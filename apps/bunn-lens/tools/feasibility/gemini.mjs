// عميل Gemini API (generativelanguage.googleapis.com) بلا اعتماديات؛ كل دوال الشبكة تقبل fetch/sleep قابلة للحقن للاختبار.
import { PROMPTS, RESPONSE_SCHEMA, validateResult } from './prompts.mjs';

export const DEFAULT_MODEL = 'gemini-2.5-flash';
export const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
export const MIME = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };

export const endpoint = (model) => `${BASE_URL}/models/${encodeURIComponent(model)}:generateContent`;

/** جسم الطلب: صورة + الطلب v0-feasibility-2، حرارة 0، JSON مفروض بالمخطط. */
export function buildBody(type, mimeType, base64) {
  if (!PROMPTS[type]) throw new Error(`نوع غير معروف: ${type}`);
  return {
    contents: [{ role: 'user', parts: [{ inlineData: { mimeType, data: base64 } }, { text: PROMPTS[type] }] }],
    generationConfig: { temperature: 0, responseMimeType: 'application/json', responseSchema: RESPONSE_SCHEMA },
  };
}

/** يحلل رد الخدمة إلى نتيجة موحدة. التكلفة 0 دائماً (الطبقة المجانية). */
export function parseResponse(j) {
  const cand = j?.candidates?.[0];
  const text = cand?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  if (!text) throw new Error(`رد فارغ (${cand?.finishReason || j?.promptFeedback?.blockReason || 'بلا سبب'})`);
  const out = validateResult(JSON.parse(text));
  const u = j.usageMetadata || {};
  return {
    score: out.status === 'ok' ? out.score : NaN, status: out.status, notes: out.notes,
    roast: out.roast_level, hasDefects: out.has_defects,
    tokensIn: u.promptTokenCount || 0, tokensOut: u.candidatesTokenCount || 0,
    tokensThoughts: u.thoughtsTokenCount || 0, cost: 0,
  };
}

/** حدّ معدل بسيط: يضمن فاصلاً أدنى بين بدايات الطلبات (rpm=0 يعطّله). */
export function makeLimiter(rpm, { now = () => Date.now(), sleep = (ms) => new Promise((r) => setTimeout(r, ms)) } = {}) {
  const gap = rpm > 0 ? 60000 / rpm : 0;
  let next = 0;
  return async () => {
    const t = now();
    const start = Math.max(t, next);
    next = start + gap;
    if (start > t) await sleep(start - t);
  };
}

const retryAfterMs = (res) => {
  const h = Number(res.headers?.get?.('retry-after'));
  return Number.isFinite(h) && h > 0 ? h * 1000 : NaN;
};

/**
 * يرسل الطلب مع مهلة، وإعادة محاولة عند 429 (وأخطاء 5xx) بتراجع أسّي.
 * يعيد { json, ms, attempts }. المفتاح في ترويسة x-goog-api-key لا في الرابط.
 */
export async function callGemini({ apiKey, model, body, timeoutMs = 60000, maxRetries = 4, baseDelayMs = 2000,
  fetchImpl = fetch, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), limiter = async () => {}, log = () => {} }) {
  for (let attempt = 0; ; attempt++) {
    await limiter();
    const t0 = performance.now();
    let res;
    try {
      res = await fetchImpl(endpoint(model), {
        method: 'POST', signal: AbortSignal.timeout(timeoutMs),
        headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
      });
    } catch (e) {
      const timedOut = e?.name === 'TimeoutError' || e?.name === 'AbortError';
      if (attempt < maxRetries) { const d = baseDelayMs * 2 ** attempt; log(`${timedOut ? 'مهلة' : e.message}، إعادة بعد ${d}ms`); await sleep(d); continue; }
      throw new Error(timedOut ? `انتهت المهلة (${timeoutMs}ms)` : e.message);
    }
    if (res.ok) return { json: await res.json(), ms: performance.now() - t0, attempts: attempt + 1 };
    const retryable = res.status === 429 || res.status >= 500;
    if (retryable && attempt < maxRetries) {
      const d = retryAfterMs(res) || baseDelayMs * 2 ** attempt;
      log(`HTTP ${res.status}، إعادة بعد ${d}ms (${attempt + 1}/${maxRetries})`);
      await sleep(d);
      continue;
    }
    throw new Error(`HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
}
