import { initializeApp } from 'firebase/app';
import {
    getAuth, connectAuthEmulator, onAuthStateChanged, signInWithEmailAndPassword,
    createUserWithEmailAndPassword, sendPasswordResetEmail, signInAnonymously, signOut,
} from 'firebase/auth';
import {
    getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, deleteDoc,
    collection, query, where, getDocs, addDoc, writeBatch, serverTimestamp, orderBy,
} from 'firebase/firestore';
import { CLASSES, MAX_UPLOAD_BYTES, isCivilId, parseStudentRows, scoreQuiz, summarize, reportCsv } from './logic.js';

const $ = (id) => document.getElementById(id);

let auth, db;
let teacher = null;        // {uid, name, civilId, school, className, email}
let students = [];         // طلاب المعلم كلهم (كل الفصول)
let uploads = [];
let activeStudent = null;  // {id, name, ...}
let teacherTab = 'students';
let authMode = 'login';

// ---------- الإعداد ----------

async function firebaseConfig() {
    if (['localhost', '127.0.0.1'].includes(location.hostname)) {
        return { emulator: true, config: { apiKey: 'demo-key', projectId: 'demo-nafs', authDomain: 'demo-nafs.firebaseapp.com' } };
    }
    // Firebase Hosting يقدّم إعدادات المشروع تلقائياً على هذا المسار.
    const res = await fetch('/__/firebase/init.json');
    if (!res.ok) throw new Error('init.json ' + res.status);
    return { emulator: false, config: await res.json() };
}

async function start() {
    fillClassSelects();
    bindEvents();
    try {
        const { emulator, config } = await firebaseConfig();
        const app = initializeApp(config);
        auth = getAuth(app);
        db = getFirestore(app);
        if (emulator) {
            connectAuthEmulator(auth, `http://${location.hostname}:9099`, { disableWarnings: true });
            connectFirestoreEmulator(db, location.hostname, 8080);
        }
    } catch (err) {
        console.error(err);
        $('loadingScreen').textContent = 'تعذر الاتصال بالخادم. حدّث الصفحة بعد قليل.';
        return;
    }
    onAuthStateChanged(auth, handleAuthChange);
}

async function handleAuthChange(user) {
    if (!user) { teacher = null; showScreen(activeStudent ? 'studentLoginScreen' : 'roleSelectionScreen'); return; }
    if (user.isAnonymous) {
        // جلسة الطالب لا تُستعاد بعد تحديث الصفحة.
        if (!activeStudent) await signOut(auth);
        return;
    }
    try {
        const snap = await getDoc(doc(db, 'teachers', user.uid));
        if (!snap.exists()) {
            // حساب أنشئ ولم يكتمل ملفه (انقطاع أثناء التسجيل) — ننتظر نموذج التسجيل يكمله.
            if (authMode === 'signup') return;
            showScreen('teacherLoginScreen');
            setAuthMode('signup');
            $('signupEmail').value = user.email || '';
            showAlert('أكمل بيانات حسابك للمتابعة.', 'إكمال التسجيل');
            return;
        }
        teacher = { uid: user.uid, ...snap.data() };
        await openTeacherDashboard();
    } catch (err) {
        reportError(err);
    }
}

// ---------- التنقل ----------

function showScreen(id) {
    document.querySelectorAll('.screen').forEach((el) => el.classList.toggle('hidden', el.id !== id));
    const isTeacher = id === 'teacherDashboardScreen';
    $('userInfoHeader').classList.toggle('hidden', !isTeacher);
    if (isTeacher) $('headerTeacherName').textContent = teacher.name;
}

function setAuthMode(mode) {
    authMode = mode;
    $('teacherLoginForm').classList.toggle('hidden', mode !== 'login');
    $('teacherSignupForm').classList.toggle('hidden', mode !== 'signup');
    const on = 'flex-1 py-2 rounded-lg bg-white shadow text-emerald-700';
    const off = 'flex-1 py-2 rounded-lg text-slate-500';
    $('authTabLogin').className = mode === 'login' ? on : off;
    $('authTabSignup').className = mode === 'signup' ? on : off;
}

function fillClassSelects() {
    document.querySelectorAll('.class-select').forEach((sel) => {
        for (const c of CLASSES) sel.add(new Option(c.replace(' - ', ' (') + ')', c));
    });
}

// ---------- المعلم ----------

async function teacherLogin(e) {
    e.preventDefault();
    await busy(e.submitter, async () => {
        await signInWithEmailAndPassword(auth, $('loginEmail').value.trim(), $('loginPassword').value);
        $('loginPassword').value = '';
    });
}

async function teacherSignup(e) {
    e.preventDefault();
    const profile = {
        name: $('tName').value.trim(),
        civilId: $('tId').value.trim(),
        school: $('tSchool').value.trim(),
        className: $('tClass').value,
        email: $('signupEmail').value.trim(),
    };
    if (!isCivilId(profile.civilId)) return showAlert('السجل المدني يجب أن يكون مكوناً من 10 أرقام.', 'تنبيه خطأ');
    await busy(e.submitter, async () => {
        let user = auth.currentUser;
        if (!user || user.isAnonymous || user.email !== profile.email) {
            user = (await createUserWithEmailAndPassword(auth, profile.email, $('signupPassword').value)).user;
        }
        await setDoc(doc(db, 'teachers', user.uid), { ...profile, createdAt: serverTimestamp() });
        $('signupPassword').value = '';
        teacher = { uid: user.uid, ...profile };
        authMode = 'login';
        await openTeacherDashboard();
        showAlert('تم إنشاء حسابك. بياناتك محفوظة وتجدها من أي جهاز.', 'نجح التسجيل');
    });
}

async function resetPassword() {
    const email = $('loginEmail').value.trim();
    if (!email) return showAlert('اكتب بريدك الإلكتروني أولاً ثم اضغط «نسيت كلمة المرور».', 'تنبيه');
    try {
        await sendPasswordResetEmail(auth, email);
        showAlert('أرسلنا رابط تغيير كلمة المرور إلى بريدك (إن كان مسجلاً).', 'تم الإرسال');
    } catch (err) { reportError(err); }
}

async function logout() {
    await signOut(auth);
    students = []; uploads = [];
    showAlert('تم تسجيل الخروج بنجاح.', 'إشعار');
}

async function openTeacherDashboard() {
    showScreen('teacherDashboardScreen');
    $('dashWelcome').textContent = `مرحباً بك أستاذ/ة: ${teacher.name}`;
    $('dashClass').value = teacher.className;
    renderMeta();
    await Promise.all([loadStudents(), loadUploads()]);
}

function renderMeta() {
    $('dashMeta').textContent = `المدرسة: ${teacher.school} | الفصل: ${teacher.className}`;
}

async function changeClass() {
    const className = $('dashClass').value;
    try {
        await updateDoc(doc(db, 'teachers', teacher.uid), { className });
        teacher.className = className;
        renderMeta();
        renderTeacher();
    } catch (err) { reportError(err); $('dashClass').value = teacher.className; }
}

function switchTeacherTab(tab) {
    teacherTab = tab;
    const on = 'pb-3 border-b-2 border-emerald-600 font-bold text-emerald-700 text-sm transition';
    const off = 'pb-3 border-b-2 border-transparent text-slate-500 hover:text-slate-800 font-bold text-sm transition';
    $('teacherTabStudents').classList.toggle('hidden', tab !== 'students');
    $('teacherTabReports').classList.toggle('hidden', tab !== 'reports');
    $('tabBtnStudents').className = tab === 'students' ? on : off;
    $('tabBtnReports').className = tab === 'reports' ? on : off;
    renderTeacher();
}

const classStudents = () => students.filter((s) => s.className === teacher.className);

async function loadStudents() {
    const snap = await getDocs(query(collection(db, 'students'), where('teacherUid', '==', teacher.uid)));
    students = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
        .sort((a, b) => (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0));
    renderTeacher();
}

function cell(text, cls = 'p-3') {
    const td = document.createElement('td');
    td.className = cls;
    td.textContent = text;
    return td;
}

function emptyRow(text) {
    const tr = document.createElement('tr');
    tr.append(cell(text, 'p-6 text-center text-slate-400'));
    tr.firstChild.colSpan = 5;
    return tr;
}

function renderTeacher() {
    const list = classStudents();
    if (teacherTab === 'students') {
        $('studentCount').textContent = list.length;
        const tbody = $('studentsTableBody');
        tbody.replaceChildren();
        if (!list.length) tbody.append(emptyRow('لا يوجد طلاب مسجلين بعد. قم بإضافة طلاب أو ارفع ملف أكسل.'));
        list.forEach((s, i) => {
            const tr = document.createElement('tr');
            tr.className = 'hover:bg-slate-50/80 transition';
            const level = cell('');
            const badge = document.createElement('span');
            badge.className = 'px-2.5 py-1 bg-emerald-50 text-emerald-700 rounded-lg font-bold';
            badge.textContent = typeof s.score === 'number' ? s.score + '%' : 'لم يقس بعد';
            level.append(badge);
            const actions = cell('', 'p-3 text-center');
            const del = document.createElement('button');
            del.className = 'text-red-500 hover:text-red-700 font-bold px-2 py-1 rounded';
            del.textContent = 'حذف';
            del.dataset.action = 'delete-student';
            del.dataset.id = s.id;
            actions.append(del);
            tr.append(cell(i + 1, 'p-3 font-bold'), cell(s.name, 'p-3 font-semibold text-slate-800'), cell(s.id, 'p-3 font-mono text-slate-600'), level, actions);
            tbody.append(tr);
        });
    } else {
        const sum = summarize(list);
        $('repTotalStudents').textContent = sum.total;
        $('repCompletedCount').textContent = sum.completed;
        $('repAvgMastery').textContent = sum.avg + '%';
        const tbody = $('reportsTableBody');
        tbody.replaceChildren();
        if (!list.length) tbody.append(emptyRow('لا توجد بيانات تقارير متاحة حالياً.'));
        for (const s of list) {
            const done = typeof s.score === 'number';
            const tr = document.createElement('tr');
            const status = cell('');
            const pill = document.createElement('span');
            pill.className = 'px-2.5 py-1 rounded-full text-[11px] ' + (done ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600');
            pill.textContent = done ? 'منجز' : 'بانتظار الاختبار';
            status.append(pill);
            tr.append(cell(s.name, 'p-3 font-bold text-slate-800'), cell(s.id, 'p-3 font-mono'), cell('طلاقة وقراءة استيعابية'),
                cell(done ? s.score + '%' : 'غير مختبر', 'p-3 font-bold text-emerald-600'), status);
            tbody.append(tr);
        }
    }
}

function newStudentDoc(name) {
    return { name, teacherUid: teacher.uid, className: teacher.className, school: teacher.school, status: 'لم يبدأ', createdAt: serverTimestamp() };
}

// يرجع: 'mine' مسجل عندك | 'other' مسجل عند معلم آخر | null غير مسجل
async function existingOwner(id) {
    if (students.some((s) => s.id === id)) return 'mine';
    const snap = await getDoc(doc(db, 'students', id));
    if (!snap.exists()) return null;
    return snap.data().teacherUid === teacher.uid ? 'mine' : 'other';
}

async function addStudent(e) {
    e.preventDefault();
    const name = $('newStudentName').value.trim();
    const id = $('newStudentId').value.trim();
    if (!isCivilId(id)) return showAlert('رقم السجل المدني للطالب يجب أن يكون 10 أرقام.', 'تنبيه');
    await busy(e.submitter, async () => {
        const owner = await existingOwner(id);
        if (owner === 'mine') return showAlert('رقم السجل المدني هذا مسجل مسبقاً في فصولك.', 'تنبيه');
        if (owner === 'other') return showAlert('هذا الطالب مسجل لدى معلم آخر.', 'تنبيه');
        await setDoc(doc(db, 'students', id), newStudentDoc(name));
        $('newStudentName').value = '';
        $('newStudentId').value = '';
        await loadStudents();
        showAlert('تم إضافة الطالب بنجاح!', 'نجاح');
    });
}

async function deleteStudent(id) {
    const s = students.find((x) => x.id === id);
    if (!s || !(await confirmDialog(`حذف الطالب «${s.name}» ونتيجته نهائياً؟`))) return;
    try {
        await deleteDoc(doc(db, 'students', id));
        await loadStudents();
    } catch (err) { reportError(err); }
}

async function clearAllStudents() {
    const list = classStudents();
    if (!list.length) return;
    if (!(await confirmDialog(`حذف جميع طلاب فصل «${teacher.className}» (${list.length}) ونتائجهم نهائياً؟`))) return;
    try {
        for (let i = 0; i < list.length; i += 400) {
            const batch = writeBatch(db);
            list.slice(i, i + 400).forEach((s) => batch.delete(doc(db, 'students', s.id)));
            await batch.commit();
        }
        await loadStudents();
        showAlert('تم حذف جميع الطلاب بنجاح.', 'إشعار');
    } catch (err) { reportError(err); }
}

// ---------- ملفات الأكسل ----------

function toBase64(buf) {
    const bytes = new Uint8Array(buf);
    let bin = '';
    for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
    return btoa(bin);
}

async function handleExcelUpload(e) {
    const input = e.target;
    const file = input.files[0];
    input.value = '';
    if (!file) return;
    if (file.size > MAX_UPLOAD_BYTES) return showAlert('حجم الملف أكبر من 700 كيلوبايت. احذف الأعمدة الزائدة وأعد المحاولة.', 'تنبيه');
    showAlert('جاري رفع الملف واستيراد الطلاب…', 'لحظات');
    try {
        const buf = await file.arrayBuffer();
        let rows;
        try {
            const XLSX = await import('xlsx'); // يُحمَّل عند أول رفع فقط
            const wb = XLSX.read(new Uint8Array(buf), { type: 'array' });
            rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1 });
        } catch {
            return showAlert('حدث خطأ أثناء قراءة ملف الأكسل. تأكد من صحة التنسيق.', 'خطأ');
        }
        const parsed = parseStudentRows(rows);
        if (!parsed.length) return showAlert('لم نجد في الملف أي صف فيه اسم طالب ورقم سجل مدني من 10 أرقام.', 'تنبيه');
        let added = 0, mine = 0, other = 0;
        const toAdd = [];
        for (const s of parsed) {
            const owner = await existingOwner(s.id);
            if (owner === 'mine') mine++;
            else if (owner === 'other') other++;
            else toAdd.push(s);
        }
        for (let i = 0; i < toAdd.length; i += 400) {
            const batch = writeBatch(db);
            toAdd.slice(i, i + 400).forEach((s) => batch.set(doc(db, 'students', s.id), newStudentDoc(s.name)));
            await batch.commit();
            added += Math.min(400, toAdd.length - i);
        }
        await addDoc(collection(db, 'teachers', teacher.uid, 'uploads'), {
            name: file.name.slice(0, 200), size: file.size, type: file.type || 'application/octet-stream',
            data: toBase64(buf), className: teacher.className, added, createdAt: serverTimestamp(),
        });
        await Promise.all([loadStudents(), loadUploads()]);
        let msg = `تم استيراد ${added} طالباً بنجاح من ملف الأكسل، وحُفظ الملف في حسابك.`;
        if (mine) msg += ` (${mine} مسجلون مسبقاً لديك)`;
        if (other) msg += ` (${other} مسجلون لدى معلم آخر ولم يُضافوا)`;
        showAlert(msg, 'نجاح الاستيراد');
    } catch (err) { reportError(err); }
}

async function loadUploads() {
    const snap = await getDocs(query(collection(db, 'teachers', teacher.uid, 'uploads'), orderBy('createdAt', 'desc')));
    uploads = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    $('uploadCount').textContent = uploads.length;
    const ul = $('uploadsList');
    ul.replaceChildren();
    if (!uploads.length) {
        const li = document.createElement('li');
        li.className = 'text-slate-400';
        li.textContent = 'لم ترفع أي ملف بعد.';
        ul.append(li);
    }
    for (const u of uploads) {
        const li = document.createElement('li');
        li.className = 'flex items-center justify-between gap-2 p-2.5 bg-slate-50 rounded-xl border border-slate-200';
        const info = document.createElement('div');
        info.className = 'min-w-0';
        const name = document.createElement('p');
        name.className = 'font-bold text-slate-800 truncate';
        name.textContent = u.name;
        const meta = document.createElement('p');
        meta.className = 'text-slate-500';
        const date = u.createdAt?.toDate ? u.createdAt.toDate().toLocaleDateString('ar-SA') : '';
        meta.textContent = `${u.className} · ${u.added} طالب · ${date}`;
        info.append(name, meta);
        const btns = document.createElement('div');
        btns.className = 'flex gap-2 shrink-0';
        const dl = document.createElement('button');
        dl.className = 'text-teal-700 font-bold';
        dl.textContent = 'تنزيل';
        dl.dataset.action = 'download-upload';
        dl.dataset.id = u.id;
        const del = document.createElement('button');
        del.className = 'text-red-500 font-bold';
        del.textContent = 'حذف';
        del.dataset.action = 'delete-upload';
        del.dataset.id = u.id;
        btns.append(dl, del);
        li.append(info, btns);
        ul.append(li);
    }
}

function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function downloadUpload(id) {
    const u = uploads.find((x) => x.id === id);
    if (!u) return;
    const bin = atob(u.data);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    downloadBlob(new Blob([bytes], { type: u.type }), u.name);
}

async function deleteUpload(id) {
    const u = uploads.find((x) => x.id === id);
    if (!u || !(await confirmDialog(`حذف الملف «${u.name}» من حسابك؟ (الطلاب المستوردون منه يبقون)`))) return;
    try {
        await deleteDoc(doc(db, 'teachers', teacher.uid, 'uploads', id));
        await loadUploads();
    } catch (err) { reportError(err); }
}

function exportReport() {
    const list = classStudents();
    if (!list.length) return showAlert('لا توجد بيانات طلاب لتصديرها.', 'تنبيه');
    downloadBlob(new Blob([reportCsv(list)], { type: 'text/csv;charset=utf-8;' }), `تقرير_نواتج_التعلم_${teacher.className}.csv`);
    showAlert('تم تصدير التقرير الدوري بنجاح!', 'نجاح التصدير');
}

// ---------- الطالب ----------

async function studentLogin(e) {
    e.preventDefault();
    const id = $('sIdInput').value.trim();
    if (!isCivilId(id)) return showAlert('رقم السجل المدني يجب أن يكون 10 أرقام.', 'تنبيه');
    await busy(e.submitter, async () => {
        activeStudent = { id };
        if (!auth.currentUser) await signInAnonymously(auth);
        const snap = await getDoc(doc(db, 'students', id));
        if (!snap.exists()) {
            activeStudent = null;
            return showAlert('عذراً، رقم السجل المدني غير مسجل في النظام. تأكد من المعلم.', 'تنبيه دخول');
        }
        activeStudent = { id, ...snap.data() };
        $('sIdInput').value = '';
        document.querySelectorAll('#quizContainer input[type=radio]').forEach((r) => { r.checked = false; });
        $('quizContainer').classList.add('hidden');
        showScreen('studentDashboardScreen');
        $('studentFullNameDisplay').textContent = `أهلاً بك، ${activeStudent.name}`;
        $('studentClassDisplay').textContent = `رقم السجل المدني: ${id} | ${activeStudent.className}`;
    });
}

async function studentLogout(message = 'تم تسجيل خروج الطالب.', title = 'إشعار') {
    activeStudent = null;
    if (auth.currentUser?.isAnonymous) await signOut(auth);
    showScreen(teacher ? 'teacherDashboardScreen' : 'roleSelectionScreen');
    showAlert(message, title);
}

async function submitQuiz(e) {
    const answers = ['q1', 'q2'].map((q) => document.querySelector(`input[name="${q}"]:checked`)?.value);
    if (answers.includes(undefined)) return showAlert('الرجاء الإجابة عن جميع الأسئلة قبل الإرسال.', 'تنبيه');
    const score = scoreQuiz(answers);
    await busy(e.target, async () => {
        await updateDoc(doc(db, 'students', activeStudent.id), { score, status: 'منجز', completedAt: serverTimestamp() });
        await studentLogout(`ممتاز! لقد أكملت التدريب بنجاح. نتيجتك هي: ${score}%`, 'نتيجة الاختبار');
    });
}

// ---------- رسائل ----------

let modalResolve = null;

function showAlert(message, title = 'تنبيه') {
    if (modalResolve) { modalResolve(false); modalResolve = null; }
    $('modalTitle').textContent = title;
    $('modalMessage').textContent = message;
    $('modalCancel').classList.add('hidden');
    $('modalOk').textContent = 'حسناً';
    $('customModal').classList.remove('hidden');
}

function confirmDialog(message) {
    showAlert(message, 'تأكيد');
    $('modalCancel').classList.remove('hidden');
    $('modalOk').textContent = 'نعم، احذف';
    return new Promise((resolve) => { modalResolve = resolve; });
}

function closeModal(result) {
    $('customModal').classList.add('hidden');
    if (modalResolve) { modalResolve(result); modalResolve = null; }
}

const AUTH_ERRORS = {
    'auth/invalid-credential': 'البريد أو كلمة المرور غير صحيحة.',
    'auth/wrong-password': 'البريد أو كلمة المرور غير صحيحة.',
    'auth/user-not-found': 'البريد أو كلمة المرور غير صحيحة.',
    'auth/email-already-in-use': 'هذا البريد مسجل مسبقاً. استخدم «تسجيل الدخول».',
    'auth/weak-password': 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.',
    'auth/invalid-email': 'البريد الإلكتروني غير صحيح.',
    'auth/too-many-requests': 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.',
    'auth/network-request-failed': 'لا يوجد اتصال بالإنترنت.',
    'permission-denied': 'ليست لديك صلاحية لهذا الإجراء.',
    'unavailable': 'لا يوجد اتصال بالخادم. تحقق من الإنترنت.',
};

function reportError(err) {
    console.error(err);
    showAlert(AUTH_ERRORS[err?.code] || 'حدث خطأ غير متوقع. أعد المحاولة.', 'خطأ');
}

async function busy(button, fn) {
    if (button) button.disabled = true;
    try { await fn(); } catch (err) { reportError(err); } finally { if (button) button.disabled = false; }
}

// ---------- الأحداث ----------

function bindEvents() {
    $('teacherLoginForm').addEventListener('submit', teacherLogin);
    $('teacherSignupForm').addEventListener('submit', teacherSignup);
    $('addStudentForm').addEventListener('submit', addStudent);
    $('studentLoginForm').addEventListener('submit', studentLogin);
    $('excelFile').addEventListener('change', handleExcelUpload);
    $('dashClass').addEventListener('change', changeClass);
    $('modalOk').addEventListener('click', () => closeModal(true));
    $('modalCancel').addEventListener('click', () => closeModal(false));

    document.addEventListener('click', (e) => {
        const el = e.target.closest('[data-action]');
        if (!el) return;
        const { action, id, tab } = el.dataset;
        switch (action) {
            case 'show-teacher-login': showScreen('teacherLoginScreen'); setAuthMode('login'); break;
            case 'show-student-login': showScreen('studentLoginScreen'); break;
            case 'back': showScreen('roleSelectionScreen'); break;
            case 'auth-tab': setAuthMode(tab); break;
            case 'reset-password': resetPassword(); break;
            case 'logout': logout(); break;
            case 'teacher-tab': switchTeacherTab(tab); break;
            case 'export': exportReport(); break;
            case 'clear-all': clearAllStudents(); break;
            case 'delete-student': deleteStudent(id); break;
            case 'download-upload': downloadUpload(id); break;
            case 'delete-upload': deleteUpload(id); break;
            case 'start-quiz': $('quizContainer').classList.remove('hidden'); break;
            case 'submit-quiz': submitQuiz(e); break;
            case 'student-logout': studentLogout(); break;
        }
    });
}

start();
