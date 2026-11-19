// Activation codes: each one lets one device use the app for free (no subscription).
// «أسرتي» and «لمحة» have separate codes (their own prefix, hash namespace and collection), so a code works in one app only.
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

export type CodeApp = "asraty" | "lamha";
const CODE_APPS: Record<CodeApp, { prefix: string; ns: string; collection: string }> = {
  asraty: { prefix: "ASR", ns: "asraty-code", collection: "activationCodes" },
  lamha: { prefix: "LAM", ns: "lamha-code", collection: "lamhaCodes" },
};

export const codeHash = (code: string, app: CodeApp = "asraty") =>
  createHash("sha256").update(`${CODE_APPS[app].ns}:${normalizeCode(code)}`).digest("hex");

/** A fresh code like "ASR-7KQ2-M9XD" (or "LAM-…" for «لمحة»). */
export function newCode(app: CodeApp = "asraty"): string {
  const part = () => Array.from({ length: 4 }, () => ALPHABET[randomInt(ALPHABET.length)]).join("");
  return `${CODE_APPS[app].prefix}-${part()}-${part()}`;
}

export const codeRef = (code: string, app: CodeApp = "asraty") => db.collection(CODE_APPS[app].collection).doc(codeHash(code, app));

/** «لمحة»: the same rules as «أسرتي», with its own codes. */
export const lamhaRedeem = (data: unknown, ctx: CallContext) => redeemCode(data, ctx, "lamha");

/** Binds a code to a device (first use) or confirms it on the same device. */
export async function redeemCode(data: unknown, ctx: CallContext, app: CodeApp = "asraty") {
  const d = (data ?? {}) as Record<string, unknown>;
  const code = normalizeCode(d.code);
  const deviceId = cleanText(d.deviceId, 120);
  if (code.length < 6 || code.length > 20 || deviceId.length < 8) fail("code-invalid", {}, "invalid-argument");

  // Guessing is rate-limited per device and per network address.
  const bucket = createHash("sha256").update(`${app === "asraty" ? "" : `${app}|`}${deviceId}|${ctx.ip ?? ""}`).digest("hex");
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

  const ref = codeRef(code, app);
  await db.runTransaction(async (tx) => {
    const c = (await tx.get(ref)).data();
    if (!c || c.disabled) fail("code-invalid", {}, "not-found");
    if (c.deviceId && c.deviceId !== deviceId) fail("code-used");
    if (!c.deviceId) tx.update(ref, { deviceId, usedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
}
