import { env } from "cloudflare:workers";
import { createHandler } from "../src/app";
import type { Env } from "../src/config";
import type { ModelOutput } from "../src/gemini";

/** نصوص اصطناعية للاختبار فقط، ليست من الكتب. */
export const PASSAGES = [
  {
    id: "kalila-b001-p00001",
    book: "كتاب تجريبي",
    chapter: "باب الاختبار",
    text: "قالَ الحكيمُ لتلميذِه: إنّ الصبرَ مفتاحُ الفرجِ، ومَن صبرَ على الشدّةِ نالَ ما يريد.",
  },
  {
    id: "kalila-b001-p00002",
    book: "كتاب تجريبي",
    chapter: "باب الاختبار",
    text: "وكان في المدينةِ تاجرٌ يحبُّ الكتبَ، فإذا سافرَ حملَ معه صندوقاً منها.",
  },
];

export const TRUE_QUOTE = "إن الصبر مفتاح الفرج";

export const okOutput: ModelOutput = {
  found: true,
  answer: "الصبر مفتاح الفرج كما قال الحكيم.",
  citations: [{ paragraph_id: PASSAGES[0].id, quote: TRUE_QUOTE }],
};

/** UUID v4 فريد لكل اختبار حتى لا تتداخل العدّادات. */
export function newDevice(): string {
  return crypto.randomUUID();
}

let ipCounter = 0;
export function newIp(): string {
  ipCounter++;
  return `10.${(ipCounter >> 16) & 255}.${(ipCounter >> 8) & 255}.${ipCounter & 255}`;
}

export const allow: RateLimit = { limit: async () => ({ success: true }) };

/** env الحقيقي (الـ DO وقيم wrangler.jsonc) مع حد الدقيقة معطّل افتراضياً. */
export function makeEnv(over: Partial<Record<keyof Env, unknown>> = {}): Env {
  const base = env;
  return {
    COUNTERS: base.COUNTERS,
    RL_DEVICE: allow,
    RL_IP: allow,
    GEMINI_API_KEY: base.GEMINI_API_KEY,
    DEVICE_SALT: base.DEVICE_SALT,
    IP_SALT: base.IP_SALT,
    GEMINI_MODEL: base.GEMINI_MODEL,
    GEMINI_API_BASE: base.GEMINI_API_BASE,
    GEMINI_TIMEOUT_MS: base.GEMINI_TIMEOUT_MS,
    DAILY_PER_DEVICE: base.DAILY_PER_DEVICE,
    DAILY_PER_IP: base.DAILY_PER_IP,
    DAILY_GLOBAL: base.DAILY_GLOBAL,
    MIN_CLIENT: base.MIN_CLIENT,
    MAX_BODY_BYTES: base.MAX_BODY_BYTES,
    MAX_QUESTION_CHARS: base.MAX_QUESTION_CHARS,
    MAX_PASSAGES: base.MAX_PASSAGES,
    MAX_PASSAGE_CHARS: base.MAX_PASSAGE_CHARS,
    MAX_PASSAGES_TOTAL_CHARS: base.MAX_PASSAGES_TOTAL_CHARS,
    MAX_ANSWER_CHARS: base.MAX_ANSWER_CHARS,
    ...over,
  } as Env;
}

export interface FakeGemini {
  calls: Array<{ url: string; init: RequestInit; body: any }>;
  fetch: (url: string, init: RequestInit) => Promise<Response>;
}

/** Gemini وهمي: [respond] يعيد الرد لكل استدعاء. */
export function fakeGemini(respond: (n: number) => Response | Promise<Response>): FakeGemini {
  const calls: FakeGemini["calls"] = [];
  return {
    calls,
    fetch: async (url, init) => {
      calls.push({ url, init, body: JSON.parse(String(init.body)) });
      return respond(calls.length);
    },
  };
}

export function geminiJson(output: unknown, finishReason = "STOP"): Response {
  return Response.json({
    candidates: [
      {
        finishReason,
        content: { role: "model", parts: [{ text: typeof output === "string" ? output : JSON.stringify(output) }] },
      },
    ],
  });
}

export function gemini429(details: unknown[] = []): Response {
  return Response.json(
    { error: { code: 429, status: "RESOURCE_EXHAUSTED", message: "quota", details } },
    { status: 429 },
  );
}

export const DAILY_QUOTA_429 = [
  {
    "@type": "type.googleapis.com/google.rpc.QuotaFailure",
    violations: [{ quotaId: "GenerateRequestsPerDayPerProjectPerModel-FreeTier" }],
  },
];

export const MINUTE_QUOTA_429 = [
  {
    "@type": "type.googleapis.com/google.rpc.QuotaFailure",
    violations: [{ quotaId: "GenerateRequestsPerMinutePerProjectPerModel-FreeTier" }],
  },
  { "@type": "type.googleapis.com/google.rpc.RetryInfo", retryDelay: "30s" },
];

export interface Client {
  device: string;
  ip: string;
  clock: { now: number };
  gemini: FakeGemini;
  env: Env;
  ask(body?: unknown, headers?: Record<string, string>): Promise<Response>;
  quota(headers?: Record<string, string>): Promise<Response>;
  raw(req: Request): Promise<Response>;
}

/** يوم ثابت لكل مجموعة اختبارات حتى لا تتداخل العدّادات الإجمالية. */
let dayCounter = 0;
export function freshDay(): number {
  dayCounter++;
  return Date.UTC(2030, 0, 1) + dayCounter * 7 * 86_400_000 + 12 * 3_600_000;
}

export function askBody(over: Record<string, unknown> = {}) {
  return { v: 1, lang: "ar", question: "ما مفتاح الفرج؟", passages: PASSAGES, ...over };
}

export function makeClient(opts: {
  gemini?: FakeGemini;
  env?: Env;
  now?: number;
  device?: string;
  ip?: string;
} = {}): Client {
  const clock = { now: opts.now ?? freshDay() };
  const gemini = opts.gemini ?? fakeGemini(() => geminiJson(okOutput));
  const e = opts.env ?? makeEnv();
  const handle = createHandler({ fetch: gemini.fetch, now: () => clock.now });
  const device = opts.device ?? newDevice();
  const ip = opts.ip ?? newIp();
  const baseHeaders = () => ({
    "X-Device-Id": client.device,
    "X-Client": "adeeb-android/5",
    "CF-Connecting-IP": client.ip,
  });
  const client: Client = {
    device,
    ip,
    clock,
    gemini,
    env: e,
    ask: (body = askBody(), headers = {}) =>
      handle(
        new Request("https://adeeb.test/v1/ask", {
          method: "POST",
          headers: { ...baseHeaders(), "Content-Type": "application/json", ...headers },
          body: typeof body === "string" ? body : JSON.stringify(body),
        }),
        e,
      ),
    quota: (headers = {}) =>
      handle(
        new Request("https://adeeb.test/v1/quota", { headers: { ...baseHeaders(), ...headers } }),
        e,
      ),
    raw: (req) => handle(req, e),
  };
  return client;
}
