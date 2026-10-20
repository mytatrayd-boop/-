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

test('الطالب: يقرأ سجله برقمه ويحفظ النتيجة فقط', async () => {
    const db = studentDb();
    await assertSucceeds(getDoc(doc(db, 'students/1111111111')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'students/1111111111')));
    await assertSucceeds(updateDoc(doc(db, 'students/1111111111'), { score: 50, status: 'منجز', completedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, 'students/1111111111'), { score: 150, status: 'منجز', completedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, 'students/1111111111'), { score: 50, status: 'منجز', completedAt: serverTimestamp(), name: 'x' }));
    await assertFails(updateDoc(doc(db, 'students/1111111111'), { teacherUid: 'anon1' }));
    await assertFails(deleteDoc(doc(db, 'students/1111111111')));
});

test('حذف طالب: صاحبه فقط', async () => {
    await assertFails(deleteDoc(doc(teacherDb(T2), 'students/1111111111')));
    await assertFails(updateDoc(doc(teacherDb(T2), 'students/1111111111'), { name: 'x' }));
    await assertFails(updateDoc(doc(teacherDb(T1), 'students/1111111111'), { teacherUid: T2 }));
    await assertSucceeds(deleteDoc(doc(teacherDb(T1), 'students/1111111111')));
});
