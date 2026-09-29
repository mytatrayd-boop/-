import { defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
export const MAIL_FROM = defineString("MAIL_FROM", { default: "أسرتي <onboarding@resend.dev>" });
export const SUPPORT_EMAIL = defineString("SUPPORT_EMAIL", { default: "asraty200@gmail.com" });

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

/**
 * Sends a transactional email through Resend. Without an API key (local
 * emulator), the message is logged instead so codes can be read from the
 * emulator logs.
 */
export async function sendMail(mail: Mail): Promise<void> {
  let key = "";
  try {
    key = RESEND_API_KEY.value();
  } catch {
    key = "";
  }
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    // Local development: keep a readable copy (visible in the Emulator UI and used by tests).
    logger.info(`[mail:dev] to=${mail.to} subject=${mail.subject}\n${mail.text}`);
    await getFirestore().collection("devMail").add({ to: mail.to, subject: mail.subject, text: mail.text, createdAt: FieldValue.serverTimestamp() });
    return;
  }
  if (!key) {
    logger.error("RESEND_API_KEY is not set; email not sent", mail.to, mail.subject);
    throw new Error("mail-not-configured");
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: MAIL_FROM.value(),
      to: [mail.to],
      subject: mail.subject,
      text: mail.text,
      html: html(mail.text),
      ...(mail.replyTo ? { reply_to: mail.replyTo } : {}),
    }),
  });
  if (!res.ok) {
    logger.error("Resend error", res.status, await res.text());
    throw new Error("mail-failed");
  }
}

export function codeMailText(intro: string, code: string): string {
  return `${intro}\n\nكود التحقق: ${code}\nصالح لمدة 30 دقيقة.\n\nإذا لم تطلب هذا الكود فتجاهل الرسالة.`;
}
