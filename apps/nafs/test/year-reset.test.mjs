// سكربت بداية العام الدراسي على محاكيات Firebase: يحذف الأشخاص ويُبقي المدرسة والفصول والاختبارات والنتائج مرتبطة بالرقم الإحصائي.
import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { yearReset } from '../scripts/year-reset.mjs';

const app = initializeApp({ projectId: 'demo-nafs' }, 'reset');
const db = getFirestore(app), auth = getAuth(app);
const quiet = () => {};

test('بداية العام: حذف الأشخاص وبقاء المدرسة ونتائجها', async () => {
    const t0 = Timestamp.fromMillis(Date.UTC(2026, 8, 1));
    const tUser = await auth.createUser({ email: 'rt@example.com', password: 'abcdef1' });
    const pUser = await auth.createUser({ email: 'rp@example.com', password: 'abcdef1' });
    await db.doc('schools/777001').set({ no: '777001', name: 'مدرسة الاختبار', principalUid: pUser.uid, principalName: 'مدير', classes: ['الثالث الابتدائي - أ'], year: '1448هـ · 2026-2027', years: [{ label: '1448هـ · 2026-2027', start: 0 }] });
    await db.doc(`principals/${pUser.uid}`).set({ name: 'مدير', schoolNo: '777001' });
    await db.doc(`teachers/${tUser.uid}`).set({ name: 'معلم', schoolNo: '777001' });
    await db.doc('teacherRoster/1000000001').set({ schoolNo: '777001', uid: tUser.uid });
    await db.doc('students/2000000001').set({ name: 'فهد', teacherUid: tUser.uid });
    await db.doc('providers/p1').set({ name: 'مقدم' });
    await db.doc('providerLinks/777001').set({ providerUid: 'p1' });
    await db.doc('tests/t1').set({ teacherUid: tUser.uid, title: 'اختبار', createdAt: t0 });
    await db.doc('testKeys/t1').set({ keys: [0, 1] });
    await db.doc('attempts/a1').set({ testId: 't1', studentId: '2000000001', teacherUid: tUser.uid, score: 5 });
    await db.doc('tests/orphan').set({ teacherUid: 'ghost', title: 'يتيم', createdAt: t0 });

    // معاينة: لا تغيّر شيئاً
    const dry = await yearReset({ db, auth, confirm: false, log: quiet });
    assert.equal(dry.dryRun, true);
    assert.ok((await db.doc('students/2000000001').get()).exists);
    assert.ok((await db.doc(`principals/${pUser.uid}`).get()).exists);
    assert.deepEqual(dry.orphans.tests, ['orphan']);

    // تنفيذ
    await yearReset({ db, auth, confirm: true, now: Date.UTC(2027, 7, 20), log: quiet });
    for (const p of [`principals/${pUser.uid}`, `teachers/${tUser.uid}`, 'teacherRoster/1000000001', 'students/2000000001', 'providers/p1', 'providerLinks/777001']) {
        assert.equal((await db.doc(p).get()).exists, false, `${p} يجب أن يُحذف`);
    }
    await assert.rejects(auth.getUser(tUser.uid));
    await assert.rejects(auth.getUser(pUser.uid));

    const school = (await db.doc('schools/777001').get()).data();
    assert.equal(school.principalUid, null);
    assert.equal(school.year, '1449هـ · 2027-2028');
    assert.equal(school.years.length, 2);
    assert.deepEqual(school.classes, ['الثالث الابتدائي - أ']);

    const t = (await db.doc('tests/t1').get()).data();
    assert.equal(t.schoolNo, '777001');
    assert.equal(t.year, '1448هـ · 2026-2027');
    const a = (await db.doc('attempts/a1').get()).data();
    assert.equal(a.schoolNo, '777001');
    assert.equal(a.studentName, 'فهد');
    assert.equal(a.score, 5);
    assert.ok((await db.doc('testKeys/t1').get()).exists);
    assert.ok((await db.doc('tests/orphan').get()).exists, 'اختبار بلا مدرسة معروفة يُترك');
});
