// End-to-end tests of the callable functions against the Firebase emulators.
// Run with: npm run test:api (builds, then starts auth/firestore/functions/storage emulators).
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const PROJECT = "demo-asraty";
const FN = process.env.API_BASE ?? "http://127.0.0.1:5055/api";
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";

initializeApp({ projectId: PROJECT });
const db = getFirestore();

async function call(name, data, idToken) {
  const res = await fetch(`${FN}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  if (body.error) {
    const e = new Error(body.error.message);
    e.code = body.error.details?.code ?? body.error.message;
    throw e;
  }
  return body.result;
}

const rejects = (p, code) => assert.rejects(p, (e) => (assert.equal(e.code, code), true));

async function lastCode(email) {
  const snap = await db.collection("devMail").where("to", "==", email).get();
  const mails = snap.docs.map((d) => d.data()).sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis());
  return /كود التحقق: (\d{6})/.exec(mails[0].text)[1];
}

async function signIn(token) {
  const r = await fetch(`${AUTH}/accounts:signInWithCustomToken?key=fake`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token, returnSecureToken: true }),
  });
  return (await r.json()).idToken;
}

async function login(email, role, extra = {}) {
  await call("requestCode", { email, role, resend: true, ...extra }).catch((e) => {
    if (e.code !== "too-soon") throw e;
  });
  const v = await call("verifyCode", { email, code: await lastCode(email) });
  return { ...v, idToken: await signIn(v.token) };
}

// Avoid the 30s resend limit between logins of the same email.
const clearRate = (email) => db.collection("authCodes").get().then((s) => Promise.all(s.docs.map((d) => d.ref.delete()))).then(() => email);

let owner, fid;

before(async () => {
  owner = await login("abu@test.sa", "admin", { familyName: "أسرة آل محمد", name: "أبو أصيل" });
  fid = owner.familyId;
});

test("owner created the family", async () => {
  assert.equal(owner.role, "owner");
  assert.equal(owner.first, true);
  const fam = await db.doc(`families/${fid}`).get();
  assert.equal(fam.data().name, "أسرة آل محمد");
});

test("login errors", async () => {
  await rejects(call("requestCode", { email: "nobody@test.sa", role: "member" }), "not-invited");
  await rejects(call("requestCode", { email: "bad", role: "member" }), "bad-email");
  await rejects(call("api", { op: "addTask" }), "unauthenticated");
});

test("invite member, wrong-role guidance, code attempts", async () => {
  await call("api", { op: "addPerson", role: "member", name: "أصيل", email: "aseel@test.sa", avatar: "boy" }, owner.idToken);
  await rejects(call("api", { op: "addPerson", role: "member", name: "x", email: "aseel@test.sa" }, owner.idToken), "email-taken");
  await rejects(call("requestCode", { email: "aseel@test.sa", role: "admin" }), "registered-as-member");
  // Invite code already sent → not re-sent without resend.
  assert.deepEqual(await call("requestCode", { email: "aseel@test.sa", role: "member" }), { sent: false, alreadySent: true });
  for (let i = 0; i < 5; i++) await rejects(call("verifyCode", { email: "aseel@test.sa", code: "000000" }), "bad-code");
  await rejects(call("verifyCode", { email: "aseel@test.sa", code: await lastCode("aseel@test.sa") }), "too-many-attempts");
});

test("task → completion → approval → points in summaries", async () => {
  await clearRate();
  const kid = await login("aseel@test.sa", "member");
  assert.equal(kid.role, "member");
  await rejects(call("api", { op: "addTask", title: "x", personId: "all", points: 5 }, kid.idToken), "no-permission");

  await call("api", { op: "addTask", title: "ترتيب السرير", personId: "all", points: 5, repeat: "daily" }, owner.idToken);
  const task = (await db.collection(`families/${fid}/tasks`).get()).docs[0];
  await rejects(call("api", { op: "completeTask", taskId: task.id, photo: "bm90LWFuLWltYWdl" }, kid.idToken), "bad-photo");
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]).toString("base64");
  await call("api", { op: "completeTask", taskId: task.id, photo: jpeg }, kid.idToken);
  await rejects(call("api", { op: "completeTask", taskId: task.id }, kid.idToken), "already-done");

  const comp = (await db.collection(`families/${fid}/completions`).get()).docs[0];
  assert.equal(comp.data().hasPhoto, true);
  assert.equal((await db.doc(`families/${fid}/proofs/${comp.id}`).get()).data().data, jpeg);
  await call("api", { op: "decideCompletion", completionId: comp.id, approve: true }, owner.idToken);
  await rejects(call("api", { op: "decideCompletion", completionId: comp.id, approve: true }, owner.idToken), "already-decided");
  assert.equal((await db.doc(`families/${fid}/proofs/${comp.id}`).get()).exists, false, "proof deleted after decision");

  const sums = (await db.collection(`families/${fid}/summaries`).where("personId", "==", kid.personId).get()).docs.map((d) => d.data());
  assert.equal(sums.length, 4); // today + this week + this month + this year (honor board)
  assert.ok(sums.some((s) => s.periodKey.startsWith("m")) && sums.some((s) => s.periodKey.startsWith("y")));
  assert.ok(sums.every((s) => s.points === 5 && s.count === 1));
  const ledger = await db.collection(`families/${fid}/ledger`).get();
  assert.equal(ledger.size, 1);
});

test("delegated admin only gets granted permissions", async () => {
  await call("api", { op: "addPerson", role: "admin", name: "أم أصيل", email: "um@test.sa", avatar: "mom", perms: { tasks: true, bogus: true } }, owner.idToken);
  await clearRate();
  const admin = await login("um@test.sa", "admin");
  assert.equal(admin.role, "admin");
  const me = await db.doc(`families/${fid}/people/${admin.personId}`).get();
  assert.deepEqual(Object.keys(me.data().perms).filter((k) => me.data().perms[k]), ["tasks"]);
  await call("api", { op: "addTask", title: "مراجعة", personId: "all", points: 3 }, admin.idToken);
  // The Android SDK wraps whole numbers the way the callable protocol encodes longs.
  await call("api", { op: "addTask", title: "رقم أندرويد", personId: "all", points: { "@type": "type.googleapis.com/google.protobuf.Int64Value", value: "7" } }, admin.idToken);
  const wrapped = (await db.collection(`families/${fid}/tasks`).where("title", "==", "رقم أندرويد").get()).docs;
  assert.ok(wrapped.length > 0 && wrapped.every((d) => d.data().points === 7));
  // iOS sends whole numbers the same way: a reward tier's threshold must arrive as a number.
  await call("api", { op: "addTier", name: "مستوى آيفون", emoji: "🎁", threshold: { "@type": "type.googleapis.com/google.protobuf.Int64Value", value: "30" }, period: "daily", scope: "each" }, owner.idToken);
  const tier = (await db.collection(`families/${fid}/tiers`).where("name", "==", "مستوى آيفون").get()).docs;
  assert.ok(tier.length === 1 && tier[0].data().threshold === 30);
  await rejects(call("api", { op: "addTier", name: "x", threshold: 5 }, admin.idToken), "no-permission");
  await rejects(call("api", { op: "addPerson", role: "member", name: "y", email: "y@test.sa" }, admin.idToken), "no-permission");
});

test("competition ranks are unique under simultaneous taps", async () => {
  const kids = [];
  for (const [i, n] of ["لمى", "سلمان", "ريم", "فهد"].entries()) {
    const email = `kid${i}@test.sa`;
    await call("api", { op: "addPerson", role: "member", name: n, email, avatar: "girl" }, owner.idToken);
    await clearRate();
    kids.push(await login(email, "member"));
  }
  await call("api", { op: "addCompetition", title: "أسرع من يرتّب غرفته", startPoints: 20, minutes: 0 }, owner.idToken);
  const compId = (await db.collection(`families/${fid}/competitions`).get()).docs[0].id;
  const results = await Promise.all(kids.map((k) => call("api", { op: "enterCompetition", compId }, k.idToken)));
  assert.deepEqual(results.map((r) => r.rank).sort(), [1, 2, 3, 4]);
  for (const r of results) assert.equal(r.points, 21 - r.rank);
  await rejects(call("api", { op: "enterCompetition", compId }, kids[0].idToken), "already-entered");
  await call("api", { op: "endCompetition", compId }, owner.idToken);
  const late = await login("aseel@test.sa", "member").catch(() => null);
  if (late) await rejects(call("api", { op: "enterCompetition", compId }, late.idToken), "comp-over");
});

test("family goals, timed alerts and private rewards", async () => {
  await clearRate();
  const kid = await login("kid1@test.sa", "member");
  await rejects(call("api", { op: "addGoal", title: "x", target: 3 }, kid.idToken), "no-permission");
  await call("api", { op: "addGoal", title: "قراءة كتب", target: 3, period: "yearly", personId: "family" }, owner.idToken);
  const goal = (await db.collection(`families/${fid}/goals`).get()).docs[0];
  assert.equal(goal.data().periodKey[0], "y");
  for (let i = 0; i < 5; i++) await call("api", { op: "goalProgress", goalId: goal.id, delta: 1 }, owner.idToken);
  assert.equal((await goal.ref.get()).data().progress, 3, "progress is capped at the target");
  const reached = await db.collection(`families/${fid}/notifications`).where("title", "==", "🎉 تحقق الهدف").get();
  assert.equal(reached.size, 1, "one notice when the goal is reached");
  await call("api", { op: "deleteGoal", goalId: goal.id }, owner.idToken);
  assert.equal((await goal.ref.get()).exists, false);

  await call("api", { op: "sendAlert", to: kid.personId, body: "العشاء جاهز", minutes: 30 }, owner.idToken);
  const alert = (await db.collection(`families/${fid}/notifications`).where("body", "==", "العشاء جاهز").get()).docs[0];
  const left = alert.data().expiresAt.toMillis() - Date.now();
  assert.ok(left > 29 * 60000 && left <= 30 * 60000);
  await rejects(call("api", { op: "deleteAlert", noticeId: alert.id }, kid.idToken), "no-permission");
  await call("api", { op: "deleteAlert", noticeId: alert.id }, owner.idToken);
  assert.equal((await alert.ref.get()).exists, false);

  await call("api", { op: "addTier", name: "دراجة", emoji: "🎁", threshold: 50, period: "weekly", scope: "family", personId: kid.personId }, owner.idToken);
  const priv = (await db.collection(`families/${fid}/tiers`).where("name", "==", "دراجة").get()).docs[0].data();
  assert.equal(priv.personId, kid.personId);
  assert.equal(priv.scope, "each", "a private reward always counts the member's own points");
});

test("removed member loses access; account deletion", async () => {
  await clearRate();
  const kid = await login("kid3@test.sa", "member");
  await call("api", { op: "sendAlert", to: kid.personId, body: "تنبيه خاص" }, owner.idToken);
  await call("api", { op: "addTier", name: "هدية خاصة", threshold: 5, period: "daily", personId: kid.personId }, owner.idToken);
  await call("api", { op: "removePerson", personId: kid.personId }, owner.idToken);
  assert.equal((await db.collection(`families/${fid}/notifications`).where("to", "==", kid.personId).get()).size, 0, "their alerts are removed");
  assert.equal((await db.collection(`families/${fid}/tiers`).where("personId", "==", kid.personId).get()).size, 0, "their private rewards are removed");
  // Rejected either at token verification (auth user deleted) or by the people-doc check.
  await assert.rejects(call("api", { op: "markRead" }, kid.idToken), (e) => ["removed", "unauthenticated"].includes(e.code));
  assert.equal((await db.doc("emailIndex/kid3@test.sa").get()).exists, false);

  await clearRate();
  const k2 = await login("kid2@test.sa", "member");
  await call("api", { op: "deleteAccount" }, k2.idToken);
  assert.equal((await db.doc(`families/${fid}/people/${k2.personId}`).get()).exists, false);
  await rejects(call("api", { op: "deleteAccount" }, owner.idToken), "owner-must-delete-family");
});

test("feedback works before sign-in", async () => {
  await call("sendFeedback", { type: "suggestion", text: "أتمنى إضافة مهام خاصة برمضان", platform: "test" });
  const fb = await db.collection("feedback").get();
  assert.equal(fb.size, 1);
  const mail = await db.collection("devMail").where("to", "==", "asraty200@gmail.com").get();
  assert.equal(mail.size, 1);
});

test("owner deletes the whole family", async () => {
  await call("api", { op: "deleteFamily" }, owner.idToken);
  assert.equal((await db.doc(`families/${fid}`).get()).exists, false);
  assert.equal((await db.collection(`families/${fid}/people`).get()).size, 0);
  assert.equal((await db.doc("emailIndex/abu@test.sa").get()).exists, false);
});
