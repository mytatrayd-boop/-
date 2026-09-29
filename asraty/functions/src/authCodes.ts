import { createHash, randomInt } from "node:crypto";
import { onCall } from "firebase-functions/https";
import { db, fam, people, auth, fail, FieldValue, Timestamp } from "./db";
import { AVATAR_KEYS, EMAIL_RE, cleanText, normalizeEmail } from "./logic";
import { RESEND_API_KEY, codeMailText, sendMail } from "./mail";

export const CODE_TTL_MS = 30 * 60 * 1000;
export const MAX_ATTEMPTS = 5;
const MAX_SENDS_PER_HOUR = 5;
const MIN_RESEND_MS = 30 * 1000;

const sha = (s: string) => createHash("sha256").update(s).digest("hex");
export const codeDocId = (email: string) => sha(email);
export const hashCode = (email: string, code: string) => sha(`${email}:${code}`);

/**
 * Creates a fresh 6-digit code for `email`, stores its hash and emails it.
 * Enforces a per-email send rate limit.
 */
export async function issueCode(
  email: string,
  mail: { subject: string; intro: string },
  setup?: { familyName: string; name: string },
): Promise<void> {
  const ref = db.collection("authCodes").doc(codeDocId(email));
  const code = String(randomInt(100000, 1000000));
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data();
    let windowStart = d?.windowStart?.toMillis?.() ?? now;
    let sentCount = d?.sentCount ?? 0;
    if (now - windowStart > 3600 * 1000) {
      windowStart = now;
      sentCount = 0;
    }
    if (sentCount >= MAX_SENDS_PER_HOUR) fail("rate-limited", {}, "resource-exhausted");
    const last = d?.sentAt?.toMillis?.() ?? 0;
    if (now - last < MIN_RESEND_MS) fail("too-soon", { waitSeconds: Math.ceil((MIN_RESEND_MS - (now - last)) / 1000) }, "resource-exhausted");
    tx.set(ref, {
      codeHash: hashCode(email, code),
      expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
      attempts: 0,
      sentCount: sentCount + 1,
      windowStart: Timestamp.fromMillis(windowStart),
      sentAt: Timestamp.fromMillis(now),
      setup: setup ?? null,
    });
  });
  await sendMail({ to: email, subject: mail.subject, text: codeMailText(mail.intro, code) });
}

interface RequestCodeData {
  email?: string;
  role?: "admin" | "member";
  familyName?: string;
  name?: string;
  resend?: boolean;
}

export const requestCode = onCall({ secrets: [RESEND_API_KEY] }, async (req) => {
  const d = (req.data ?? {}) as RequestCodeData;
  const email = normalizeEmail(d.email);
  if (!EMAIL_RE.test(email)) fail("bad-email", {}, "invalid-argument");
  const role = d.role === "admin" ? "admin" : "member";

  const idx = (await db.collection("emailIndex").doc(email).get()).data() as
    | { familyId: string; personId: string; role: string }
    | undefined;

  let setup: { familyName: string; name: string } | undefined;
  if (role === "admin") {
    if (idx?.role === "member") fail("registered-as-member");
    if (!idx) {
      const familyName = cleanText(d.familyName, 60);
      const name = cleanText(d.name, 40);
      if (!familyName || !name) fail("setup-needed");
      setup = { familyName, name };
    }
  } else {
    if (idx && idx.role !== "member") fail("registered-as-admin");
    if (!idx) fail("not-invited");
  }

  // If an unexpired code exists (e.g. from the invite email), don't replace it
  // unless the user explicitly asked to resend — matches the prototype.
  if (!d.resend && !setup) {
    const cur = (await db.collection("authCodes").doc(codeDocId(email)).get()).data();
    if (cur && cur.expiresAt.toMillis() > Date.now() && cur.attempts < 5) return { sent: false, alreadySent: true };
  }

  await issueCode(email, {
    subject: "كود الدخول إلى أسرتي",
    intro: d.resend ? "كود تحقق جديد لتسجيل الدخول إلى تطبيق أسرتي." : "هذا كود التحقق لتسجيل الدخول إلى تطبيق أسرتي.",
  }, setup);
  return { sent: true };
});

export const verifyCode = onCall(async (req) => {
  const email = normalizeEmail(req.data?.email);
  const code = String(req.data?.code ?? "").trim();
  if (!EMAIL_RE.test(email) || !/^\d{6}$/.test(code)) fail("bad-code", {}, "invalid-argument");

  const ref = db.collection("authCodes").doc(codeDocId(email));
  // Check and count the attempt atomically so parallel guesses can't exceed the limit.
  const setup = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const c = snap.data();
    if (!c) fail("bad-code");
    if (c.expiresAt.toMillis() < Date.now()) fail("code-expired");
    if (c.attempts >= MAX_ATTEMPTS) fail("too-many-attempts");
    if (c.codeHash !== hashCode(email, code)) {
      tx.update(ref, { attempts: FieldValue.increment(1) });
      return "wrong" as const;
    }
    tx.delete(ref);
    return (c.setup ?? null) as { familyName: string; name: string } | null;
  });
  if (setup === "wrong") fail("bad-code");

  const idxRef = db.collection("emailIndex").doc(email);
  let familyId: string, personId: string, role: string, first = false;

  if (setup) {
    // New family: create family + owner atomically; refuse if the email got registered meanwhile.
    const famRef = db.collection("families").doc();
    const pRef = famRef.collection("people").doc();
    await db.runTransaction(async (tx) => {
      if ((await tx.get(idxRef)).exists) fail("already-registered");
      tx.set(famRef, { name: setup.familyName, ownerPersonId: pRef.id, createdAt: FieldValue.serverTimestamp() });
      tx.set(pRef, {
        name: setup.name, email, role: "owner", perms: {}, avatar: AVATAR_KEYS[0],
        status: "active", authUid: pRef.id, fcmTokens: [], createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(idxRef, { familyId: famRef.id, personId: pRef.id, role: "owner" });
    });
    familyId = famRef.id;
    personId = pRef.id;
    role = "owner";
    first = true;
  } else {
    const idx = (await idxRef.get()).data();
    if (!idx) fail("not-invited");
    familyId = idx.familyId;
    personId = idx.personId;
    role = idx.role;
    const pRef = people(familyId).doc(personId);
    const p = (await pRef.get()).data();
    if (!p) fail("not-invited");
    first = p.status !== "active";
    await pRef.update({ status: "active", authUid: personId });
  }

  const famName = ((await fam(familyId).get()).data()?.name as string) ?? "";
  const token = await auth.createCustomToken(personId, { familyId, role });
  return { token, familyId, personId, role, familyName: famName, first };
});
