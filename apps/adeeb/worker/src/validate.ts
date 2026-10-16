import type { Config } from "./config";

/** فقرة مرسلة من التطبيق (ARCHITECTURE §8.1). */
export interface Passage {
  id: string;
  book: string;
  chapter: string;
  text: string;
}

export interface AskRequest {
  v: 1;
  lang: "ar" | "en";
  question: string;
  passages: Passage[];
}

export type Validation<T> = { ok: true; value: T } | { ok: false; code: "BAD_REQUEST" | "UPGRADE_REQUIRED" };

/** معرّف الفقرة (ARCHITECTURE §4.2): `<book>-b\d{3}-p\d{5}`. */
export const PARAGRAPH_ID = /^(?:[a-z]{2,12}|o\d{5})-b\d{3,4}-p\d{5}$/;
const DEVICE_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CLIENT = /^adeeb-(android|ios)\/(\d{1,9})$/;
const MAX_TITLE_CHARS = 200;
const MIN_QUESTION_CHARS = 2;

const bad = { ok: false, code: "BAD_REQUEST" } as const;

/** معرّف الجهاز (UUID v4)، بحروف صغيرة ليكون مفتاحه ثابتاً. */
export function readDeviceId(headers: Headers): string | null {
  const id = headers.get("X-Device-Id");
  return id !== null && DEVICE_ID.test(id) ? id.toLowerCase() : null;
}

/** `X-Client: adeeb-android/<build>`؛ أقدم من MIN_CLIENT ← 426. */
export function checkClient(headers: Headers, config: Config): Validation<number> {
  const match = CLIENT.exec(headers.get("X-Client") ?? "");
  if (!match) return bad;
  const build = Number(match[2]);
  if (build < config.minClient) return { ok: false, code: "UPGRADE_REQUIRED" };
  return { ok: true, value: build };
}

function isPlainObject(x: unknown): x is Record<string, unknown> {
  return typeof x === "object" && x !== null && !Array.isArray(x);
}

function hasExactly(obj: Record<string, unknown>, keys: readonly string[]): boolean {
  const own = Object.keys(obj);
  return own.length === keys.length && keys.every((k) => Object.hasOwn(obj, k));
}

/** نص صالح: سلسلة غير فارغة بعد حذف المسافات، بلا محارف تحكم غير \n و\t. */
function isCleanText(x: unknown, max: number, min = 1): x is string {
  if (typeof x !== "string") return false;
  if (x.trim().length < min || x.length > max) return false;
  // eslint-disable-next-line no-control-regex
  return !/[\u0000-\u0008\u000B-\u001F\u007F]/.test(x);
}

/**
 * تحقق صارم من جسم `POST /v1/ask` (ARCHITECTURE §8.4): لا حقول إضافية، حدود
 * الطول والعدد، معرّفات بالنمط وفريدة. أي مخالفة ← BAD_REQUEST.
 */
export function validateAsk(body: unknown, config: Config): Validation<AskRequest> {
  if (!isPlainObject(body) || !hasExactly(body, ["v", "lang", "question", "passages"])) {
    return bad;
  }
  const { v, lang, question, passages } = body;
  if (typeof v !== "number" || !Number.isInteger(v)) return bad;
  if (v < 1) return { ok: false, code: "UPGRADE_REQUIRED" };
  if (v !== 1) return bad;
  if (lang !== "ar" && lang !== "en") return bad;
  if (!isCleanText(question, config.maxQuestionChars, MIN_QUESTION_CHARS)) return bad;
  if (!Array.isArray(passages) || passages.length < 1 || passages.length > config.maxPassages) {
    return bad;
  }
  const ids = new Set<string>();
  let total = 0;
  const out: Passage[] = [];
  for (const p of passages) {
    if (!isPlainObject(p) || !hasExactly(p, ["id", "book", "chapter", "text"])) return bad;
    const { id, book, chapter, text } = p;
    if (typeof id !== "string" || !PARAGRAPH_ID.test(id) || ids.has(id)) return bad;
    if (!isCleanText(book, MAX_TITLE_CHARS) || !isCleanText(chapter, MAX_TITLE_CHARS)) return bad;
    if (!isCleanText(text, config.maxPassageChars)) return bad;
    total += text.length;
    if (total > config.maxPassagesTotalChars) return bad;
    ids.add(id);
    out.push({ id, book, chapter, text });
  }
  return { ok: true, value: { v: 1, lang, question: question.trim(), passages: out } };
}
