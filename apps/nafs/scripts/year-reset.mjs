// بداية عام دراسي جديد: حذف كل الأشخاص (مديرو المدارس والمعلمون والطلاب ومقدمو خدمات الدعم) مع بقاء المدرسة معرّفة
// بالرقم الإحصائي ومرتبطة بفصولها واختباراتها ونتائجها.
//
// يشغّله مالك الموقع فقط (مفتاح حساب الخدمة، لا يعمل من المتصفح):
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/year-reset.mjs            ← معاينة بلا تغيير (الافتراضي)
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/year-reset.mjs --confirm  ← تنفيذ فعلي
//
// الترتيب مقصود: أولاً نختم كل اختبار ومفتاح ومحاولة برقم مدرسته وعامها (وباسم الطالب في المحاولة) كي لا تضيع صلتها بالمدرسة
// عند حذف أصحابها، ثم تُفرَّغ المدرسة من مديرها وتُفتح لها سنة جديدة، ثم يُحذف الأشخاص وحساباتهم.
// ما لا يُحذف: schools (الرقم الإحصائي والاسم والفصول والأعوام)، tests، testKeys، attempts، bank (أسئلة المعلمين).
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';
import { nextYearLabel, yearOf } from '../src/years.js';

const PEOPLE = ['students', 'teachers', 'principals', 'providers', 'providerLinks', 'providerRequests', 'schoolTransfers', 'teacherRoster'];
const ms = (t) => (t?.toMillis ? t.toMillis() : typeof t === 'number' ? t : 0);

async function all(db, name) {
    const snap = await db.collection(name).get();
    return snap.docs;
}

async function writeInBatches(db, ops) {
    for (let i = 0; i < ops.length; i += 400) {
        const batch = db.batch();
        for (const [ref, data] of ops.slice(i, i + 400)) batch.set(ref, data, { merge: true });
        await batch.commit();
    }
}

export async function yearReset({ db, auth, confirm = false, openNewYear = true, now = Date.now(), log = console.log }) {
    const report = { dryRun: !confirm, orphans: { tests: [], attempts: [] }, counts: {} };

    const schools = Object.fromEntries((await all(db, 'schools')).map((d) => [d.id, d.data()]));
    const teachers = Object.fromEntries((await all(db, 'teachers')).map((d) => [d.id, d.data()]));
    const students = Object.fromEntries((await all(db, 'students')).map((d) => [d.id, d.data()]));

    // 1) ختم الاختبارات والمفاتيح والمحاولات برقم المدرسة والعام
    const testInfo = {}, ops = [];
    for (const d of await all(db, 'tests')) {
        const t = d.data();
        const schoolNo = t.schoolNo ?? teachers[t.teacherUid]?.schoolNo;
        const school = schools[schoolNo];
        if (!school) { report.orphans.tests.push(d.id); continue; }
        const year = t.year ?? yearOf(school.years ?? [{ label: school.year, start: 0 }], ms(t.createdAt));
        testInfo[d.id] = { schoolNo, year };
        ops.push([d.ref, { schoolNo, year, archived: true }]);
    }
    for (const d of await all(db, 'testKeys')) if (testInfo[d.id]) ops.push([d.ref, { schoolNo: testInfo[d.id].schoolNo }]);
    for (const d of await all(db, 'attempts')) {
        const a = d.data(), info = testInfo[a.testId];
        if (!info) { report.orphans.attempts.push(d.id); continue; }
        ops.push([d.ref, { schoolNo: info.schoolNo, year: info.year, studentName: students[a.studentId]?.name ?? a.studentName ?? null }]);
    }
    report.counts.stamped = ops.length;

    // 2) إفراغ المدارس من مديريها وفتح عام جديد
    const schoolOps = Object.entries(schools).map(([no, s]) => {
        const years = s.years?.length ? s.years : [{ label: s.year, start: 0 }];
        const next = openNewYear ? nextYearLabel(s.year) : s.year;
        return [db.collection('schools').doc(no), { principalUid: null, principalName: null, year: next, years: openNewYear ? [...years, { label: next, start: now }] : years }];
    });
    report.counts.schools = schoolOps.length;

    // 3) الأشخاص
    report.counts.people = {};
    for (const name of PEOPLE) report.counts.people[name] = (await all(db, name)).length;
    const users = [];
    let page;
    do { page = await auth.listUsers(1000, page?.pageToken); users.push(...page.users.map((u) => u.uid)); } while (page.pageToken);
    report.counts.authUsers = users.length;

    log(`${confirm ? 'تنفيذ' : 'معاينة'}: سيُختم ${ops.length} مستنداً، وتُفرَّغ ${schoolOps.length} مدرسة ويُفتح لها عام جديد.`);
    log('سيُحذف:', JSON.stringify(report.counts.people), `، وحسابات الدخول: ${users.length}`);
    if (report.orphans.tests.length || report.orphans.attempts.length) log(`تنبيه: ${report.orphans.tests.length} اختباراً و${report.orphans.attempts.length} محاولة بلا مدرسة معروفة، تُترك كما هي.`);
    if (!confirm) return report;

    await writeInBatches(db, ops);
    await writeInBatches(db, schoolOps);
    for (const name of PEOPLE) for (const d of await all(db, name)) await db.recursiveDelete(d.ref);
    for (let i = 0; i < users.length; i += 1000) await auth.deleteUsers(users.slice(i, i + 1000));
    log('تم. تبقى المدارس والفصول والاختبارات والنتائج مرتبطة بأرقام المدارس الإحصائية.');
    return report;
}

if (import.meta.url === `file://${process.argv[1]}`) {
    const confirm = process.argv.includes('--confirm');
    const projectId = process.env.PROJECT_ID || JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')).project_id;
    initializeApp({ credential: applicationDefault(), projectId });
    await yearReset({ db: getFirestore(), auth: getAuth(), confirm, openNewYear: !process.argv.includes('--keep-year') });
    if (!confirm) console.log('هذه معاينة فقط. أضف --confirm للتنفيذ الفعلي.');
}
