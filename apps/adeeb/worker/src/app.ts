import { ConfigError, readConfig, type Config, type Env } from "./config";
import { callGemini, type FetchLike } from "./gemini";
import { hmacHex } from "./hash";
import { ipLimitKey } from "./ip";
import { logRequest } from "./log";
import { nextPacificMidnight, nextUtcMidnight, utcDay } from "./time";
import { checkClient, readDeviceId, validateAsk } from "./validate";
import { verifyOutput } from "./verify";

/** الاعتماديات الخارجية قابلة للاستبدال في الاختبار (Gemini مُحاكى، ساعة ثابتة). */
export interface Deps {
  fetch: FetchLike;
  now: () => number;
}

type ErrorCode =
  | "BAD_REQUEST"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "METHOD_NOT_ALLOWED"
  | "UPGRADE_REQUIRED"
  | "DAILY_LIMIT"
  | "RATE_LIMIT"
  | "UNAVAILABLE";

interface Outcome {
  response: Response;
  /** رمز قصير للسجل فقط (لا نص من الطلب). */
  code: string;
}

const ROUTES: Record<string, string> = {
  "/v1/ask": "POST",
  "/v1/quota": "GET",
  "/v1/health": "GET",
};

function json(status: number, body: unknown, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

function fail(
  status: number,
  code: ErrorCode,
  extra: { remaining?: number; retry_after?: number } = {},
  logCode: string = code,
): Outcome {
  const headers: Record<string, string> = {};
  if (extra.retry_after !== undefined) headers["Retry-After"] = String(extra.retry_after);
  return { response: json(status, { code, ...extra }, headers), code: logCode };
}

const secondsUntil = (targetMs: number, nowMs: number) =>
  Math.max(Math.ceil((targetMs - nowMs) / 1000), 1);

/** يقرأ الجسم بحد أقصى للبايتات حتى لو غاب Content-Length. */
async function readBodyCapped(request: Request, maxBytes: number): Promise<Uint8Array | null> {
  const declared = request.headers.get("Content-Length");
  if (declared !== null && !(Number(declared) <= maxBytes)) return null;
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const out = new Uint8Array(size);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.byteLength;
  }
  return out;
}

function counters(env: Env) {
  return env.COUNTERS.get(env.COUNTERS.idFromName("counters-v1"));
}

async function identify(request: Request, config: Config) {
  const device = readDeviceId(request.headers);
  if (device === null) return null;
  const ip = ipLimitKey(request.headers.get("CF-Connecting-IP"));
  const [deviceKey, ipKey] = await Promise.all([
    hmacHex(config.deviceSalt, device),
    hmacHex(config.ipSalt, ip),
  ]);
  return { deviceKey, ipKey };
}

async function handleQuota(request: Request, env: Env, config: Config, deps: Deps): Promise<Outcome> {
  const client = checkClient(request.headers, config);
  if (!client.ok) return client.code === "UPGRADE_REQUIRED" ? fail(426, client.code) : fail(400, client.code);
  const who = await identify(request, config);
  if (!who) return fail(400, "BAD_REQUEST");
  // حد الدقيقة لكل IP يشمل /v1/quota أيضاً (كل طلب يصل إلى الـ DO).
  if (!(await env.RL_IP.limit({ key: who.ipKey })).success) {
    return fail(429, "RATE_LIMIT", { retry_after: 60 });
  }
  const now = deps.now();
  const used = await counters(env).used(utcDay(now), who.deviceKey);
  return {
    response: json(200, {
      limit: config.dailyPerDevice,
      remaining: Math.max(config.dailyPerDevice - used, 0),
      resets_at: new Date(nextUtcMidnight(now)).toISOString(),
    }),
    code: "OK",
  };
}

async function handleAsk(request: Request, env: Env, config: Config, deps: Deps): Promise<Outcome> {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (!/^application\/json\s*(;\s*charset=utf-8\s*)?$/i.test(contentType.trim())) {
    return fail(400, "BAD_REQUEST", {}, "BAD_CONTENT_TYPE");
  }
  const client = checkClient(request.headers, config);
  if (!client.ok) return client.code === "UPGRADE_REQUIRED" ? fail(426, client.code) : fail(400, client.code, {}, "BAD_CLIENT");
  if (readDeviceId(request.headers) === null) return fail(400, "BAD_REQUEST", {}, "BAD_DEVICE");

  const bytes = await readBodyCapped(request, config.maxBodyBytes);
  if (bytes === null) return fail(400, "BAD_REQUEST", {}, "BODY_TOO_LARGE");
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes));
  } catch {
    return fail(400, "BAD_REQUEST", {}, "BAD_JSON");
  }
  const parsed = validateAsk(body, config);
  if (!parsed.ok) {
    return parsed.code === "UPGRADE_REQUIRED" ? fail(426, parsed.code) : fail(400, parsed.code, {}, "BAD_BODY");
  }
  const ask = parsed.value;

  const who = await identify(request, config);
  if (!who) return fail(400, "BAD_REQUEST", {}, "BAD_DEVICE");

  // حد بالدقيقة (Rate Limiting binding)، بمفاتيح مجزّأة لا خام.
  const [byDevice, byIp] = await Promise.all([
    env.RL_DEVICE.limit({ key: who.deviceKey }),
    env.RL_IP.limit({ key: who.ipKey }),
  ]);
  if (!byDevice.success || !byIp.success) return fail(429, "RATE_LIMIT", { retry_after: 60 });

  const now = deps.now();
  const day = utcDay(now);
  const store = counters(env);
  const reservation = await store.reserve({
    day,
    nowMs: now,
    device: who.deviceKey,
    ip: who.ipKey,
    limits: { device: config.dailyPerDevice, ip: config.dailyPerIp, global: config.dailyGlobal },
  });
  if (!reservation.ok) {
    if (reservation.reason === "DEVICE" || reservation.reason === "IP") {
      return fail(
        429,
        "DAILY_LIMIT",
        { remaining: 0, retry_after: secondsUntil(nextUtcMidnight(now), now) },
        `DAILY_LIMIT_${reservation.reason}`,
      );
    }
    return fail(503, "UNAVAILABLE", { remaining: reservation.remaining }, `UNAVAILABLE_${reservation.reason}`);
  }

  // من هنا السؤال محجوز: أي فشل قبل الرد يسترده.
  // الاسترداد متساوي الأثر في الـ DO (برمز الحجز)، فتكراره في catch آمن.
  const refund = (breakerUntil?: number) =>
    store.refund({
      token: reservation.token,
      day,
      device: who.deviceKey,
      dailyPerDevice: config.dailyPerDevice,
      breakerUntil,
    });
  try {
    const result = await callGemini(deps.fetch, config, ask.question, ask.passages);
    switch (result.kind) {
      case "quota": {
        const until = result.daily ? nextPacificMidnight(now) : now + result.retryAfterMs;
        // الاسترداد والقاطع في معاملة واحدة.
        const remaining = await refund(until);
        return fail(
          503,
          "UNAVAILABLE",
          { remaining, retry_after: secondsUntil(until, now) },
          result.daily ? "GEMINI_429_DAILY" : "GEMINI_429",
        );
      }
      case "error": {
        const remaining = await refund();
        return fail(503, "UNAVAILABLE", { remaining }, result.cause);
      }
      case "blocked":
        return {
          response: json(200, {
            found: false,
            answer: "",
            citations: [],
            reason: "NOT_FOUND",
            remaining: reservation.remaining,
          }),
          code: "BLOCKED",
        };
      case "ok": {
        const verified = verifyOutput(result.output, ask.passages);
        return {
          response: json(200, { ...verified, remaining: reservation.remaining }),
          code: verified.found ? "OK" : verified.reason,
        };
      }
    }
  } catch {
    const remaining = await refund().catch(() => undefined);
    return fail(503, "UNAVAILABLE", remaining === undefined ? {} : { remaining }, "INTERNAL");
  }
}

function tryReadConfig(env: Env): Config | null {
  try {
    return readConfig(env);
  } catch (e) {
    if (e instanceof ConfigError) return null;
    throw e;
  }
}

export function createHandler(deps: Deps) {
  return async function handle(request: Request, env: Env): Promise<Response> {
    const started = Date.now();
    const path = new URL(request.url).pathname;
    const method = ROUTES[path];
    let outcome: Outcome;
    try {
      if (method === undefined) {
        outcome = fail(404, "NOT_FOUND");
      } else if (request.method !== method) {
        outcome = fail(405, "METHOD_NOT_ALLOWED");
        outcome.response.headers.set("Allow", method);
      } else if (request.headers.has("Origin")) {
        // المتصفحات ترسل Origin والتطبيق لا يرسله؛ لا CORS (ARCHITECTURE §8.4).
        outcome = fail(403, "FORBIDDEN");
      } else if (path === "/v1/health") {
        outcome = { response: json(200, { ok: true }), code: "OK" };
      } else {
        const config = tryReadConfig(env);
        if (config === null) {
          outcome = fail(503, "UNAVAILABLE", {}, "CONFIG");
        } else if (path === "/v1/ask") {
          outcome = await handleAsk(request, env, config, deps);
        } else {
          outcome = await handleQuota(request, env, config, deps);
        }
      }
    } catch {
      outcome = fail(503, "UNAVAILABLE", {}, "INTERNAL");
    }
    logRequest({
      path: method === undefined ? "other" : path,
      status: outcome.response.status,
      ms: Date.now() - started,
      code: outcome.code,
    });
    return outcome.response;
  };
}
