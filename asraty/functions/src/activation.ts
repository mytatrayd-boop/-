// Activation codes: each one lets one device use the app for free (no subscription).
// Codes are made by scripts/make-codes.mjs (stored hashed, emailed to the owner).
// Once a code is used on a device, it only works again on that same device.
import { createHash, randomInt } from "node:crypto";
import { db, fail, FieldValue, Timestamp, CallContext } from "./db";
import { cleanText } from "./logic";

/** No 0/O, 1/I/L: easy to read out and type. */
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const MAX_TRIES_PER_HOUR = 10;

/** Upper case, spaces and dashes dropped: "asr-ab12 cd34" → "ASRAB12CD34". */
export const normalizeCode = (v: unknown) => String(v ?? "").toUpperCase().replace(/[\s-]/g, "");

export const codeHash = (code: string) => createHash("sha256").update(`asraty-code:${normalizeCode(code)}`).digest("hex");

/** A fresh code like "ASR-7KQ2-M9XD". */
export function newCode(): string {
  const part = () => Array.from({ length: 4 }, () => ALPHABET[randomInt(ALPHABET.length)]).join("");
  return `ASR-${part()}-${part()}`;
}

export const codeRef = (code: string) => db.collection("activationCodes").doc(codeHash(code));

/** Binds a code to a device (first use) or confirms it on the same device. */
export async function redeemCode(data: unknown, ctx: CallContext) {
  const d = (data ?? {}) as Record<string, unknown>;
  const code = normalizeCode(d.code);
  const deviceId = cleanText(d.deviceId, 120);
  if (code.length < 6 || code.length > 20 || deviceId.length < 8) fail("code-invalid", {}, "invalid-argument");

  // Guessing is rate-limited per device and per network address.
  const bucket = createHash("sha256").update(`${deviceId}|${ctx.ip ?? ""}`).digest("hex");
  const rateRef = db.collection("codeTries").doc(bucket);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const r = (await tx.get(rateRef)).data();
    const start = r?.windowStart?.toMillis?.() ?? 0;
    const fresh = now - start > 3600e3;
    const n = fresh ? 0 : r?.n ?? 0;
    if (n >= MAX_TRIES_PER_HOUR) fail("rate-limited", {}, "resource-exhausted");
    tx.set(rateRef, { n: n + 1, windowStart: fresh ? Timestamp.fromMillis(now) : r!.windowStart });
  });

  const ref = codeRef(code);
  await db.runTransaction(async (tx) => {
    const c = (await tx.get(ref)).data();
    if (!c || c.disabled) fail("code-invalid", {}, "not-found");
    if (c.deviceId && c.deviceId !== deviceId) fail("code-used");
    if (!c.deviceId) tx.update(ref, { deviceId, usedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
}
