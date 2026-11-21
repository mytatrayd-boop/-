// Email + password sign-in. A password is set (or reset) by proving the email
// with a 6-digit code first (requestCode with `password`, then verifyCode).
// Hashes live in credentials/{sha256(email)}, server-only.
import { createHash, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { db, fail, fam, people, auth, Timestamp, CallContext } from "./db";
import { EMAIL_RE, normalizeEmail } from "./logic";

export const MIN_PASSWORD = 6;
const MAX_FAILS = 5;
const LOCK_MS = 15 * 60 * 1000;

export const credRef = (email: string) => db.collection("credentials").doc(createHash("sha256").update(email).digest("hex"));

export function checkPassword(v: unknown): string {
  const p = String(v ?? "");
  if (p.length < MIN_PASSWORD || p.length > 128) fail("weak-password", { min: MIN_PASSWORD }, "invalid-argument");
  return p;
}

export function hashPassword(password: string): { salt: string; hash: string } {
  const salt = randomBytes(16).toString("hex");
  return { salt, hash: scryptSync(password, salt, 32).toString("hex") };
}

function matches(password: string, salt: string, hash: string): boolean {
  const a = scryptSync(password, salt, 32), b = Buffer.from(hash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

export async function login(data: unknown, _ctx: CallContext) {
  const d = (data ?? {}) as { email?: string; password?: string };
  const email = normalizeEmail(d.email);
  const password = String(d.password ?? "");
  if (!EMAIL_RE.test(email)) fail("bad-email", {}, "invalid-argument");
  const idx = (await db.collection("emailIndex").doc(email).get()).data() as
    | { familyId: string; personId: string; role: string }
    | undefined;
  const ref = credRef(email);
  const cred = (await ref.get()).data();
  if (!idx) fail("bad-login");
  // Accounts from before passwords existed (or invited, not yet linked) set one with a code first.
  if (!cred) fail("no-password");
  const now = Date.now();
  if ((cred.lockUntil?.toMillis?.() ?? 0) > now) fail("locked", { waitMinutes: Math.ceil((cred.lockUntil.toMillis() - now) / 60000) });
  if (!matches(password, cred.salt, cred.hash)) {
    const fails = (cred.fails ?? 0) + 1;
    await ref.update(fails >= MAX_FAILS ? { fails: 0, lockUntil: Timestamp.fromMillis(now + LOCK_MS) } : { fails });
    fail("bad-login");
  }
  if (cred.fails) await ref.update({ fails: 0 });
  const p = (await people(idx.familyId).doc(idx.personId).get()).data();
  if (!p) fail("bad-login");
  if (p.status !== "active") await people(idx.familyId).doc(idx.personId).update({ status: "active", authUid: idx.personId });
  const famName = ((await fam(idx.familyId).get()).data()?.name as string) ?? "";
  const token = await auth.createCustomToken(idx.personId, { familyId: idx.familyId, role: idx.role });
  return { token, familyId: idx.familyId, personId: idx.personId, role: idx.role, familyName: famName, name: p.name ?? "", first: false };
}
