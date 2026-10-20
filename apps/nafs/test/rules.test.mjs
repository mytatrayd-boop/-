// قواعد Firestore على المحاكي (يشغله: npm test).
import test, { before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where, addDoc, serverTimestamp } from 'firebase/firestore';

let env;
const T1 = 'teacher1', T2 = 'teacher2';
const teacherDb = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'password' } }).firestore();
const studentDb = () => env.authenticatedContext('anon1', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const profile = { name: 'معلم', civilId: '1000000001', school: 'مدرسة', className: 'الثالث الابتدائي - أ', email: 't@x.com' };
const student = (uid) => ({ name: 'طالب', teacherUid: uid, className: 'الثالث الابتدائي - أ', school: 'مدرسة', status: 'لم يبدأ', createdAt: serverTimestamp() });

before(async () => {
    const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
    env = await initializeTestEnvironment({ projectId: 'demo-nafs', firestore: { host, port: Number(port), rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') } });
});
after(() => env.cleanup());
beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'students/1111111111'), { ...student(T1), createdAt: new Date() });
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
