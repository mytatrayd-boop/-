// Read-only push diagnosis: for every family, which parents have a device
// registered for notifications, and what FCM says about each token in a dry
// run (nothing is delivered to anyone), and the latest notices (kind, target, time; no text).
// Prints roles and short ids only.
//   GOOGLE_APPLICATION_CREDENTIALS=sa.json node scripts/push-check.mjs
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const fcm = getMessaging();

const fams = await db.collection("families").get();
for (const f of fams.docs) {
  console.log(`\nfamily ${f.id.slice(0, 6)}`);
  const people = await f.ref.collection("people").get();
  for (const p of people.docs) {
    const x = p.data();
    const tokens = x.fcmTokens ?? [];
    const perms = Object.keys(x.perms ?? {}).filter((k) => x.perms[k]).join(",") || "-";
    console.log(`  ${x.role.padEnd(6)} ${p.id.slice(0, 6)} status=${x.status} perms=${perms} tokens=${tokens.length}`);
    for (const t of tokens) {
      try {
        await fcm.send({ token: t, notification: { title: "check", body: "check" }, apns: { payload: { aps: { sound: "default" } } } }, true);
        console.log(`    token …${t.slice(-6)}: OK`);
      } catch (e) {
        console.log(`    token …${t.slice(-6)}: ${e.code ?? e.message}`);
      }
    }
  }
  const notes = await f.ref.collection("notifications").orderBy("createdAt", "desc").limit(6).get();
  for (const n of notes.docs) {
    const x = n.data();
    const to = x.to === "all" ? "all" : String(x.to).slice(0, 6);
    console.log(`  notice ${x.kind ?? "notice"} to=${to} at=${x.createdAt?.toDate().toISOString() ?? "-"}`);
  }
}
