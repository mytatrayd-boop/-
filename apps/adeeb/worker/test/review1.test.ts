import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import type { Env } from "../src/config";
import { ipLimitKey } from "../src/ip";
import {
  DAILY_QUOTA_429,
  fakeGemini,
  freshDay,
  gemini429,
  geminiJson,
  makeClient,
  makeEnv,
  newIp,
} from "./helpers";

async function remaining(c: ReturnType<typeof makeClient>) {
  return ((await (await c.quota()).json()) as { remaining: number }).remaining;
}

describe("مفتاح IP: IPv4 كامل وIPv6 ببادئة /64", () => {
  it("ipLimitKey", () => {
    expect(ipLimitKey("203.0.113.5")).toBe("v4:203.0.113.5");
    expect(ipLimitKey("203.0.113.6")).not.toBe(ipLimitKey("203.0.113.5"));
    expect(ipLimitKey("2001:db8:1:2:aaaa::1")).toBe("v6:2001:db8:1:2::/64");
    expect(ipLimitKey("2001:0DB8:0001:0002:ffff:1:2:3")).toBe("v6:2001:db8:1:2::/64");
    expect(ipLimitKey("2001:db8:1:3::1")).toBe("v6:2001:db8:1:3::/64");
    expect(ipLimitKey("::1")).toBe("v6:0:0:0:0::/64");
    expect(ipLimitKey("::ffff:203.0.113.5")).toBe("v4:203.0.113.5");
    expect(ipLimitKey("fe80::1%eth0")).toBe("v6:fe80:0:0:0::/64");
    expect(ipLimitKey(null)).toBe("unknown");
    expect(ipLimitKey("1:2:3")).toBe("raw:1:2:3");
  });

  it("عنوانان من نفس /64 يتشاركان الحد اليومي لـ IP", async () => {
    const e = makeEnv({ DAILY_PER_IP: "2" });
    const now = freshDay();
    const a = makeClient({ env: e, now, ip: "2001:db8:aa:bb::1" });
    const b = makeClient({ env: e, now, ip: "2001:db8:aa:bb:ffff:eeee:dddd:cccc" });
    const other = makeClient({ env: e, now, ip: "2001:db8:aa:bc::1" });
    expect((await a.ask()).status).toBe(200);
    expect((await b.ask()).status).toBe(200);
    const res = await makeClient({ env: e, now, ip: "2001:db8:aa:bb::99" }).ask();
    expect(res.status).toBe(429);
    expect(await res.json()).toMatchObject({ code: "DAILY_LIMIT" });
    expect((await other.ask()).status).toBe(200);
  });

  it("عنوانان من نفس /64 يتشاركان حد الدقيقة RL_IP", async () => {
    const e = makeEnv({ RL_IP: env.RL_IP });
    const now = freshDay();
    for (let i = 0; i < 10; i++) {
      const c = makeClient({ env: e, now, ip: `2001:db8:77:1::${(i + 1).toString(16)}` });
      expect((await c.ask()).status).toBe(200);
    }
    const res = await makeClient({ env: e, now, ip: "2001:db8:77:1:abcd::1" }).ask();
    expect(await res.json()).toMatchObject({ code: "RATE_LIMIT" });
  });
});

/** يغلّف الـ DO الحقيقي ويجعل أول استدعاء لـ refund يرمي بعد أن ينفّذ فعلاً (رد ضائع). */
function flakyCounters(): { ns: Env["COUNTERS"]; refundCalls: () => number } {
  const real = env.COUNTERS;
  let calls = 0;
  const ns = {
    idFromName: (n: string) => real.idFromName(n),
    get: (id: DurableObjectId) => {
      const stub = real.get(id);
      // أغلفة صريحة: خصائص بديل RPC لا تُربط بـ bind.
      return {
        reserve: (input: any) => stub.reserve(input),
        used: (day: string, device: string) => stub.used(day, device),
        refund: async (input: any) => {
          calls++;
          const r = await stub.refund(input);
          if (calls === 1) throw new Error("connection lost after commit");
          return r;
        },
      };
    },
  } as unknown as Env["COUNTERS"];
  return { ns, refundCalls: () => calls };
}

describe("الاسترداد لا يتكرر", () => {
  it("فشل بعد الاسترداد (429) ← catch يعيد المحاولة دون استرداد مزدوج، والقاطع مفعّل", async () => {
    const flaky = flakyCounters();
    const gemini = fakeGemini(() => gemini429(DAILY_QUOTA_429));
    const c = makeClient({ env: makeEnv({ COUNTERS: flaky.ns }), gemini });
    // سؤال ناجح أولاً حتى يكون هناك ما قد يُسترد خطأً مرتين.
    const ok = makeClient({ now: c.clock.now, device: c.device, ip: c.ip });
    expect((await ok.ask()).status).toBe(200);
    expect(await remaining(c)).toBe(9);

    const res = await c.ask();
    expect(res.status).toBe(503);
    expect(flaky.refundCalls()).toBe(2);
    // 9 لا 10: الحجز الفاشل استُرد مرة واحدة فقط.
    expect(await remaining(c)).toBe(9);
    // القاطع طُبّق في المعاملة نفسها.
    const after = makeClient({ now: c.clock.now + 1000, gemini: fakeGemini(() => geminiJson({ found: false, answer: "", citations: [] })) });
    expect((await after.ask()).status).toBe(503);
    expect(after.gemini.calls).toHaveLength(0);
  });

  it("فشل بعد الاسترداد (خطأ Gemini) لا يضاعف الاسترداد على العدّاد الإجمالي", async () => {
    const flaky = flakyCounters();
    const e = makeEnv({ COUNTERS: flaky.ns, DAILY_GLOBAL: "1" });
    const now = freshDay();
    const c = makeClient({ env: e, now, gemini: fakeGemini(() => new Response("", { status: 500 })) });
    expect((await c.ask()).status).toBe(503);
    expect(flaky.refundCalls()).toBe(2);
    // لو استُرد مرتين لصار الإجمالي -1 مقيداً بـ 0 ولسمح بسؤالين؛ نتحقق أنه يسمح بواحد فقط.
    const g = fakeGemini(() => geminiJson({ found: false, answer: "", citations: [] }));
    expect((await makeClient({ env: makeEnv({ DAILY_GLOBAL: "1" }), now, gemini: g }).ask()).status).toBe(200);
    expect((await makeClient({ env: makeEnv({ DAILY_GLOBAL: "1" }), now, gemini: g }).ask()).status).toBe(503);
  });

  it("refund بالرمز نفسه مرتين مباشرة على الـ DO ← أثر واحد", async () => {
    const stub = env.COUNTERS.get(env.COUNTERS.idFromName("counters-v1"));
    const day = "2035-01-01";
    const nowMs = Date.UTC(2035, 0, 1, 12);
    const limits = { device: 10, ip: 30, global: 100 };
    await stub.reserve({ day, nowMs, device: "d1", ip: "i1", limits });
    const r = await stub.reserve({ day, nowMs, device: "d1", ip: "i1", limits });
    if (!r.ok) throw new Error("reserve failed");
    expect(await stub.refund({ token: r.token, day, device: "d1", dailyPerDevice: 10 })).toBe(9);
    expect(await stub.refund({ token: r.token, day, device: "d1", dailyPerDevice: 10 })).toBe(9);
    expect(await stub.used(day, "d1")).toBe(1);
  });
});

describe("حد طول الإجابة (MAX_ANSWER_CHARS = 800)", () => {
  const out = (n: number) => ({
    found: true,
    answer: "ج".repeat(n),
    citations: [{ paragraph_id: "kalila-b001-p00001", quote: "إن الصبر مفتاح الفرج" }],
  });
  it("800 حرف مقبولة", async () => {
    const c = makeClient({ gemini: fakeGemini(() => geminiJson(out(800))) });
    expect(await (await c.ask()).json()).toMatchObject({ found: true });
  });
  it("801 حرف ← رد غير صالح: 503 ويُسترد", async () => {
    const c = makeClient({ gemini: fakeGemini(() => geminiJson(out(801))) });
    const res = await c.ask();
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ code: "UNAVAILABLE", remaining: 10 });
  });
  it("الحد إعداد", async () => {
    const c = makeClient({ env: makeEnv({ MAX_ANSWER_CHARS: "100" }), gemini: fakeGemini(() => geminiJson(out(101))) });
    expect((await c.ask()).status).toBe(503);
  });
});

describe("RL_IP على GET /v1/quota", () => {
  it("الطلب الحادي عشر في الدقيقة من نفس IP ← 429 RATE_LIMIT", async () => {
    const e = makeEnv({ RL_IP: env.RL_IP });
    const ip = newIp();
    for (let i = 0; i < 10; i++) {
      expect((await makeClient({ env: e, ip }).quota()).status).toBe(200);
    }
    const res = await makeClient({ env: e, ip }).quota();
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({ code: "RATE_LIMIT", retry_after: 60 });
  });
});
