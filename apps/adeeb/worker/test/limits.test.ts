import { env } from "cloudflare:workers";
import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import type { CounterStore } from "../src/counters";
import { utcDay } from "../src/time";
import { fakeGemini, freshDay, geminiJson, makeClient, makeEnv, newDevice, okOutput } from "./helpers";

const DAY = 86_400_000;

describe("الحد اليومي لكل جهاز (10)", () => {
  it("عشرة أسئلة ثم الحادي عشر DAILY_LIMIT برمز واضح، بلا استدعاء Gemini", async () => {
    const c = makeClient();
    for (let i = 1; i <= 10; i++) {
      const res = await c.ask();
      expect(res.status).toBe(200);
      expect(((await res.json()) as { remaining: number }).remaining).toBe(10 - i);
    }
    const res = await c.ask();
    expect(res.status).toBe(429);
    const body = await res.json();
    expect(body).toMatchObject({ code: "DAILY_LIMIT", remaining: 0 });
    expect(Number(res.headers.get("Retry-After"))).toBeGreaterThan(0);
    expect(c.gemini.calls).toHaveLength(10);
  });

  it("/v1/quota لا يستهلك ويعكس الباقي وموعد التجدد 00:00 UTC", async () => {
    const c = makeClient();
    for (let i = 0; i < 3; i++) await c.quota();
    let q = (await (await c.quota()).json()) as Record<string, unknown>;
    expect(q).toEqual({
      limit: 10,
      remaining: 10,
      resets_at: new Date(Math.floor(c.clock.now / DAY) * DAY + DAY).toISOString(),
    });
    await c.ask();
    await c.ask();
    q = (await (await c.quota()).json()) as Record<string, unknown>;
    expect(q.remaining).toBe(8);
  });

  it("الأجهزة مستقلة: حصة جهاز لا تؤثر في آخر", async () => {
    const a = makeClient();
    const b = makeClient({ now: a.clock.now, ip: a.ip });
    for (let i = 0; i < 10; i++) await a.ask();
    expect((await a.ask()).status).toBe(429);
    const res = await b.ask();
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ remaining: 9 });
  });

  it("تتجدد الحصة في اليوم التالي بتوقيت UTC", async () => {
    const start = Math.floor(freshDay() / DAY) * DAY + DAY - 60_000; // 23:59 UTC
    const c = makeClient({ now: start });
    for (let i = 0; i < 10; i++) expect((await c.ask()).status).toBe(200);
    expect((await c.ask()).status).toBe(429);
    c.clock.now = start + 60_000; // 00:00 UTC
    const res = await c.ask();
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ remaining: 9 });
    expect(await (await c.quota()).json()).toMatchObject({ remaining: 9 });
  });

  it("الطلبات المتزامنة لا تتجاوز الحد (ذرية الـ DO)", async () => {
    const c = makeClient();
    const results = await Promise.all(Array.from({ length: 15 }, () => c.ask()));
    const statuses = results.map((r) => r.status).sort();
    expect(statuses.filter((s) => s === 200)).toHaveLength(10);
    expect(statuses.filter((s) => s === 429)).toHaveLength(5);
    expect(c.gemini.calls).toHaveLength(10);
  });

  it("DAILY_PER_DEVICE إعداد لا ثابت", async () => {
    const c = makeClient({ env: makeEnv({ DAILY_PER_DEVICE: "2" }) });
    expect((await c.ask()).status).toBe(200);
    expect((await c.ask()).status).toBe(200);
    expect((await c.ask()).status).toBe(429);
    expect(await (await c.quota()).json()).toMatchObject({ limit: 2, remaining: 0 });
  });
});

describe("الحد اليومي لكل IP (30)", () => {
  it("الطلب 31 من نفس العنوان بأجهزة مختلفة ← DAILY_LIMIT", async () => {
    const first = makeClient();
    const gemini = first.gemini;
    for (let i = 0; i < 30; i++) {
      const c = makeClient({ now: first.clock.now, ip: first.ip, gemini });
      expect((await c.ask()).status).toBe(200);
    }
    const c = makeClient({ now: first.clock.now, ip: first.ip, gemini });
    const res = await c.ask();
    expect(res.status).toBe(429);
    expect(await res.json()).toMatchObject({ code: "DAILY_LIMIT", remaining: 0 });
    expect(gemini.calls).toHaveLength(30);
    // عنوان آخر يعمل
    expect((await makeClient({ now: first.clock.now, gemini }).ask()).status).toBe(200);
  });
});

describe("الحد الإجمالي اليومي", () => {
  it("بعد DAILY_GLOBAL سؤالاً ← 503 UNAVAILABLE للجميع، ويتجدد غداً", async () => {
    const e = makeEnv({ DAILY_GLOBAL: "3" });
    const now = freshDay();
    const gemini = fakeGemini(() => geminiJson(okOutput));
    for (let i = 0; i < 3; i++) {
      expect((await makeClient({ env: e, now, gemini }).ask()).status).toBe(200);
    }
    const c = makeClient({ env: e, now, gemini });
    const res = await c.ask();
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ code: "UNAVAILABLE", remaining: 10 });
    expect(gemini.calls).toHaveLength(3);
    c.clock.now = now + DAY;
    expect((await c.ask()).status).toBe(200);
  });
});

describe("الحد بالدقيقة (Rate Limiting binding)", () => {
  it("الجهاز: الطلب الرابع في الدقيقة ← 429 RATE_LIMIT بلا حجز", async () => {
    const c = makeClient({ env: makeEnv({ RL_DEVICE: env.RL_DEVICE }) });
    for (let i = 0; i < 3; i++) expect((await c.ask()).status).toBe(200);
    const res = await c.ask();
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({ code: "RATE_LIMIT", retry_after: 60 });
    expect(c.gemini.calls).toHaveLength(3);
    expect(await (await c.quota()).json()).toMatchObject({ remaining: 7 });
  });

  it("IP: الطلب الحادي عشر في الدقيقة من أجهزة مختلفة ← RATE_LIMIT", async () => {
    const e = makeEnv({ RL_IP: env.RL_IP });
    const first = makeClient({ env: e });
    for (let i = 0; i < 10; i++) {
      expect((await makeClient({ env: e, ip: first.ip, now: first.clock.now }).ask()).status).toBe(200);
    }
    const res = await makeClient({ env: e, ip: first.ip, now: first.clock.now }).ask();
    expect(res.status).toBe(429);
    expect(await res.json()).toMatchObject({ code: "RATE_LIMIT" });
  });

  it("الطلبات المرفوضة بالصيغة لا تستهلك حد الدقيقة", async () => {
    const c = makeClient({ env: makeEnv({ RL_DEVICE: env.RL_DEVICE }) });
    for (let i = 0; i < 5; i++) expect((await c.ask({ bad: true })).status).toBe(400);
    expect((await c.ask()).status).toBe(200);
  });
});

describe("تخزين العدّادات", () => {
  const stub = () => env.COUNTERS.get(env.COUNTERS.idFromName("counters-v1"));

  it("لا يُخزَّن المعرّف ولا IP خاماً", async () => {
    const device = newDevice();
    const c = makeClient({ device, ip: "203.0.113.77" });
    await c.ask();
    const rows = await runInDurableObject(stub(), (_i: CounterStore, state) =>
      state.storage.sql.exec("SELECT key_hash FROM counters").toArray(),
    );
    const all = JSON.stringify(rows);
    expect(all).not.toContain(device);
    expect(all).not.toContain("203.0.113.77");
    for (const r of rows) expect(String(r.key_hash)).toMatch(/^([0-9a-f]{64}|\*)$/);
  });

  it("التنظيف يحذف صفوف الأيام السابقة فقط، والمنبّه يعمل", async () => {
    const now = freshDay();
    const c = makeClient({ now });
    await c.ask();
    const s = stub();
    const before = await s.rowCount();
    expect(before).toBeGreaterThan(0);
    // تنظيف بتاريخ اليوم نفسه لا يحذف شيئاً من اليوم.
    await s.cleanup(utcDay(now), now);
    expect(await (await c.quota()).json()).toMatchObject({ remaining: 9 });
    // تنظيف بتاريخ الغد يحذف صفوف اليوم.
    await s.cleanup(utcDay(now + DAY), now + DAY);
    expect(await (await c.quota()).json()).toMatchObject({ remaining: 10 });
    // منبّه مجدول بعد أول حجز، وتشغيله لا يرمي.
    expect(await runDurableObjectAlarm(s)).toBe(true);
  });
});
