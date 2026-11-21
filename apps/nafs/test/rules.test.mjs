// قواعد Firestore على المحاكي (يشغله: npm test).
import test, { before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where, addDoc, serverTimestamp } from 'firebase/firestore';

let env;
const T1 = 'teacher1', T2 = 'teacher2';
const teacherDb = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'password' } }).firestore();
const studentDb = () => env.authenticatedContext('anon1', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const profile = { name: 'معلم', civilId: '1000000001', school: 'مدرسة', schoolNo: '123456', className: 'الثالث الابتدائي - أ', email: 't@x.com' };
const P1 = 'principal1', P2 = 'principal2';
const CLASSES_ASSIGNED = ['الثالث الابتدائي - أ', 'الثالث الابتدائي - ب'];
const student = (uid) => ({ name: 'طالب', teacherUid: uid, className: 'الثالث الابتدائي - أ', school: 'مدرسة', status: 'لم يبدأ', createdAt: serverTimestamp() });

before(async () => {
    const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
    env = await initializeTestEnvironment({ projectId: 'demo-nafs', firestore: { host, port: Number(port), rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') } });
});
after(() => env.cleanup());
beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
        const f = ctx.firestore();
        await setDoc(doc(f, 'students/1111111111'), { ...student(T1), createdAt: new Date() });
        // مدرسة 123456 لمدير P1، وكشف فيه المعلم 1000000001 مفعّلاً لـ T1، وآخر 1000000002 لم يُفعَّل
        await setDoc(doc(f, 'principals', P1), { name: 'مدير', civilId: '1000000100', email: 'p@x.com', schoolNo: '123456', createdAt: new Date() });
        await setDoc(doc(f, 'schools/123456'), { no: '123456', name: 'مدرسة', principalUid: P1, principalName: 'مدير', classes: CLASSES_ASSIGNED, year: '1447-1448', createdAt: new Date() });
        await setDoc(doc(f, 'teacherRoster/1000000001'), { schoolNo: '123456', name: 'معلم', classes: CLASSES_ASSIGNED, uid: T1, email: 't@x.com', createdAt: new Date(), activatedAt: new Date() });
        await setDoc(doc(f, 'teacherRoster/1000000002'), { schoolNo: '123456', name: 'معلم ٢', classes: CLASSES_ASSIGNED, uid: null, createdAt: new Date() });
    });
});

test('المعلم يكتب ملفه فقط', async () => {
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'teachers', T1), profile));
    await assertFails(setDoc(doc(teacherDb(T1), 'teachers', T2), profile));
    await assertFails(setDoc(doc(teacherDb(T1), 'teachers', T1), { ...profile, civilId: '123' }));
    await assertFails(setDoc(doc(teacherDb(T1), 'teachers', T1), { ...profile, admin: true }));
    await assertFails(setDoc(doc(studentDb(), 'teachers', 'anon1'), profile));
    await assertFails(getDoc(doc(teacherDb(T2), 'teachers', T1)));
});

test('الملفات المرفوعة خاصة بصاحبها', async () => {
    const up = { name: 'a.xlsx', size: 10, type: 'x', data: 'AAAA', className: 'c', added: 1, createdAt: serverTimestamp() };
    await assertSucceeds(addDoc(collection(teacherDb(T1), 'teachers', T1, 'uploads'), up));
    await assertFails(addDoc(collection(teacherDb(T2), 'teachers', T1, 'uploads'), up));
    await assertFails(getDocs(collection(teacherDb(T2), 'teachers', T1, 'uploads')));
    await assertFails(addDoc(collection(teacherDb(T1), 'teachers', T1, 'uploads'), { ...up, data: 'A'.repeat(950001) }));
    await assertSucceeds(getDocs(collection(teacherDb(T1), 'teachers', T1, 'uploads')));
});

test('إضافة طالب: لنفسه فقط، ولا يكتب فوق طالب معلم آخر', async () => {
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'students/2222222222'), student(T1)));
    await assertFails(setDoc(doc(teacherDb(T1), 'students/3333333333'), student(T2)));
    await assertFails(setDoc(doc(teacherDb(T1), 'students/12345'), student(T1)));
    await assertFails(setDoc(doc(teacherDb(T2), 'students/1111111111'), student(T2)));
    await assertFails(setDoc(doc(teacherDb(T1), 'students/4444444444'), { ...student(T1), score: 100 }));
    await assertFails(setDoc(doc(studentDb(), 'students/5555555555'), student('anon1')));
});

test('القائمة: المعلم يرى طلابه فقط', async () => {
    await assertSucceeds(getDocs(query(collection(teacherDb(T1), 'students'), where('teacherUid', '==', T1))));
    await assertFails(getDocs(query(collection(teacherDb(T2), 'students'), where('teacherUid', '==', T1))));
    await assertFails(getDocs(collection(teacherDb(T1), 'students')));
    await assertFails(getDocs(collection(studentDb(), 'students')));
});

test('الطالب: يقرأ سجله برقمه ولا يعدّله', async () => {
    const db = studentDb();
    await assertSucceeds(getDoc(doc(db, 'students/1111111111')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'students/1111111111')));
    await assertFails(updateDoc(doc(db, 'students/1111111111'), { score: 100, status: 'منجز', completedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db, 'students/1111111111')));
});

const CLASS = 'الثالث الابتدائي - أ';
const testData = (uid, status = 'published') => ({
    teacherUid: uid, title: 'اختبار', className: CLASS, grade: 3, passage: 'نص',
    questions: [{ skill: '3-1.1', level: 'know', text: 'س', options: ['أ', 'ب'] }, { skill: '3-2.1', level: 'know', text: 'س2', options: ['أ', 'ب'] }],
    skills: ['3-1.1', '3-2.1'], status, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});
const attempt = (testId = 'T1', studentId = '1111111111', extra = {}) => ({
    testId, studentId, teacherUid: T1, className: CLASS, answers: [0, 1], submittedAt: serverTimestamp(), ...extra,
});
async function seedTests() {
    await env.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'tests/T1'), { ...testData(T1), createdAt: new Date(), updatedAt: new Date() });
        await setDoc(doc(db, 'tests/DRAFT'), { ...testData(T1, 'draft'), createdAt: new Date(), updatedAt: new Date() });
        await setDoc(doc(db, 'testKeys/T1'), { teacherUid: T1, answers: [0, 1] });
    });
}

test('الاختبارات: المعلم يبني لنفسه فقط، والطالب يرى المنشور فقط', async () => {
    await seedTests();
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'tests/NEW'), testData(T1)));
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/NEW2'), testData(T2)));
    await assertFails(setDoc(doc(teacherDb(T2), 'tests/T1'), testData(T2)));
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/BAD'), { ...testData(T1), grade: 4 }));
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/BAD'), { ...testData(T1), questions: [] }));
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/BAD'), { ...testData(T1), answers: [0] }));
    await assertFails(setDoc(doc(studentDb(), 'tests/BAD'), testData('anon1')));
    await assertSucceeds(updateDoc(doc(teacherDb(T1), 'tests/T1'), { status: 'draft', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(teacherDb(T1), 'tests/T1'), { status: 'published', updatedAt: serverTimestamp() }));

    await assertSucceeds(getDoc(doc(studentDb(), 'tests/T1')));
    await assertFails(getDoc(doc(studentDb(), 'tests/DRAFT')));
    await assertSucceeds(getDocs(query(collection(studentDb(), 'tests'), where('teacherUid', '==', T1), where('className', '==', CLASS), where('status', '==', 'published'))));
    await assertFails(getDocs(query(collection(studentDb(), 'tests'), where('teacherUid', '==', T1))));
    await assertSucceeds(getDocs(query(collection(teacherDb(T1), 'tests'), where('teacherUid', '==', T1))));
    await assertFails(getDocs(query(collection(teacherDb(T2), 'tests'), where('teacherUid', '==', T1))));
    await assertFails(deleteDoc(doc(teacherDb(T2), 'tests/T1')));
});

test('الاختبارات: المادة والمصدر وأسئلة الصور (النماذج الرسمية)', async () => {
    const official = {
        ...testData(T1, 'draft'), subject: 'math', source: 'a3-math',
        questions: [{ skill: 'm3-1-1-2.1', level: 'apply', text: '', options: ['أ', 'ب', 'ج', 'د'], image: 'forms/a3/q01.webp', iw: 600, ih: 300 }],
    };
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'tests/OFF1'), official));
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'tests/OFF2'), { ...official, subject: 'science', source: 'a6-science' }));
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'tests/OLD'), testData(T1))); // بلا مادة = قراءة (اختبارات قديمة)
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/BAD1'), { ...official, subject: 'history' }));
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/BAD2'), { ...official, source: 'x'.repeat(21) }));
    await assertFails(setDoc(doc(teacherDb(T1), 'tests/BAD3'), { ...official, source: 5 }));
    await assertFails(setDoc(doc(teacherDb(T2), 'tests/OFF1'), official));
});

test('مفاتيح الإجابات: للمعلم صاحبها فقط', async () => {
    await seedTests();
    await assertSucceeds(getDoc(doc(teacherDb(T1), 'testKeys/T1')));
    await assertFails(getDoc(doc(studentDb(), 'testKeys/T1')));
    await assertFails(getDoc(doc(teacherDb(T2), 'testKeys/T1')));
    await assertFails(setDoc(doc(teacherDb(T2), 'testKeys/T1'), { teacherUid: T2, answers: [1, 1] }));
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'testKeys/NEW'), { teacherUid: T1, answers: [1] }));
});

test('المحاولات: مرة واحدة، لاختبار منشور، لطالب من نفس الفصل والمعلم', async () => {
    await seedTests();
    const db = studentDb();
    await assertFails(setDoc(doc(db, 'attempts/T1_1111111111'), attempt('T1', '1111111111', { answers: [0] })));
    await assertFails(setDoc(doc(db, 'attempts/T1_2222222222'), attempt('T1', '1111111111')));
    await assertFails(setDoc(doc(db, 'attempts/DRAFT_1111111111'), attempt('DRAFT')));
    await assertFails(setDoc(doc(db, 'attempts/T1_9999999999'), attempt('T1', '9999999999')));
    await assertFails(setDoc(doc(db, 'attempts/T1_1111111111'), attempt('T1', '1111111111', { className: 'السادس الابتدائي - أ' })));
    await assertFails(setDoc(doc(teacherDb(T1), 'attempts/T1_1111111111'), attempt()));
    await assertSucceeds(setDoc(doc(db, 'attempts/T1_1111111111'), attempt()));
    await assertFails(setDoc(doc(db, 'attempts/T1_1111111111'), attempt('T1', '1111111111', { answers: [1, 1] })));
    await assertSucceeds(getDoc(doc(db, 'attempts/T1_1111111111')));
    await assertFails(getDocs(collection(db, 'attempts')));
    await assertSucceeds(getDocs(query(collection(teacherDb(T1), 'attempts'), where('teacherUid', '==', T1))));
    await assertFails(getDocs(query(collection(teacherDb(T2), 'attempts'), where('teacherUid', '==', T1))));
    await assertFails(deleteDoc(doc(teacherDb(T2), 'attempts/T1_1111111111')));
    await assertSucceeds(deleteDoc(doc(teacherDb(T1), 'attempts/T1_1111111111')));
});

test('حذف طالب: صاحبه فقط', async () => {
    await assertFails(deleteDoc(doc(teacherDb(T2), 'students/1111111111')));
    await assertFails(updateDoc(doc(teacherDb(T2), 'students/1111111111'), { name: 'x' }));
    await assertFails(updateDoc(doc(teacherDb(T1), 'students/1111111111'), { teacherUid: T2 }));
    await assertSucceeds(deleteDoc(doc(teacherDb(T1), 'students/1111111111')));
});

test('بنك الأسئلة: لصاحبه فقط، بحالات وإصدارات صحيحة، وأربعة خيارات', async () => {
    const q = { teacherUid: T1, skill: '3-1.1', level: 'know', text: 'ما مرادف كلمة «سعيد»؟', options: ['حزين', 'فرِح', 'غاضب', 'متعب'], answer: 1, explanation: 'سعيد = فرِح', source: 'ai', status: 'generated', version: 1 };
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'bank/B1'), q));
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'bank/B1'), { ...q, status: 'approved' }));
    await assertFails(setDoc(doc(teacherDb(T1), 'bank/B1'), { ...q, version: 0 }));
    await assertFails(setDoc(doc(teacherDb(T2), 'bank/B1'), q));
    await assertFails(setDoc(doc(teacherDb(T1), 'bank/B2'), { ...q, options: ['أ', 'ب'] }));
    await assertFails(setDoc(doc(teacherDb(T1), 'bank/B3'), { ...q, level: 'x' }));
    await assertFails(setDoc(doc(teacherDb(T1), 'bank/B4'), { ...q, status: 'live' }));
    await assertFails(setDoc(doc(teacherDb(T1), 'bank/B5'), { ...q, extra: 1 }));
    await assertSucceeds(setDoc(doc(teacherDb(T1), 'bank/NA1'), { teacherUid: T1, skill: '3-1.1', level: 'reason', status: 'na', reason: 'لا يناسب المؤشر', source: 'ai', version: 1 }));
    await assertFails(getDoc(doc(studentDb(), 'bank/B1')));
    await assertFails(getDoc(doc(teacherDb(T2), 'bank/B1')));
    await assertSucceeds(getDocs(query(collection(teacherDb(T1), 'bank'), where('teacherUid', '==', T1))));
    await assertFails(deleteDoc(doc(teacherDb(T2), 'bank/B1')));
    await assertSucceeds(deleteDoc(doc(teacherDb(T1), 'bank/B1')));
});

test('المحاولات الورقية: المعلم صاحب الاختبار يرفعها ويستبدلها، ولا يستبدل محاولة إلكترونية', async () => {
    await seedTests(); // T1 منشور، DRAFT مسودة، الطالب 1111111111 للمعلم T1
    const paper = (extra = {}) => attempt('T1', '1111111111', { source: 'paper', ...extra });
    const t1 = teacherDb(T1);
    await assertSucceeds(setDoc(doc(t1, 'attempts/T1_1111111111'), paper()));            // رفع أول
    await assertSucceeds(setDoc(doc(t1, 'attempts/T1_1111111111'), paper({ answers: [1, 1] }))); // استبدال ورقية
    await assertSucceeds(setDoc(doc(t1, 'attempts/DRAFT_1111111111'), paper({ testId: 'DRAFT' }))); // ولو مسودة
    await assertFails(setDoc(doc(t1, 'attempts/T1_1111111111'), attempt())); // بلا source
    await assertFails(setDoc(doc(t1, 'attempts/T1_1111111111'), paper({ source: 'x' })));
    await assertFails(setDoc(doc(t1, 'attempts/T1_1111111111'), paper({ answers: [0] })));    // عدد الإجابات
    await assertFails(setDoc(doc(t1, 'attempts/T1_2222222222'), paper({ studentId: '2222222222' }))); // طالب غير موجود
    await assertFails(setDoc(doc(t1, 'attempts/T1_1111111111'), paper({ extra: 1 })));
    await assertFails(setDoc(doc(teacherDb(T2), 'attempts/T1_1111111111'), paper({ teacherUid: T2 }))); // اختبار ليس له
    await assertFails(setDoc(doc(studentDb(), 'attempts/T1_1111111111'), paper())); // الطالب لا يرفع ورقية
    // محاولة إلكترونية قائمة لا تُستبدل بورقية
    await assertSucceeds(deleteDoc(doc(t1, 'attempts/T1_1111111111')));
    await assertSucceeds(setDoc(doc(studentDb(), 'attempts/T1_1111111111'), attempt()));
    await assertFails(setDoc(doc(t1, 'attempts/T1_1111111111'), paper()));
});

const teacherDbNew = (uid) => teacherDb(uid);
test('المدير: يسجّل نفسه ويُنشئ مدرسته برقم إحصائي أرقام فقط، ولا يتصرف في مدرسة غيره', async () => {
    const p2 = teacherDbNew(P2);
    const pr = { name: 'مدير ٢', civilId: '1000000200', email: 'p2@x.com', schoolNo: '654321', createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(p2, 'principals', P2), { ...pr, schoolNo: '65a321' }));      // حروف
    await assertFails(setDoc(doc(p2, 'principals', P2), { ...pr, civilId: '123' }));
    await assertFails(setDoc(doc(p2, 'principals', P1), pr));                                   // ليس مستنده
    await assertSucceeds(setDoc(doc(p2, 'principals', P2), pr));
    const school = { no: '654321', name: 'مدرسة ٢', principalUid: P2, principalName: 'مدير ٢', classes: [], year: '1447-1448', createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(p2, 'schools/65a321'), { ...school, no: '65a321' }));
    await assertFails(setDoc(doc(p2, 'schools/654321'), { ...school, principalUid: P1 }));       // يسند لغيره
    await assertFails(setDoc(doc(p2, 'schools/123456'), { ...school, no: '123456' }));          // رقم مأخوذ (تعديل غير مالك)
    await assertSucceeds(setDoc(doc(p2, 'schools/654321'), school));
    await assertSucceeds(getDoc(doc(p2, 'schools/123456')));                                    // يرى تبعيتها لمدير آخر
    await assertFails(getDocs(collection(p2, 'schools')));                                      // لا قائمة
    await assertFails(updateDoc(doc(p2, 'schools/123456'), { name: 'اختراق' }));
    await assertFails(updateDoc(doc(p2, 'schools/123456'), { principalUid: P2 }));             // لا ينقل ملكية بنفسه
    await assertSucceeds(updateDoc(doc(teacherDbNew(P1), 'schools/123456'), { name: 'مدرسة جديدة', classes: ['الثالث الابتدائي - أ'] }));
    await assertFails(updateDoc(doc(teacherDbNew(P1), 'schools/123456'), { principalUid: P2 }));
    await assertFails(setDoc(doc(studentDb(), 'principals', 'anon1'), pr));
});

test('كشف المعلمين: المدير يضيف ويعدّل ويعيد ضبط التفعيل، والمعلم يفعّل نفسه مرة واحدة فقط', async () => {
    const p1 = teacherDbNew(P1), p2 = teacherDbNew(P2);
    const row = { schoolNo: '123456', name: 'معلم ٣', classes: ['الثالث الابتدائي - أ'], uid: null, createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(p1, 'teacherRoster/1000000003'), row));
    await assertFails(setDoc(doc(p2, 'teacherRoster/1000000004'), row));                         // ليس مدير المدرسة
    await assertFails(setDoc(doc(p1, 'teacherRoster/12345'), row));                              // سجل مدني غير صالح
    await assertFails(setDoc(doc(p1, 'teacherRoster/1000000005'), { ...row, uid: 'x' }));        // لا يفعّل بنفسه
    await assertFails(setDoc(doc(p1, 'teacherRoster/1000000005'), { ...row, classes: [] }));
    await assertFails(setDoc(doc(p1, 'teacherRoster/1000000005'), { ...row, schoolNo: '1' }));
    await assertSucceeds(getDocs(query(collection(p1, 'teacherRoster'), where('schoolNo', '==', '123456'))));
    await assertFails(getDocs(query(collection(p2, 'teacherRoster'), where('schoolNo', '==', '123456'))));
    await assertSucceeds(updateDoc(doc(p1, 'teacherRoster/1000000003'), { classes: ['الثالث الابتدائي - ب'] }));
    // تفعيل المعلم لنفسه: كشف جاهز لم يُفعَّل
    const t3 = teacherDbNew('newteacher');
    await assertSucceeds(getDoc(doc(t3, 'teacherRoster/1000000002')));
    await assertFails(updateDoc(doc(t3, 'teacherRoster/1000000002'), { uid: 'someoneelse', email: 'a@b.c', activatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(t3, 'teacherRoster/1000000002'), { uid: 'newteacher', email: 'a@b.c', activatedAt: serverTimestamp(), classes: ['السادس الابتدائي - أ'] }));
    await assertSucceeds(updateDoc(doc(t3, 'teacherRoster/1000000002'), { uid: 'newteacher', email: 'a@b.c', activatedAt: serverTimestamp() }));
    // لا ينتحل معلم آخر كشفاً مفعّلاً، ولا يفعّل مرتين
    await assertFails(updateDoc(doc(teacherDbNew('thief'), 'teacherRoster/1000000002'), { uid: 'thief', email: 'x@y.z', activatedAt: serverTimestamp() }));
    await assertFails(getDoc(doc(teacherDbNew('thief'), 'teacherRoster/1000000002')));
    // المدير يعيد ضبط التفعيل (مثلاً بعد انتحال) ويحذف
    await assertSucceeds(updateDoc(doc(p1, 'teacherRoster/1000000002'), { uid: null, email: null, activatedAt: null }));
    await assertSucceeds(deleteDoc(doc(p1, 'teacherRoster/1000000003')));
    await assertFails(deleteDoc(doc(p2, 'teacherRoster/1000000002')));
});

test('إنشاء ملف المعلم يتطلب تفعيل الكشف معه، والفصل من فصوله المسندة', async () => {
    const t = teacherDbNew('newteacher');
    const prof = { name: 'معلم ٢', civilId: '1000000002', school: 'مدرسة', schoolNo: '123456', className: 'الثالث الابتدائي - ب', email: 'a@b.c' };
    // بلا تفعيل الكشف: مرفوض
    await assertFails(setDoc(doc(t, 'teachers', 'newteacher'), { ...prof, createdAt: serverTimestamp() }));
    // التفعيل وإنشاء الملف في دفعة واحدة
    const { writeBatch } = await import('firebase/firestore');
    const b = writeBatch(t);
    b.update(doc(t, 'teacherRoster/1000000002'), { uid: 'newteacher', email: 'a@b.c', activatedAt: serverTimestamp() });
    b.set(doc(t, 'teachers', 'newteacher'), { ...prof, createdAt: serverTimestamp() });
    await assertSucceeds(b.commit());
    await assertFails(updateDoc(doc(t, 'teachers', 'newteacher'), { className: 'السادس الابتدائي - أ' })); // فصل غير مسند
    await assertSucceeds(updateDoc(doc(t, 'teachers', 'newteacher'), { className: 'الثالث الابتدائي - أ' }));
    // معلم غير مدرج في أي كشف لا ينشئ ملفاً
    await assertFails(setDoc(doc(teacherDbNew('stranger'), 'teachers', 'stranger'), { ...prof, civilId: '1000000009', createdAt: serverTimestamp() }));
});

test('نقل تبعية مدرسة: المدير الجديد يرسل طلباً، والحالي يحذفها من عنده فتصير للجديد', async () => {
    const p1 = teacherDbNew(P1), p2 = teacherDbNew(P2);
    // المدير الجديد سجّل نفسه بالرقم الإحصائي نفسه (المدرسة مسجلة لغيره)
    await assertSucceeds(setDoc(doc(p2, 'principals', P2), { name: 'مدير جديد', civilId: '1000000200', email: 'n@x.com', schoolNo: '123456', createdAt: serverTimestamp() }));
    const req = { schoolNo: '123456', requesterUid: P2, requesterName: 'مدير جديد', createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(teacherDbNew('rand'), 'schoolTransfers/123456'), { ...req, requesterUid: 'rand' })); // ليس مديراً مسجلاً بالرقم
    await assertFails(setDoc(doc(p2, 'schoolTransfers/123456'), { ...req, requesterUid: P1 }));
    await assertFails(setDoc(doc(p1, 'schoolTransfers/123456'), { ...req, requesterUid: P1 }));  // الحالي لا يطلب لنفسه
    await assertSucceeds(setDoc(doc(p2, 'schoolTransfers/123456'), req));
    await assertSucceeds(getDoc(doc(p1, 'schoolTransfers/123456')));        // المدير الحالي يرى التنبيه
    await assertSucceeds(getDoc(doc(p2, 'schoolTransfers/123456')));
    await assertFails(getDoc(doc(teacherDbNew('thief'), 'schoolTransfers/123456')));
    // لا ينقل المدير الجديد الملكية بنفسه، ولا يوجّهها لغير صاحب الطلب
    await assertFails(updateDoc(doc(p2, 'schools/123456'), { principalUid: P2, principalName: 'مدير جديد' }));
    await assertFails(updateDoc(doc(p1, 'schools/123456'), { principalUid: 'thief', principalName: 'x' }));
    await assertFails(updateDoc(doc(p1, 'schools/123456'), { principalUid: P2, principalName: 'اسم آخر' }));
    // المدير الحالي: «حذف المدرسة من عندي»
    const { writeBatch } = await import('firebase/firestore');
    const b = writeBatch(p1);
    b.update(doc(p1, 'schools/123456'), { principalUid: P2, principalName: 'مدير جديد' });
    b.delete(doc(p1, 'schoolTransfers/123456'));
    await assertSucceeds(b.commit());
    // الجديد يملك الآن كشف المعلمين، والسابق لا
    await assertSucceeds(getDocs(query(collection(p2, 'teacherRoster'), where('schoolNo', '==', '123456'))));
    await assertFails(getDocs(query(collection(p1, 'teacherRoster'), where('schoolNo', '==', '123456'))));
    await assertSucceeds(updateDoc(doc(p2, 'schools/123456'), { name: 'باسم الجديد' }));
    await assertFails(updateDoc(doc(p1, 'schools/123456'), { name: 'اسم السابق' }));
});

test('طلب النقل: يلغيه صاحبه أو يرفضه المدير الحالي', async () => {
    const p1 = teacherDbNew(P1), p2 = teacherDbNew(P2);
    await assertSucceeds(setDoc(doc(p2, 'principals', P2), { name: 'مدير جديد', civilId: '1000000200', email: 'n@x.com', schoolNo: '123456', createdAt: serverTimestamp() }));
    const req = { schoolNo: '123456', requesterUid: P2, requesterName: 'مدير جديد', createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(p2, 'schoolTransfers/123456'), req));
    await assertFails(setDoc(doc(p2, 'schoolTransfers/123456'), req)); // طلب واحد قائم
    await assertSucceeds(deleteDoc(doc(p1, 'schoolTransfers/123456')));  // رفض
    await assertSucceeds(setDoc(doc(p2, 'schoolTransfers/123456'), req));
    await assertFails(deleteDoc(doc(teacherDbNew('thief'), 'schoolTransfers/123456')));
    await assertSucceeds(deleteDoc(doc(p2, 'schoolTransfers/123456')));  // إلغاء
});

test('مقدم خدمات التميز: يضيف المدارس المسجّلة بالرقم الإحصائي، ويتنازل المقدم السابق عند الطلب', async () => {
    const v1 = teacherDbNew('prov1'), v2 = teacherDbNew('prov2');
    const pr = (n) => ({ name: `مقدم ${n}`, civilId: `100000030${n}`, email: `v${n}@x.com`, createdAt: serverTimestamp() });
    await assertSucceeds(setDoc(doc(v1, 'providers', 'prov1'), pr(1)));
    await assertSucceeds(setDoc(doc(v2, 'providers', 'prov2'), pr(2)));
    await assertFails(setDoc(doc(v1, 'providers', 'prov2'), pr(2)));
    const link = (uid, name) => ({ schoolNo: '123456', providerUid: uid, providerName: name, createdAt: serverTimestamp() });
    await assertFails(setDoc(doc(v1, 'providerLinks/999999'), { ...link('prov1', 'مقدم 1'), schoolNo: '999999' })); // مدرسة لم يسجلها مديرها
    await assertFails(setDoc(doc(teacherDbNew('nobody'), 'providerLinks/123456'), link('nobody', 'x')));            // ليس مقدماً مسجلاً
    await assertFails(setDoc(doc(v1, 'providerLinks/123456'), link('prov2', 'مقدم 2')));
    await assertSucceeds(setDoc(doc(v1, 'providerLinks/123456'), link('prov1', 'مقدم 1')));
    await assertFails(setDoc(doc(v2, 'providerLinks/123456'), link('prov2', 'مقدم 2')));                           // مأخوذة
    await assertSucceeds(getDoc(doc(v2, 'providerLinks/123456')));                                                  // يرى اسم المقدم الحالي
    await assertSucceeds(getDocs(query(collection(v1, 'providerLinks'), where('providerUid', '==', 'prov1'))));
    await assertFails(getDocs(query(collection(v2, 'providerLinks'), where('providerUid', '==', 'prov1'))));
    // تنبيه المقدم السابق
    const rq = { schoolNo: '123456', requesterUid: 'prov2', requesterName: 'مقدم 2', createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(v1, 'providerRequests/123456'), { ...rq, requesterUid: 'prov1', requesterName: 'مقدم 1' })); // الحالي لا يطلب لنفسه
    await assertSucceeds(setDoc(doc(v2, 'providerRequests/123456'), rq));
    await assertSucceeds(getDoc(doc(v1, 'providerRequests/123456')));
    await assertFails(getDoc(doc(teacherDbNew('thief'), 'providerRequests/123456')));
    await assertFails(updateDoc(doc(v2, 'providerLinks/123456'), { providerUid: 'prov2', providerName: 'مقدم 2' }));  // لا يستولي بنفسه
    await assertFails(updateDoc(doc(v1, 'providerLinks/123456'), { providerUid: 'thief', providerName: 'x' }));
    const { writeBatch } = await import('firebase/firestore');
    const b = writeBatch(v1);
    b.update(doc(v1, 'providerLinks/123456'), { providerUid: 'prov2', providerName: 'مقدم 2' });
    b.delete(doc(v1, 'providerRequests/123456'));
    await assertSucceeds(b.commit());
    await assertSucceeds(getDocs(query(collection(v2, 'providerLinks'), where('providerUid', '==', 'prov2'))));
    await assertSucceeds(deleteDoc(doc(v2, 'providerLinks/123456')));                                               // يحذفها من عنده
    await assertFails(deleteDoc(doc(v1, 'providerLinks/123456')));
});

test('الأعوام الدراسية: المدير يفتح عاماً جديداً (تُؤرشف الأعوام ولا تُحذف)، وغيره لا', async () => {
    const p1 = teacherDbNew(P1), p2 = teacherDbNew(P2);
    const years = [{ label: '1447هـ', start: 1 }, { label: '1448هـ', start: 2 }];
    await assertSucceeds(updateDoc(doc(p1, 'schools/123456'), { year: '1448هـ', years }));
    await assertFails(updateDoc(doc(p2, 'schools/123456'), { year: '1449هـ', years }));
    await assertFails(updateDoc(doc(p1, 'schools/123456'), { year: '1449هـ', years: Array.from({ length: 81 }, (_, i) => ({ label: String(i), start: i })) }));
    await assertSucceeds(getDoc(doc(teacherDbNew('t'), 'schools/123456')));      // المعلم يقرأ العام الحالي والأعوام
});

test('مدرسة بلا مدير: يتسلمها مديرها المسجل برقمها فقط، ويقرأ أرشيفها', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
        const f = ctx.firestore();
        await updateDoc(doc(f, 'schools/123456'), { principalUid: null, principalName: null });
        await setDoc(doc(f, 'principals', P2), { name: 'مدير جديد', civilId: '1000000200', email: 'n@x.com', schoolNo: '123456', createdAt: new Date() });
        await setDoc(doc(f, 'principals', 'principal3'), { name: 'آخر', civilId: '1000000300', email: 'o@x.com', schoolNo: '999999', createdAt: new Date() });
        await setDoc(doc(f, 'tests/old1'), { teacherUid: 'gone', schoolNo: '123456', year: 'y', title: 'قديم', createdAt: new Date() });
        await setDoc(doc(f, 'attempts/oldA'), { testId: 'old1', teacherUid: 'gone', studentId: 's', schoolNo: '123456', year: 'y', score: 3 });
    });
    const pdb = (uid) => teacherDb(uid);
    await assertFails(updateDoc(doc(pdb('principal3'), 'schools/123456'), { principalUid: 'principal3', principalName: 'آخر' }));
    await assertFails(updateDoc(doc(pdb(P2), 'schools/123456'), { principalUid: P2, principalName: 'م', name: 'غيّرت' }));
    await assertSucceeds(updateDoc(doc(pdb(P2), 'schools/123456'), { principalUid: P2, principalName: 'مدير جديد' }));
    await assertSucceeds(getDoc(doc(pdb(P2), 'tests/old1')));
    await assertSucceeds(getDocs(query(collection(pdb(P2), 'attempts'), where('schoolNo', '==', '123456'))));
    await assertFails(getDocs(query(collection(pdb('principal3'), 'attempts'), where('schoolNo', '==', '123456'))));
});
