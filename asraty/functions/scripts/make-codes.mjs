// Makes free-use activation codes and emails them to the owner (SUPPORT_EMAIL).
// Only their hashes are stored, so the codes never appear in logs or the database.
//   GOOGLE_APPLICATION_CREDENTIALS=sa.json GMAIL_USER=… GMAIL_APP_PASSWORD=… node scripts/make-codes.mjs 20
import { Timestamp } from "firebase-admin/firestore";
import { codeRef, newCode } from "../build/src/activation.js";
import { sendMail, supportEmail } from "../build/src/mail.js";

const n = Math.min(Math.max(parseInt(process.argv[2] ?? "10", 10) || 10, 1), 200);
const note = String(process.argv[3] ?? "").slice(0, 80);
const codes = [];
while (codes.length < n) {
  const code = newCode();
  const ref = codeRef(code);
  if ((await ref.get()).exists) continue;
  await ref.set({ deviceId: null, usedAt: null, createdAt: Timestamp.now(), note, disabled: false });
  codes.push(code);
}
await sendMail({
  to: supportEmail(),
  subject: `أكواد تفعيل أسرتي (${n})`,
  text: `هذه ${n} أكواد تفعيل جديدة${note ? ` (${note})` : ""}.\nكل كود يفعّل التطبيق مجاناً على جهاز واحد فقط، وبعد استخدامه لا يعمل على جهاز آخر.\n\n${codes.join("\n")}`,
});
console.log(`made ${n} codes and emailed them to the support address`);
