import { getFirestore, FieldValue } from "firebase-admin/firestore";
import nodemailer from "nodemailer";

// Configuration comes from environment variables (Vercel / Netlify env, or
// functions/.env + secrets when running as Cloud Functions):
//   GMAIL_USER + GMAIL_APP_PASSWORD  → send through Gmail (no domain needed)
//   RESEND_API_KEY + MAIL_FROM       → send through Resend (needs a verified domain)
//   SUPPORT_EMAIL                    → where feedback goes
export const supportEmail = () => process.env.SUPPORT_EMAIL || "asraty200@gmail.com";

const esc = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

function html(body: string): string {
  return `<!doctype html><html lang="ar" dir="rtl"><body style="margin:0;background:#F6F2E8;font-family:Tahoma,Arial,sans-serif;color:#1E302C">
<div style="max-width:520px;margin:24px auto;background:#fff;border-radius:16px;padding:24px;direction:rtl;text-align:right">
<div style="font-size:22px;font-weight:bold;color:#2F6158;margin-bottom:12px">أسرتي</div>
<div style="white-space:pre-wrap;line-height:1.7;font-size:15px">${esc(body)}</div>
</div></body></html>`;
}

export interface Mail {
  to: string;
  subject: string;
  text: string;
  replyTo?: string;
}

let transport: nodemailer.Transporter | undefined;

/**
 * Sends a transactional email. With the Firestore emulator (local dev and
 * tests) the message is stored in `devMail` instead of being sent.
 */
export async function sendMail(mail: Mail): Promise<void> {
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === "true") {
    console.info(`[mail:dev] to=${mail.to} subject=${mail.subject}\n${mail.text}`);
    await getFirestore().collection("devMail").add({ to: mail.to, subject: mail.subject, text: mail.text, createdAt: FieldValue.serverTimestamp() });
    return;
  }

  const gmailUser = process.env.GMAIL_USER, gmailPass = process.env.GMAIL_APP_PASSWORD;
  if (gmailUser && gmailPass) {
    transport ??= nodemailer.createTransport({
      service: "gmail",
      auth: { user: gmailUser, pass: gmailPass.replace(/\s+/g, "") },
    });
    await transport.sendMail({
      from: { name: "أسرتي", address: gmailUser },
      to: mail.to,
      subject: mail.subject,
      text: mail.text,
      html: html(mail.text),
      ...(mail.replyTo ? { replyTo: mail.replyTo } : {}),
    });
    return;
  }

  const key = process.env.RESEND_API_KEY;
  if (!key) {
    console.error("No mail provider configured (GMAIL_USER/GMAIL_APP_PASSWORD or RESEND_API_KEY)", mail.to, mail.subject);
    throw new Error("mail-not-configured");
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: process.env.MAIL_FROM || "أسرتي <onboarding@resend.dev>",
      to: [mail.to],
      subject: mail.subject,
      text: mail.text,
      html: html(mail.text),
      ...(mail.replyTo ? { reply_to: mail.replyTo } : {}),
    }),
  });
  if (!res.ok) {
    console.error("Resend error", res.status, await res.text());
    throw new Error("mail-failed");
  }
}

export function codeMailText(intro: string, code: string): string {
  return `${intro}\n\nكود التحقق: ${code}\nصالح لمدة 30 دقيقة.\n\nإذا لم تطلب هذا الكود فتجاهل الرسالة.`;
}
