import type { Citation, ModelOutput } from "./gemini";
import { normalizeArabic } from "./normalize";
import type { Passage } from "./validate";

/** أقل طول للاقتباس بعد التطبيع (ARCHITECTURE §7، مطابق لمدقق التطبيق). */
export const MIN_QUOTE_CHARS = 12;
export const MAX_CITATIONS = 3;

export type Verified =
  | { found: true; answer: string; citations: Citation[] }
  | { found: false; answer: ""; citations: []; reason: "NOT_FOUND" | "UNVERIFIED" };

/**
 * هل [quote] جزء متصل من نص الفقرة بعد التطبيع؟ المقارنة على حدود الكلمات
 * (مسافة قبل وبعد) حتى لا يُقبل نصف كلمة في الطرفين.
 */
export function quoteInPassage(quote: string, passageText: string): boolean {
  const q = normalizeArabic(quote);
  if (q.length < MIN_QUOTE_CHARS) return false;
  return ` ${normalizeArabic(passageText)} `.includes(` ${q} `);
}

/**
 * تحقق الخادم من رد النموذج (D12): يُبقي فقط الاقتباسات التي معرّفها من
 * الفقرات المرسلة ونصها موجود حرفياً (بعد التطبيع) في تلك الفقرة نفسها.
 * إن لم يبقَ اقتباس صحيح لا تُعاد الإجابة (UNVERIFIED).
 */
export function verifyOutput(output: ModelOutput, passages: Passage[]): Verified {
  if (!output.found) return { found: false, answer: "", citations: [], reason: "NOT_FOUND" };
  const byId = new Map(passages.map((p) => [p.id, p.text]));
  const seen = new Set<string>();
  const citations: Citation[] = [];
  for (const c of output.citations) {
    const text = byId.get(c.paragraph_id);
    if (text === undefined || !quoteInPassage(c.quote, text)) continue;
    const key = `${c.paragraph_id}\u0000${normalizeArabic(c.quote)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    citations.push({ paragraph_id: c.paragraph_id, quote: c.quote });
    if (citations.length === MAX_CITATIONS) break;
  }
  const answer = output.answer.trim();
  if (citations.length === 0 || answer === "") {
    return { found: false, answer: "", citations: [], reason: "UNVERIFIED" };
  }
  return { found: true, answer, citations };
}
