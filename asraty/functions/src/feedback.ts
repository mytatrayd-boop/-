import { db, fam, people, fail, FieldValue, CallContext } from "./db";
import { EMAIL_RE, cleanText, normalizeEmail } from "./logic";
import { sendMail, supportEmail } from "./mail";

const TYPES: Record<string, string> = { suggestion: "اقتراح", complaint: "شكوى", bug: "مشكلة تقنية" };
const ROLE_LABEL: Record<string, string> = { owner: "مسؤول الأسرة", admin: "مسؤول مفوَّض", member: "عضو" };

/** Suggestions & complaints. Works before and after sign-in. */
export async function sendFeedback(data: unknown, ctx: CallContext) {
  const d = (data ?? {}) as Record<string, string>;
  const type = TYPES[d.type] ? String(d.type) : "suggestion";
  const text = cleanText(d.text, 2000);
  if (text.length < 5) fail("too-short", {}, "invalid-argument");
  const platform = cleanText(d.platform, 40);

  const fid = ctx.familyId;
  const pid = ctx.uid;
  let name = "زائر", role = "", email = normalizeEmail(d.email), famName = "";
  if (fid && pid) {
    const [p, f] = await Promise.all([people(fid).doc(pid).get(), fam(fid).get()]);
    if (p.exists) {
      name = p.data()!.name;
      role = p.data()!.role;
      email = p.data()!.email;
    }
    famName = f.data()?.name ?? "";
  } else {
    if (email && !EMAIL_RE.test(email)) fail("bad-email", {}, "invalid-argument");
    // Anonymous sends are rate-limited per email/IP bucket to limit spam.
    const key = (email || ctx.ip || "anon").replace(/[^\w@.-]/g, "_").slice(0, 100);
    const ref = db.collection("feedbackRate").doc(key);
    await db.runTransaction(async (tx) => {
      const r = (await tx.get(ref)).data();
      const now = Date.now();
      const count = r && now - r.windowStart < 3600e3 ? r.count : 0;
      if (count >= 5) fail("rate-limited", {}, "resource-exhausted");
      tx.set(ref, { windowStart: count ? r!.windowStart : now, count: count + 1 });
    });
  }

  await db.collection("feedback").add({
    type, text, email: email || null, familyId: fid ?? null, personId: pid ?? null, role: role || null,
    platform, createdAt: FieldValue.serverTimestamp(),
  });

  await sendMail({
    to: supportEmail(),
    subject: `[${TYPES[type]}] من ${name}${famName ? " — " + famName : ""}`,
    text:
      `${text}\n\n— المرسل: ${fid ? `${name} (${ROLE_LABEL[role] ?? role})` : "مستخدم غير مسجّل"}` +
      `\n— البريد: ${email || "لم يُذكر"}\n— الأسرة: ${famName || "—"}\n— الجهاز: ${platform || "—"}`,
    replyTo: email || undefined,
  }).catch((e) => console.error("feedback mail failed", e));
  return { ok: true };
}
