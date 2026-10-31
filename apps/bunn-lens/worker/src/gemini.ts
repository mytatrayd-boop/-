// استدعاء Gemini عبر نقطة التوافق مع OpenAI. المفتاح سر من env فقط.
import { PROMPTS, RESPONSE_SCHEMA, validateResult, type Assessment, type ScanType } from './prompts';

export const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
export class GeminiBusy extends Error {}
export class GeminiFailed extends Error {}

export function buildBody(type: ScanType, model: string, base64: string) {
  return {
    model, temperature: 0,
    messages: [{ role: 'user', content: [
      { type: 'text', text: PROMPTS[type] },
      { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${base64}` } },
    ] }],
    response_format: { type: 'json_schema', json_schema: { name: 'coffee_assessment', schema: RESPONSE_SCHEMA } },
  };
}

export function parseCompletion(j: any): Assessment {
  let text = j?.choices?.[0]?.message?.content ?? '';
  if (Array.isArray(text)) text = text.map((p: any) => p.text ?? '').join('');
  text = String(text).trim().replace(/^```(?:json)?\s*|\s*```$/g, '');
  if (!text) throw new GeminiFailed('empty');
  try { return validateResult(JSON.parse(text)); } catch (e) { throw new GeminiFailed((e as Error).message); }
}

/** يقرّب الدرجة لأقرب 5 لثبات أعلى بين الفحوص. */
export const roundScore = (n: number) => Math.min(100, Math.max(0, Math.round(n / 5) * 5));

export async function analyze(apiKey: string, model: string, type: ScanType, base64: string, f: typeof fetch = fetch, timeoutMs = 20000): Promise<Assessment> {
  let res: Response;
  try {
    res = await f(ENDPOINT, {
      method: 'POST', signal: AbortSignal.timeout(timeoutMs),
      headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` },
      body: JSON.stringify(buildBody(type, model, base64)),
    });
  } catch { throw new GeminiFailed('network'); }
  if (res.status === 429) throw new GeminiBusy('429');
  if (!res.ok) throw new GeminiFailed(`http ${res.status}`);
  const a = parseCompletion(await res.json());
  return a.status === 'ok' ? { ...a, score: roundScore(a.score) } : a;
}
