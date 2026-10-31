// عميل Gemini عبر نقطة التوافق مع OpenAI (generativelanguage.googleapis.com/v1beta/openai) بلا اعتماديات؛ كل دوال الشبكة تقبل fetch/sleep قابلة للحقن للاختبار.
import { PROMPTS, RESPONSE_SCHEMA, validateResult } from './prompts.mjs';

export const DEFAULT_MODEL = 'gemini-2.5-flash';
export const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/openai';
export const MIME = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };

export const endpoint = () => `${BASE_URL}/chat/completions`;

/** يحوّل مخطط Gemini (أنواع بحروف كبيرة) إلى JSON Schema قياسي. */
export const toJsonSchema = (n) =>
  Array.isArray(n) ? n.map(toJsonSchema)
    : n && typeof n === 'object' ? Object.fromEntries(Object.entries(n).map(([k, v]) => [k, k === 'type' && typeof v === 'string' ? v.toLowerCase() : toJsonSchema(v)]))
      : n;

/**
 * جسم الطلب (chat.completions): صورة + الطلب، حرارة 0.
 * jsonMode: 'schema' (json_schema، الافتراضي) أو 'object' (json_object؛ يبقى validateResult هو الحَكَم).
 */
export function buildBody(type, mimeType, base64, { jsonMode = 'schema' } = {}) {
  if (!PROMPTS[type]) throw new Error(`نوع غير معروف: ${type}`);
  return {
    temperature: 0,
    messages: [{ role: 'user', content: [
      { type: 'text', text: PROMPTS[type] },
      { type: 'image_url', image_url: { url: `data:${mimeType};base64,${base64}` } },
    ] }],
    response_format: jsonMode === 'object' ? { type: 'json_object' }
      : { type: 'json_schema', json_schema: { name: 'coffee_assessment', schema: toJsonSchema(RESPONSE_SCHEMA) } },
  };
}

/** يحلل رد الخدمة إلى نتيجة موحدة. التكلفة 0 دائماً (الطبقة المجانية). */
export function parseResponse(j) {
  const ch = j?.choices?.[0];
  let text = ch?.message?.content ?? '';
  if (Array.isArray(text)) text = text.map((p) => p.text ?? '').join('');
  text = String(text).trim().replace(/^```(?:json)?\s*|\s*```$/g, '');
  if (!text) throw new Error(`رد فارغ (${ch?.finish_reason || 'بلا سبب'})`);
  const out = validateResult(JSON.parse(text));
  const u = j.usage || {};
  return {
    score: out.status === 'ok' ? out.score : NaN, status: out.status, notes: out.notes,
    roast: out.roast_level, hasDefects: out.has_defects,
    tokensIn: u.prompt_tokens || 0, tokensOut: u.completion_tokens || 0,
    tokensThoughts: u.completion_tokens_details?.reasoning_tokens || 0, cost: 0,
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
 * يعيد { json, ms, attempts }. التوثيق: إن وُجد apiKey يُرسل Bearer، وإلا لا تُرسل Authorization (الوكيل يحقنها من سر الشبكة). المفتاح لا يوضع في الرابط.
 */
export async function callGemini({ apiKey, model, body, timeoutMs = 60000, maxRetries = 4, baseDelayMs = 2000,
  fetchImpl = fetch, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), limiter = async () => {}, log = () => {} }) {
  const headers = { 'Content-Type': 'application/json', ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}) };
  for (let attempt = 0; ; attempt++) {
    await limiter();
    const t0 = performance.now();
    let res;
    try {
      res = await fetchImpl(endpoint(), {
        method: 'POST', signal: AbortSignal.timeout(timeoutMs),
        headers, body: JSON.stringify({ model, ...body }),
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
