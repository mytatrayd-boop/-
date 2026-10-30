// Sends ONE real test notification to every registered device of a single family,
// found by the sha256 of its owner's email (so the address never appears in logs),
// and prints FCM's answer per device. Prints roles and short ids only.
//   OWNER_EMAIL_SHA256=<hex> GOOGLE_APPLICATION_CREDENTIALS=sa.json node scripts/push-test.mjs
import { createHash } from "node:crypto";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const want = (process.env.OWNER_EMAIL_SHA256 ?? "").trim().toLowerCase();
if (!/^[0-9a-f]{64}$/.test(want)) throw new Error("OWNER_EMAIL_SHA256 must be a sha256 hex");
const sha = (s) => createHash("sha256").update(String(s ?? "").trim().toLowerCase()).digest("hex");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const fcm = getMessaging();

let found = 0;
for (const f of (await db.collection("families").get()).docs) {
  const people = (await f.ref.collection("people").get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  if (!people.some((p) => p.role === "owner" && sha(p.email) === want)) continue;
  found++;
  console.log(`family ${f.id.slice(0, 6)}`);
  for (const p of people) {
    for (const t of p.fcmTokens ?? []) {
      try {
        await fcm.send({
          token: t,
          notification: { title: "🔔 اختبار من أسرتي", body: "هذا تنبيه تجريبي للتأكد من وصول التنبيهات." },
          android: { priority: "high", notification: { channelId: "asraty_alerts", sound: "default" } },
          apns: { headers: { "apns-priority": "10", "apns-push-type": "alert" }, payload: { aps: { sound: "default" } } },
        });
        console.log(`  ${p.role.padEnd(6)} ${p.id.slice(0, 6)} token …${t.slice(-6)}: SENT`);
      } catch (e) {
        console.log(`  ${p.role.padEnd(6)} ${p.id.slice(0, 6)} token …${t.slice(-6)}: ${e.code ?? e.message}`);
      }
    }
  }
}
if (!found) console.log("no family with that owner email");
