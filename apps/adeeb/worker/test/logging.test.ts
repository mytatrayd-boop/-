import { afterEach, describe, expect, it, vi } from "vitest";
import { askBody, fakeGemini, gemini429, geminiJson, makeClient, okOutput, PASSAGES, DAILY_QUOTA_429 } from "./helpers";

const SECRET_QUESTION = "سؤال سري جدا عن صحتي الشخصية";
const IP = "198.51.100.23";

describe("السجلات لا تحوي السؤال ولا الفقرات ولا IP ولا المعرّف", () => {
  afterEach(() => vi.restoreAllMocks());

  it("في النجاح والرفض والفشل", async () => {
    const lines: string[] = [];
    for (const m of ["log", "info", "warn", "error", "debug"] as const) {
      vi.spyOn(console, m).mockImplementation((...args: unknown[]) => {
        lines.push(args.map((a) => (typeof a === "string" ? a : JSON.stringify(a))).join(" "));
      });
    }
    let mode = 0;
    const gemini = fakeGemini(() =>
      mode === 0
        ? geminiJson(okOutput)
        : mode === 1
          ? new Response("boom", { status: 500 })
          : gemini429(DAILY_QUOTA_429),
    );
    const c = makeClient({ gemini, ip: IP });
    const body = askBody({ question: SECRET_QUESTION });
    await c.ask(body); // نجاح
    await c.ask({ ...body, extra: true }); // 400
    mode = 1;
    await c.ask(body); // فشل Gemini
    mode = 2;
    await c.ask(body); // 429
    await c.quota();
    await c.raw(new Request(`https://adeeb.test/v1/${encodeURIComponent(SECRET_QUESTION)}`));

    expect(lines.length).toBeGreaterThanOrEqual(6);
    const all = lines.join("\n");
    for (const forbidden of [
      SECRET_QUESTION,
      encodeURIComponent(SECRET_QUESTION),
      PASSAGES[0].text,
      "الصبر",
      okOutput.answer,
      IP,
      c.device,
      "test-only-not-a-key",
    ]) {
      expect(all).not.toContain(forbidden);
    }
    for (const line of lines) {
      const parsed = JSON.parse(line);
      expect(Object.keys(parsed).sort()).toEqual(["code", "ms", "path", "status"]);
      expect(["/v1/ask", "/v1/quota", "/v1/health", "other"]).toContain(parsed.path);
    }
  });
});
