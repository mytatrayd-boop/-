import { describe, expect, it } from "vitest";
import { askBody, fakeGemini, geminiJson, makeClient, makeEnv, okOutput, PASSAGES } from "./helpers";

/** كل رفض يجب ألا يلمس Gemini ولا العدّادات. */
async function expectRejected(
  res: Response,
  c: ReturnType<typeof makeClient>,
  status = 400,
  code = "BAD_REQUEST",
) {
  expect(res.status).toBe(status);
  expect(await res.json()).toMatchObject({ code });
  expect(c.gemini.calls).toHaveLength(0);
  const q = await c.quota({ "X-Client": "adeeb-android/999" });
  expect(await q.json()).toMatchObject({ remaining: 10 });
}

const passage = (i: number, text = "نص فقرة تجريبية قصيرة") => ({
  id: `kalila-b001-p${String(i).padStart(5, "0")}`,
  book: "كتاب",
  chapter: "باب",
  text,
});

describe("المسارات والطريقة", () => {
  it("GET /v1/health", async () => {
    const c = makeClient();
    const res = await c.raw(new Request("https://adeeb.test/v1/health"));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
  });

  it("مسار غير معروف ← 404", async () => {
    const c = makeClient();
    const res = await c.raw(new Request("https://adeeb.test/v1/other"));
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ code: "NOT_FOUND" });
  });

  it("طريقة خاطئة ← 405 مع Allow", async () => {
    const c = makeClient();
    const res = await c.raw(new Request("https://adeeb.test/v1/ask"));
    expect(res.status).toBe(405);
    expect(res.headers.get("Allow")).toBe("POST");
    const res2 = await c.raw(new Request("https://adeeb.test/v1/quota", { method: "POST", body: "{}" }));
    expect(res2.status).toBe(405);
  });

  it("طلب من متصفح (ترويسة Origin) ← 403 بلا CORS", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody(), { Origin: "https://evil.example" }), c, 403, "FORBIDDEN");
    expect((await c.ask(askBody(), { Origin: "https://x" })).headers.get("Access-Control-Allow-Origin")).toBeNull();
  });
});

describe("الترويسات", () => {
  it("نوع محتوى غير JSON ← 400", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody(), { "Content-Type": "text/plain" }), c);
    await expectRejected(await c.ask(askBody(), { "Content-Type": "application/x-www-form-urlencoded" }), c);
  });

  it("charset=utf-8 مقبول", async () => {
    const c = makeClient();
    const res = await c.ask(askBody(), { "Content-Type": "application/json; charset=utf-8" });
    expect(res.status).toBe(200);
  });

  it("معرّف جهاز مفقود أو ليس UUID v4 ← 400", async () => {
    const c = makeClient();
    for (const id of ["", "abc", "00000000-0000-1000-8000-000000000000", "android-id-123"]) {
      const res = await c.ask(askBody(), { "X-Device-Id": id });
      expect(res.status).toBe(400);
    }
    expect(c.gemini.calls).toHaveLength(0);
    const q = await c.quota({ "X-Device-Id": "bad" });
    expect(q.status).toBe(400);
  });

  it("X-Client مفقود أو بصيغة خاطئة ← 400", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody(), { "X-Client": "" }), c);
    await expectRejected(await c.ask(askBody(), { "X-Client": "curl/8.0" }), c);
  });

  it("عميل أقدم من MIN_CLIENT ← 426", async () => {
    const c = makeClient({ env: makeEnv({ MIN_CLIENT: "7" }) });
    await expectRejected(await c.ask(askBody(), { "X-Client": "adeeb-android/6" }), c, 426, "UPGRADE_REQUIRED");
    expect((await c.quota({ "X-Client": "adeeb-android/6" })).status).toBe(426);
    expect((await c.ask(askBody(), { "X-Client": "adeeb-android/7" })).status).toBe(200);
  });
});

describe("الجسم", () => {
  it("JSON غير صالح أو UTF-8 غير صالح ← 400", async () => {
    const c = makeClient();
    await expectRejected(await c.ask("{not json"), c);
    await expectRejected(await c.ask("[]"), c);
    await expectRejected(await c.ask("null"), c);
  });

  it("حقول ناقصة أو إضافية ← 400", async () => {
    const c = makeClient();
    const { question: _q, ...noQuestion } = askBody();
    await expectRejected(await c.ask(noQuestion), c);
    await expectRejected(await c.ask(askBody({ extra: 1 })), c);
    await expectRejected(
      await c.ask(askBody({ passages: [{ ...PASSAGES[0], score: 3 }] })),
      c,
    );
    const { book: _b, ...noBook } = PASSAGES[0];
    await expectRejected(await c.ask(askBody({ passages: [noBook] })), c);
  });

  it("الإصدار واللغة", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody({ v: 2 })), c);
    await expectRejected(await c.ask(askBody({ v: "1" })), c);
    await expectRejected(await c.ask(askBody({ v: 0 })), c, 426, "UPGRADE_REQUIRED");
    await expectRejected(await c.ask(askBody({ lang: "fr" })), c);
  });

  it("طول السؤال: أقل من 2 أو أكثر من 500 ← 400، و500 مقبول", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody({ question: "" })), c);
    await expectRejected(await c.ask(askBody({ question: " ؟ " })), c);
    await expectRejected(await c.ask(askBody({ question: "س".repeat(501) })), c);
    await expectRejected(await c.ask(askBody({ question: 42 })), c);
    await expectRejected(await c.ask(askBody({ question: "سؤال\u0000مخفي" })), c);
    const ok = makeClient();
    expect((await ok.ask(askBody({ question: "س".repeat(500) }))).status).toBe(200);
  });

  it("عدد الفقرات: 0 أو أكثر من 6 ← 400، و6 مقبولة", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody({ passages: [] })), c);
    await expectRejected(await c.ask(askBody({ passages: [1, 2, 3, 4, 5, 6, 7].map((i) => passage(i)) })), c);
    await expectRejected(await c.ask(askBody({ passages: "x" })), c);
    const ok = makeClient({ gemini: fakeGemini(() => geminiJson({ found: false, answer: "", citations: [] })) });
    expect((await ok.ask(askBody({ passages: [1, 2, 3, 4, 5, 6].map((i) => passage(i)) }))).status).toBe(200);
  });

  it("طول الفقرة > 1500 أو المجموع > 8000 ← 400، والحد نفسه مقبول", async () => {
    const c = makeClient();
    await expectRejected(await c.ask(askBody({ passages: [passage(1, "ن".repeat(1501))] })), c);
    const six = [1, 2, 3, 4, 5, 6].map((i) => passage(i, "ن".repeat(1400))); // 8400
    await expectRejected(await c.ask(askBody({ passages: six })), c);
    await expectRejected(await c.ask(askBody({ passages: [passage(1, "   ")] })), c);
    await expectRejected(await c.ask(askBody({ passages: [{ ...passage(1), book: "ك".repeat(201) }] })), c);

    // أقصى طلب مشروع بالعربية المشكولة (8000 حرف) يمر رغم أنه أكبر من 16 كيلوبايت.
    const ok = makeClient({ gemini: fakeGemini(() => geminiJson({ found: false, answer: "", citations: [] })) });
    const max = [1, 2, 3, 4, 5].map((i) => passage(i, "نَ".repeat(750)));
    max.push(passage(6, "نَ".repeat(250)));
    const body = askBody({ question: "سُ".repeat(250), passages: max });
    expect(new TextEncoder().encode(JSON.stringify(body)).byteLength).toBeGreaterThan(16_384);
    expect((await ok.ask(body)).status).toBe(200);
  });

  it("معرّف فقرة بنمط خاطئ أو مكرر ← 400", async () => {
    const c = makeClient();
    for (const id of ["kalila-b1-p1", "KALILA-b001-p00001", "kalila-b001-p00001x", "k-b001-p00001", "../etc"]) {
      await expectRejected(await c.ask(askBody({ passages: [{ ...passage(1), id }] })), c);
    }
    await expectRejected(await c.ask(askBody({ passages: [passage(1), passage(1)] })), c);
  });

  it("جسم أكبر من MAX_BODY_BYTES ← 400 (بـ Content-Length أو بلا)", async () => {
    const c = makeClient({ env: makeEnv({ MAX_BODY_BYTES: "2000" }) });
    const big = JSON.stringify(askBody({ question: "س".repeat(500), passages: [passage(1, "ن".repeat(1000))] }));
    await expectRejected(await c.ask(big), c);
    // بلا Content-Length (تدفق مجزّأ)
    const stream = new ReadableStream({
      start(ctrl) {
        const bytes = new TextEncoder().encode(big);
        ctrl.enqueue(bytes.slice(0, 1000));
        ctrl.enqueue(bytes.slice(1000));
        ctrl.close();
      },
    });
    const res = await c.raw(
      new Request("https://adeeb.test/v1/ask", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Device-Id": c.device,
          "X-Client": "adeeb-android/5",
        },
        body: stream,
      }),
    );
    await expectRejected(res, c);
  });
});

describe("الإعداد", () => {
  it("سرّ ناقص ← 503 UNAVAILABLE بلا استدعاء Gemini", async () => {
    const c = makeClient({ env: makeEnv({ GEMINI_API_KEY: undefined }) });
    const res = await c.ask();
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ code: "UNAVAILABLE" });
    expect(c.gemini.calls).toHaveLength(0);
  });

  it("الرد الناجح لا يحمل نص النموذج خارج الحقول المعروفة", async () => {
    const c = makeClient();
    const res = await c.ask();
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect(await res.json()).toEqual({
      found: true,
      answer: okOutput.answer,
      citations: okOutput.citations,
      remaining: 9,
    });
  });
});
