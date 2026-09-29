import { onCall, CallableRequest } from "firebase-functions/https";
import {
  db, fam, people, auth, storage, fail, push, deleteProof, deleteTree, getPeople,
  FieldValue, Timestamp, Person,
} from "./db";
import {
  AVATAR_KEYS, EMAIL_RE, PermKey, Period, REWARD_EMOJI, Scope,
  can, cleanPerms, cleanText, competitionPoints, dayKey, normalizeEmail, periodKey, reportText, weekKey,
} from "./logic";
import { issueCode } from "./authCodes";
import { RESEND_API_KEY } from "./mail";

interface Ctx {
  fid: string;
  me: Person;
  famName: string;
  data: Record<string, unknown>;
}

type Handler = (c: Ctx) => Promise<unknown>;

const str = (v: unknown, max = 200) => cleanText(v, max);
const int = (v: unknown, min: number, max: number) => {
  const n = Math.floor(Number(v));
  if (!Number.isFinite(n) || n < min || n > max) fail("bad-number", { min, max }, "invalid-argument");
  return n;
};
const period = (v: unknown): Period => (v === "weekly" ? "weekly" : "daily");
const scope = (v: unknown): Scope => (v === "family" ? "family" : "each");
const avatar = (v: unknown) => ((AVATAR_KEYS as readonly string[]).includes(String(v)) ? String(v) : null);

function need(c: Ctx, perm: PermKey | "owner") {
  if (perm === "owner" ? c.me.role !== "owner" : !can(c.me, perm)) fail("no-permission", { perm }, "permission-denied");
}

async function person(fid: string, id: unknown): Promise<Person> {
  const snap = await people(fid).doc(String(id ?? "")).get();
  if (!snap.exists) fail("person-not-found", {}, "not-found");
  return { id: snap.id, ...(snap.data() as Omit<Person, "id">) };
}

async function notify(fid: string, to: string, title: string, body: string, from: string) {
  await fam(fid).collection("notifications").add({
    to, title, body, from, createdAt: FieldValue.serverTimestamp(), readBy: [],
  });
  const all = await getPeople(fid);
  const targets = all.filter((p) => p.role === "member" && (to === "all" || p.id === to));
  await push(fid, targets, title, body);
}

/** Writes a ledger entry and bumps the per-person day/week summaries in one transaction. */
function addPoints(tx: FirebaseFirestore.Transaction, fid: string, personId: string, delta: number, reason: string, source: string) {
  const now = Date.now();
  const f = fam(fid);
  tx.set(f.collection("ledger").doc(), {
    personId, delta, reason, source, createdAt: FieldValue.serverTimestamp(), dayKey: dayKey(now), weekKey: weekKey(now),
  });
  for (const key of [dayKey(now), weekKey(now)]) {
    tx.set(f.collection("summaries").doc(`${personId}_${key}`), {
      personId, periodKey: key, points: FieldValue.increment(delta), count: FieldValue.increment(1),
    }, { merge: true });
  }
}

const inviteMail = (p: { role: string }, famName: string, inviter: string, reminder = false) => {
  const where = p.role === "member" ? "«أحد أفراد الأسرة»" : "«مسؤول الأسرة»";
  const how = `للربط: افتح التطبيق، اختر ${where}، أدخل بريدك ثم هذا الكود.`;
  if (reminder) return { subject: `تذكير: دعوة للانضمام إلى ${famName}`, intro: `للربط: افتح تطبيق أسرتي، اختر ${where}، أدخل بريدك ثم هذا الكود.` };
  return p.role === "member"
    ? { subject: `دعوة للانضمام إلى ${famName}`, intro: `أضافك ${inviter} إلى ${famName} في تطبيق أسرتي.\n${how}` }
    : { subject: `تمت إضافتك مسؤولاً في ${famName}`, intro: `أضافك ${inviter} مسؤولاً في ${famName} على تطبيق أسرتي.\n${how}` };
};

async function removePersonData(fid: string, p: Person) {
  const f = fam(fid);
  const batch = db.batch();
  batch.delete(f.collection("people").doc(p.id));
  batch.delete(db.collection("emailIndex").doc(p.email));
  const tasks = await f.collection("tasks").where("personId", "==", p.id).get();
  tasks.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  const comps = await f.collection("completions").where("personId", "==", p.id).get();
  await Promise.all(comps.docs.map((d) => deleteProof(d.data().photoPath)));
  await auth.revokeRefreshTokens(p.id).catch(() => undefined);
  await auth.deleteUser(p.id).catch(() => undefined);
}

const ops: Record<string, Handler> = {
  // ---------- people
  async addPerson(c) {
    const role = c.data.role === "admin" ? "admin" : "member";
    need(c, role === "admin" ? "owner" : "addMembers");
    const name = str(c.data.name, 40);
    const email = normalizeEmail(c.data.email);
    if (!name || !EMAIL_RE.test(email)) fail("bad-name-email", {}, "invalid-argument");
    const ref = people(c.fid).doc();
    const idxRef = db.collection("emailIndex").doc(email);
    await db.runTransaction(async (tx) => {
      if ((await tx.get(idxRef)).exists) fail("email-taken");
      tx.set(ref, {
        name, email, role, perms: role === "admin" ? cleanPerms(c.data.perms) : {},
        avatar: avatar(c.data.avatar) ?? (role === "admin" ? "mom" : "boy"),
        status: "invited", authUid: null, fcmTokens: [], createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(idxRef, { familyId: c.fid, personId: ref.id, role });
    });
    await issueCode(email, inviteMail({ role }, c.famName, c.me.name));
    return { personId: ref.id };
  },

  async resendInvite(c) {
    const p = await person(c.fid, c.data.personId);
    need(c, p.role === "member" ? "addMembers" : "owner");
    if (p.status === "active") fail("already-active");
    await issueCode(p.email, inviteMail(p, c.famName, c.me.name, true));
    return {};
  },

  async updatePerms(c) {
    need(c, "owner");
    const p = await person(c.fid, c.data.personId);
    if (p.role !== "admin") fail("not-admin");
    await people(c.fid).doc(p.id).update({ perms: cleanPerms(c.data.perms) });
    return {};
  },

  async removePerson(c) {
    const p = await person(c.fid, c.data.personId);
    if (p.role === "owner") fail("cannot-remove-owner");
    need(c, p.role === "member" ? "addMembers" : "owner");
    await removePersonData(c.fid, p);
    return {};
  },

  async setAvatar(c) {
    const p = await person(c.fid, c.data.personId);
    const ok = p.id === c.me.id || c.me.role === "owner" || (p.role === "member" && can(c.me, "addMembers"));
    if (!ok) fail("no-permission", {}, "permission-denied");
    const a = avatar(c.data.avatar);
    if (!a) fail("bad-avatar", {}, "invalid-argument");
    await people(c.fid).doc(p.id).update({ avatar: a });
    return {};
  },

  async registerToken(c) {
    const token = str(c.data.token, 400);
    if (!token) return {};
    await people(c.fid).doc(c.me.id).update({ fcmTokens: FieldValue.arrayUnion(token) });
    return {};
  },

  async unregisterToken(c) {
    const token = str(c.data.token, 400);
    if (token) await people(c.fid).doc(c.me.id).update({ fcmTokens: FieldValue.arrayRemove(token) });
    return {};
  },

  // ---------- tasks
  async addTask(c) {
    need(c, "tasks");
    const title = str(c.data.title, 80);
    if (!title) fail("bad-title", {}, "invalid-argument");
    const points = int(c.data.points, 1, 1000);
    const repeat = period(c.data.repeat);
    const all = await getPeople(c.fid);
    const members = all.filter((p) => p.role === "member");
    const who = c.data.personId === "all" ? members : members.filter((m) => m.id === c.data.personId);
    if (!who.length) fail("person-not-found", {}, "not-found");
    const batch = db.batch();
    for (const m of who) {
      batch.set(fam(c.fid).collection("tasks").doc(), {
        title, personId: m.id, points, repeat, createdBy: c.me.id, createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return { count: who.length };
  },

  async updateTask(c) {
    need(c, "tasks");
    const ref = fam(c.fid).collection("tasks").doc(String(c.data.taskId ?? ""));
    const t = (await ref.get()).data();
    if (!t) fail("task-not-found", {}, "not-found");
    const target = await person(c.fid, c.data.personId ?? t.personId);
    if (target.role !== "member") fail("person-not-found", {}, "not-found");
    await ref.update({
      title: str(c.data.title, 80) || t.title,
      points: int(c.data.points ?? t.points, 1, 1000),
      repeat: period(c.data.repeat ?? t.repeat),
      personId: target.id,
    });
    return {};
  },

  async deleteTask(c) {
    need(c, "tasks");
    await fam(c.fid).collection("tasks").doc(String(c.data.taskId ?? "")).delete();
    return {};
  },

  async completeTask(c) {
    if (c.me.role !== "member") fail("members-only", {}, "permission-denied");
    const tRef = fam(c.fid).collection("tasks").doc(String(c.data.taskId ?? ""));
    const photoPath = c.data.photoPath ? str(c.data.photoPath, 300) : null;
    if (photoPath && !photoPath.startsWith(`proofs/${c.fid}/${c.me.id}/`)) fail("bad-photo", {}, "invalid-argument");
    const created = await db.runTransaction(async (tx) => {
      const t = (await tx.get(tRef)).data();
      if (!t || t.personId !== c.me.id) fail("task-not-found", {}, "not-found");
      const pk = periodKey(t.repeat, Date.now());
      // One completion per task per period; a rejected one may be retried.
      const cRef = fam(c.fid).collection("completions").doc(`${tRef.id}_${pk}`);
      const prev = (await tx.get(cRef)).data();
      if (prev && prev.status !== "rejected") fail("already-done");
      tx.set(cRef, {
        taskId: tRef.id, personId: c.me.id, title: t.title, points: t.points, periodKey: pk,
        status: "pending", photoPath, createdAt: FieldValue.serverTimestamp(), decidedBy: null,
      });
      return t.title as string;
    });
    const all = await getPeople(c.fid);
    await push(c.fid, all.filter((p) => can(p, "approve")), "مهمة بانتظار موافقتك", `${c.me.name}: ${created}`);
    return {};
  },

  async decideCompletion(c) {
    need(c, "approve");
    const approve = c.data.approve === true;
    const ref = fam(c.fid).collection("completions").doc(String(c.data.completionId ?? ""));
    const done = await db.runTransaction(async (tx) => {
      const d = (await tx.get(ref)).data();
      if (!d) fail("not-found", {}, "not-found");
      if (d.status !== "pending") fail("already-decided");
      tx.update(ref, { status: approve ? "approved" : "rejected", decidedBy: c.me.id, decidedAt: FieldValue.serverTimestamp(), photoPath: null });
      if (approve) addPoints(tx, c.fid, d.personId, d.points, `إنجاز: ${d.title}`, d.taskId);
      return d;
    });
    await deleteProof(done.photoPath);
    const kid = (await people(c.fid).doc(done.personId).get()).data() as Person | undefined;
    if (kid) {
      await push(c.fid, [kid], approve ? "تمت الموافقة 🎉" : "أُعيدت المهمة",
        approve ? `+${done.points} نقطة: ${done.title}` : `حاول مرة أخرى: ${done.title}`);
    }
    return {};
  },

  // ---------- competitions
  async addCompetition(c) {
    need(c, "comps");
    const title = str(c.data.title, 80);
    if (!title) fail("bad-title", {}, "invalid-argument");
    const start = int(c.data.startPoints ?? 20, 1, 1000);
    const minutes = c.data.minutes ? int(c.data.minutes, 0, 7 * 24 * 60) : 0;
    await fam(c.fid).collection("competitions").add({
      title, startPoints: start, deadline: minutes > 0 ? Timestamp.fromMillis(Date.now() + minutes * 60000) : null,
      ended: false, createdAt: FieldValue.serverTimestamp(), entries: {}, entryCount: 0, createdBy: c.me.id,
    });
    await notify(c.fid, "all", "🏁 مسابقة جديدة",
      `${title}\nأول من ينجز يحصل على ${start} نقطة، والتالي أقل بنقطة.${minutes > 0 ? `\nالوقت المتاح: ${minutes} دقيقة.` : ""}`, c.me.name);
    return {};
  },

  async endCompetition(c) {
    need(c, "comps");
    await fam(c.fid).collection("competitions").doc(String(c.data.compId ?? "")).update({ ended: true });
    return {};
  },

  async enterCompetition(c) {
    if (c.me.role !== "member") fail("members-only", {}, "permission-denied");
    const ref = fam(c.fid).collection("competitions").doc(String(c.data.compId ?? ""));
    // Rank is assigned inside a transaction so simultaneous taps get distinct ranks.
    const r = await db.runTransaction(async (tx) => {
      const comp = (await tx.get(ref)).data();
      if (!comp) fail("not-found", {}, "not-found");
      if (comp.ended || (comp.deadline && comp.deadline.toMillis() <= Date.now())) fail("comp-over");
      if (comp.entries?.[c.me.id]) fail("already-entered");
      const rank = (comp.entryCount ?? 0) + 1;
      const points = competitionPoints(comp.startPoints, rank);
      tx.update(ref, {
        [`entries.${c.me.id}`]: { personId: c.me.id, rank, points, status: "pending", createdAt: Timestamp.now() },
        entryCount: rank,
      });
      return { rank, points, title: comp.title as string };
    });
    const all = await getPeople(c.fid);
    await push(c.fid, all.filter((p) => can(p, "approve")), "إنجاز في مسابقة", `${c.me.name}: ${r.title} (المركز ${r.rank})`);
    return { rank: r.rank, points: r.points };
  },

  async decideEntry(c) {
    need(c, "approve");
    const approve = c.data.approve === true;
    const pid = String(c.data.personId ?? "");
    const ref = fam(c.fid).collection("competitions").doc(String(c.data.compId ?? ""));
    const e = await db.runTransaction(async (tx) => {
      const comp = (await tx.get(ref)).data();
      const entry = comp?.entries?.[pid];
      if (!comp || !entry) fail("not-found", {}, "not-found");
      if (entry.status !== "pending") fail("already-decided");
      tx.update(ref, { [`entries.${pid}.status`]: approve ? "approved" : "rejected" });
      if (approve) addPoints(tx, c.fid, pid, entry.points, `مسابقة: ${comp.title} (المركز ${entry.rank})`, ref.id);
      return { ...entry, title: comp.title };
    });
    const kid = (await people(c.fid).doc(pid).get()).data() as Person | undefined;
    if (kid) await push(c.fid, [kid], approve ? "🏆 تمت الموافقة" : "لم تُقبل مشاركتك", approve ? `+${e.points} نقطة: ${e.title}` : e.title);
    return {};
  },

  // ---------- rewards
  async addTier(c) {
    need(c, "owner");
    const name = str(c.data.name, 40);
    const threshold = int(c.data.threshold, 1, 100000);
    if (!name) fail("bad-title", {}, "invalid-argument");
    const emoji = REWARD_EMOJI.includes(String(c.data.emoji)) ? String(c.data.emoji) : "🎁";
    await fam(c.fid).collection("tiers").add({ name, emoji, threshold, period: period(c.data.period), scope: scope(c.data.scope) });
    return {};
  },

  async deleteTier(c) {
    need(c, "owner");
    await fam(c.fid).collection("tiers").doc(String(c.data.tierId ?? "")).delete();
    return {};
  },

  async deliver(c) {
    need(c, "owner");
    const tierId = String(c.data.tierId ?? ""), who = String(c.data.who ?? ""), pk = String(c.data.periodKey ?? "");
    if (!/^[\w-]+$/.test(tierId) || !/^[\w-]+$/.test(who) || !/^w?\d{4}-\d{2}-\d{2}$/.test(pk)) fail("bad-key", {}, "invalid-argument");
    await fam(c.fid).collection("deliveries").doc(`${tierId}_${who}_${pk}`).set({
      tierId, who, periodKey: pk, deliveredBy: c.me.id, at: FieldValue.serverTimestamp(),
    });
    return {};
  },

  // ---------- notifications & reports
  async sendAlert(c) {
    need(c, "owner");
    const body = str(c.data.body, 500);
    if (!body) fail("bad-body", {}, "invalid-argument");
    const to = c.data.to === "all" ? "all" : (await person(c.fid, c.data.to)).id;
    await notify(c.fid, to, `🔔 تنبيه من ${c.me.name}`, body, c.me.name);
    return {};
  },

  async sendReport(c) {
    need(c, "report");
    const all = await getPeople(c.fid);
    const members = all.filter((p) => p.role === "member");
    const key = dayKey(Date.now());
    const sums = await fam(c.fid).collection("summaries").where("periodKey", "==", key).get();
    const byId = new Map(sums.docs.map((d) => [d.data().personId as string, d.data()]));
    const text = reportText(
      members.map((m) => ({ name: m.name, points: byId.get(m.id)?.points ?? 0, count: byId.get(m.id)?.count ?? 0 })),
      Date.now(),
    );
    await notify(c.fid, "all", "🏆 ترتيب إنجاز اليوم", text, c.me.name);
    return {};
  },

  async markRead(c) {
    const snap = await fam(c.fid).collection("notifications").orderBy("createdAt", "desc").limit(100).get();
    const batch = db.batch();
    let n = 0;
    for (const d of snap.docs) {
      const x = d.data();
      if ((x.to === "all" || x.to === c.me.id) && !(x.readBy ?? []).includes(c.me.id)) {
        batch.update(d.ref, { readBy: FieldValue.arrayUnion(c.me.id) });
        n++;
      }
    }
    if (n) await batch.commit();
    return { n };
  },

  // ---------- account & family deletion (App Store requirement)
  async deleteAccount(c) {
    if (c.me.role === "owner") fail("owner-must-delete-family");
    await removePersonData(c.fid, c.me);
    return {};
  },

  async deleteFamily(c) {
    need(c, "owner");
    const all = await getPeople(c.fid);
    await storage.bucket().deleteFiles({ prefix: `proofs/${c.fid}/` }).catch(() => undefined);
    await Promise.all(all.map((p) => db.collection("emailIndex").doc(p.email).delete()));
    await deleteTree(fam(c.fid));
    await Promise.all(all.map(async (p) => {
      await auth.revokeRefreshTokens(p.id).catch(() => undefined);
      await auth.deleteUser(p.id).catch(() => undefined);
    }));
    return {};
  },
};

export const api = onCall({ secrets: [RESEND_API_KEY] }, async (req: CallableRequest) => {
  const fid = req.auth?.token?.familyId as string | undefined;
  const uid = req.auth?.uid;
  if (!fid || !uid) fail("unauthenticated", {}, "unauthenticated");
  const op = String(req.data?.op ?? "");
  const handler = Object.prototype.hasOwnProperty.call(ops, op) ? ops[op] : undefined;
  if (!handler) fail("unknown-op", { op }, "invalid-argument");
  const [meSnap, famSnap] = await Promise.all([people(fid).doc(uid).get(), fam(fid).get()]);
  // A removed person keeps a valid token until it expires; the people doc is the source of truth.
  if (!meSnap.exists || !famSnap.exists) fail("removed", {}, "permission-denied");
  const me = { id: meSnap.id, ...(meSnap.data() as Omit<Person, "id">) };
  return handler({ fid, me, famName: famSnap.data()!.name, data: (req.data ?? {}) as Record<string, unknown> });
});
