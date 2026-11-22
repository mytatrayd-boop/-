import { initializeApp } from 'firebase/app';
import {
    getAuth, connectAuthEmulator, onAuthStateChanged, signInWithEmailAndPassword,
    createUserWithEmailAndPassword, sendPasswordResetEmail, signInAnonymously, signOut,
} from 'firebase/auth';
import {
    getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, deleteDoc,
    collection, query, where, getDocs, addDoc, writeBatch, serverTimestamp, orderBy,
} from 'firebase/firestore';
import {
    CLASSES, MAX_UPLOAD_BYTES, isCivilId, parseStudentRows, buildReport, masteryLevel, reportCsv, shuffleOptions, questionError,
} from './logic.js';
import { GRADES, LEVELS, SUBJECTS, subjectsOfGrade, groupsFor, outcomesFor, skillsFor, skillIdsFor, gradeOfClass, skillById } from './skills.js';
import { TEMPLATES } from './templates.js';
import { omrSheetHtml, omrKeyHtml, bookletHtml, esc, OMR_PER_PAGE } from './omr.js';
import { scanSheet } from './omr-scan.js';
import { SITE_STATS } from './site-stats.js';
import { academicYear, nextYearLabel, yearOf } from './years.js';
import { BANK_STATUS, canTransition, qualityIssues, usableInTest, isDuplicate, newBankQuestion } from './bank.js';

const $ = (id) => document.getElementById(id);

let auth, db;
let bank = [];            // بنك أسئلة المعلم
let bankEditing = null;   // id السؤال قيد التحرير ('new' لسؤال جديد)
let teacher = null;        // {uid, name, civilId, school, schoolNo, className, email}
let teacherSubjects = null; // تخصصات المعلم من كشف مدرسته (null = كل المواد)
let teacherClasses = [];   // الفصول المسندة للمعلم من كشف مدرسته
let principal = null;      // {uid, name, civilId, email, schoolNo}
let provider = null;       // مقدم خدمات التميز {uid, name, civilId, email}
let providerSchools = [];  // مدارس المقدم: {no, schoolName, principalName, incoming}
let school = null;         // مدرسة المدير (مستند schools)
let roster = [];           // كشف معلمي المدرسة
let schoolYears = [];      // أعوام مدرسة المعلم [{label, start}]
let currentYear = '';      // العام الدراسي الحالي
let viewYear = '';         // العام المعروض (الأرشيف للاطلاع فقط)
let transferIn = null;     // طلب نقل وارد لمدرستي من مدير جديد
let otherSchool = null;    // مدرسة برقمي تتبع مديراً آخر {name, principalName}
let transferOut = null;    // طلبي لنقل تبعية مدرسة إليّ
let students = [];         // طلاب المعلم كلهم (كل الفصول)
let uploads = [];
let activeStudent = null;  // {id, name, ...}
let teacherTab = 'students';
let pins = {}; // كلمات مرور طلاب المعلم الحالي: {سجل مدني: 6 أرقام}
let authMode = 'login';
let activating = false;    // تسجيل مدير أو تفعيل معلم قيد التنفيذ
let tests = [];            // اختبارات المعلم (كل الفصول)
let keys = {};             // testId → الإجابات الصحيحة
let attempts = [];         // محاولات طلاب المعلم
let draft = null;          // الاختبار قيد البناء
let studentTests = [];     // اختبارات فصل الطالب المنشورة
let openTest = null;
let repSubject = 'reading'; // مادة تقرير المعلم الحالية
let aboutFrom = 'roleSelectionScreen';

const testSubject = (t) => t.subject ?? 'reading'; // الاختبارات القديمة بلا مادة = قراءة
// مواد الصف التي يدرّسها المعلم (تخصصه من كشف المدرسة)؛ بلا تخصص مسجّل أو بلا تقاطع ⇒ كل مواد الصف
const mySubjects = (grade) => {
    const all = subjectsOfGrade(grade), mine = teacherSubjects ? all.filter((x) => teacherSubjects.includes(x)) : all;
    return mine.length ? mine : all;
};
const isImageTest = (t) => t.questions.some((q) => q.image);

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
    if (!user) { if (activating) return; teacher = null; principal = null; provider = null; school = null; showScreen(activeStudent ? 'studentLoginScreen' : 'roleSelectionScreen'); return; }
    if (user.isAnonymous) {
        // جلسة الطالب لا تُستعاد بعد تحديث الصفحة.
        if (!activeStudent) await signOut(auth);
        return;
    }
    if (activating) return; // تفعيل معلم أو تسجيل مدير جارٍ: ينهيه مسار التسجيل نفسه
    try {
        const snap = await getDoc(doc(db, 'teachers', user.uid));
        if (snap.exists()) {
            teacher = { uid: user.uid, ...snap.data() };
            if (!teacher.schoolNo) return linkLegacyTeacher(user); // حساب قديم: يُربط بكشف مدرسته أو يُمنع
            return await openTeacherDashboard();
        }
        const ps = await getDoc(doc(db, 'principals', user.uid));
        if (ps.exists()) {
            principal = { uid: user.uid, ...ps.data() };
            return await openPrincipalDashboard(true);
        }
        const vs = await getDoc(doc(db, 'providers', user.uid));
        if (vs.exists()) {
            provider = { uid: user.uid, ...vs.data() };
            return await openProviderDashboard();
        }
        // حساب بلا ملف (تسجيل لم يكتمل أو معلم لم يُضَف): لا دخول.
        await signOut(auth);
        showAlert('لم يتعرّف النظام على هذا الحساب. المعلم يُفعّل حسابه بعد أن يضيفه مدير مدرسته، والمدير يسجّل مدرسته من بوابة المدير.', 'لا يوجد حساب');
    } catch (err) {
        reportError(err);
    }
}

// ---------- التنقل ----------

// أرقام الصفحة الرئيسية: تعدّ من الصفر إلى قيمتها عند ظهور الصفحة (وتظهر نهائية فوراً لمن يفضّل تقليل الحركة)
let countersRun = 0;
function runCounters() {
    const run = ++countersRun;
    const value = (k) => SITE_STATS[k] ?? SITE_STATS.subjects[k];
    const nodes = [...document.querySelectorAll('[data-count]')];
    const fmt = new Intl.NumberFormat('en-US');
    const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const t0 = performance.now(), dur = 1600;
    const tick = (now) => {
        if (run !== countersRun) return;
        const p = still ? 1 : Math.min(1, (now - t0) / dur), ease = 1 - (1 - p) ** 3;
        for (const n of nodes) n.textContent = (n.hasAttribute('data-plus') ? '+' : '') + fmt.format(Math.round(value(n.dataset.count) * ease));
        if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
}
// الأرقام في أسفل الصفحة: يبدأ العدّ حين تظهر على الشاشة
let statsObserver;
function watchCounters() {
    const box = $('statsSection');
    document.querySelectorAll('[data-count]').forEach((n) => { n.textContent = n.hasAttribute('data-plus') ? '+0' : '0'; });
    statsObserver?.disconnect();
    if (!box || !('IntersectionObserver' in window)) return runCounters();
    statsObserver = new IntersectionObserver((es) => { if (es.some((x) => x.isIntersecting)) { statsObserver.disconnect(); runCounters(); } }, { threshold: 0.3 });
    statsObserver.observe(box);
}

function showScreen(id) {
    if (id === 'roleSelectionScreen') watchCounters();
    document.querySelectorAll('.screen').forEach((el) => el.classList.toggle('hidden', el.id !== id));
    const isTeacher = id === 'teacherDashboardScreen', isPrincipal = id === 'principalDashboardScreen';
    $('userInfoHeader').classList.toggle('hidden', !isTeacher && !isPrincipal);
    if (isTeacher) $('headerTeacherName').textContent = teacher.name;
    if (isPrincipal) $('headerTeacherName').textContent = principal.name;
    if (id === 'providerDashboardScreen') { $('userInfoHeader').classList.remove('hidden'); $('headerTeacherName').textContent = provider.name; }
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

// المعلم لا يدخل ما لم يُضِفه مدير مدرسته: نتحقق من كشف المدرسة برقم سجله المدني قبل إبقاء الحساب.
async function teacherSignup(e) {
    e.preventDefault();
    const civilId = $('tId').value.trim(), email = $('signupEmail').value.trim();
    if (!isCivilId(civilId)) return showAlert('السجل المدني يجب أن يكون مكوناً من 10 أرقام.', 'تنبيه خطأ');
    await busy(e.submitter, async () => {
        activating = true;
        let user;
        try {
            user = (await createUserWithEmailAndPassword(auth, email, $('signupPassword').value)).user;
            let row;
            try { row = await getDoc(doc(db, 'teacherRoster', civilId)); } catch { row = null; }
            if (!row?.exists() || row.data().uid) {
                await user.delete();
                showScreen('teacherLoginScreen'); setAuthMode('signup');
                return showAlert('لم يتعرّف عليك النظام: لا يوجد معلم بهذا السجل المدني أضافه مدير مدرسته، أو أن حسابه مفعّل مسبقاً. اطلب من مدير مدرستك إضافتك.', 'لا يُقبل الدخول');
            }
            const r = row.data();
            const sc = (await getDoc(doc(db, 'schools', r.schoolNo))).data();
            const profile = { name: r.name, civilId, school: sc.name, schoolNo: r.schoolNo, className: r.classes[0], email, ...(r.subjects ? { subjects: r.subjects } : {}) };
            const batch = writeBatch(db);
            batch.update(doc(db, 'teacherRoster', civilId), { uid: user.uid, email, activatedAt: serverTimestamp() });
            batch.set(doc(db, 'teachers', user.uid), { ...profile, createdAt: serverTimestamp() });
            await batch.commit();
            $('signupPassword').value = '';
            teacher = { uid: user.uid, ...profile };
            authMode = 'login';
            teacherClasses = r.classes; teacherSubjects = r.subjects ?? null;
            activating = false;
            await openTeacherDashboard();
            showAlert('تم تفعيل حسابك. تجد بياناتك من أي جهاز، وتدخل لاحقاً ببريدك وكلمة مرورك.', 'تم إنشاء حسابك');
        } catch (err) {
            if (user) { await user.delete().catch(() => {}); await signOut(auth).catch(() => {}); }
            throw err;
        } finally { setTimeout(() => { activating = false; }, 600); }
    });
}

// حساب معلم قديم (قبل نظام المدارس): يُربط بكشف مدرسته إن أضافه المدير، وإلا يُمنع.
async function linkLegacyTeacher(user) {
    try {
        const row = await getDoc(doc(db, 'teacherRoster', teacher.civilId));
        if (row.exists() && !row.data().uid) {
            const r = row.data();
            const sc = (await getDoc(doc(db, 'schools', r.schoolNo))).data();
            const className = r.classes.includes(teacher.className) ? teacher.className : r.classes[0];
            const profile = { name: teacher.name, civilId: teacher.civilId, school: sc.name, schoolNo: r.schoolNo, className, email: teacher.email, ...(r.subjects ? { subjects: r.subjects } : {}) };
            const batch = writeBatch(db);
            batch.update(doc(db, 'teacherRoster', teacher.civilId), { uid: user.uid, email: teacher.email || user.email, activatedAt: serverTimestamp() });
            batch.set(doc(db, 'teachers', user.uid), { ...profile, createdAt: serverTimestamp() });
            await batch.commit();
            teacher = { uid: user.uid, ...profile };
            teacherClasses = r.classes; teacherSubjects = r.subjects ?? null;
            return await openTeacherDashboard();
        }
    } catch { /* نمنع الدخول أدناه */ }
    teacher = null;
    await signOut(auth);
    showAlert('لم يتعرّف عليك النظام: مدير مدرستك لم يضفك بعد. اطلب منه إضافتك برقم سجلك المدني ثم ادخل من جديد.', 'لا يُقبل الدخول');
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

async function loadSchoolYears() {
    try {
        const sc = (await getDoc(doc(db, 'schools', teacher.schoolNo))).data();
        currentYear = sc.year;
        schoolYears = (sc.years?.length ? sc.years : [{ label: sc.year, start: 0 }]).slice().sort((a, b) => a.start - b.start);
    } catch { currentYear = ''; schoolYears = []; }
    viewYear = currentYear;
    const sel = $('yearSel');
    sel.replaceChildren(...schoolYears.slice().reverse().map((y) => new Option(y.label + (y.label === currentYear ? ' (الحالي)' : ' (أرشيف)'), y.label)));
    sel.value = currentYear;
    sel.classList.toggle('hidden', !schoolYears.length);
}

async function loadTeacherClasses() {
    try {
        const r = await getDoc(doc(db, 'teacherRoster', teacher.civilId));
        if (r.exists() && r.data().uid === teacher.uid) { teacherClasses = r.data().classes; teacherSubjects = r.data().subjects ?? null; }
    } catch { /* نبقي الفصل الحالي فقط */ }
    if (!teacherClasses.includes(teacher.className)) teacherClasses = [teacher.className, ...teacherClasses];
    const sel = $('dashClass');
    sel.replaceChildren(...teacherClasses.map((c) => new Option(c.replace(' - ', ' (') + ')', c)));
}

async function openTeacherDashboard() {
    await loadTeacherClasses();
    await loadSchoolYears();
    showScreen('teacherDashboardScreen');
    $('dashWelcome').textContent = `مرحباً بك أستاذ/ة: ${teacher.name}`;
    $('dashClass').value = teacher.className;
    renderMeta();
    await Promise.all([loadStudents(), loadUploads(), loadTeacherTests()]);
}

function renderMeta() {
    $('dashMeta').textContent = `المدرسة: ${teacher.school} | الفصل: ${teacher.className}` + (teacherSubjects ? ` | التخصص: ${teacherSubjects.map((x) => SUBJECTS[x].name).join('، ')}` : '');
}

async function changeClass() {
    const className = $('dashClass').value;
    try {
        await updateDoc(doc(db, 'teachers', teacher.uid), { className });
        teacher.className = className;
        if (!mySubjects(currentGrade()).includes(repSubject)) repSubject = mySubjects(currentGrade())[0];
        $('officialPanel').classList.add('hidden');
        $('bankPanel').classList.add('hidden');
        renderMeta();
        renderTeacher();
    } catch (err) { reportError(err); $('dashClass').value = teacher.className; }
}

const TAB_ON = 'pb-3 border-b-2 border-emerald-600 font-bold text-emerald-700 text-sm transition whitespace-nowrap';
const TAB_OFF = 'pb-3 border-b-2 border-transparent text-slate-500 hover:text-slate-800 font-bold text-sm transition whitespace-nowrap';

function switchTeacherTab(tab) {
    teacherTab = tab;
    for (const [name, panel, btn] of [['students', 'teacherTabStudents', 'tabBtnStudents'], ['tests', 'teacherTabTests', 'tabBtnTests'], ['bank', 'teacherTabBank', 'tabBtnBank'], ['reports', 'teacherTabReports', 'tabBtnReports']]) {
        $(panel).classList.toggle('hidden', tab !== name);
        $(btn).className = tab === name ? TAB_ON : TAB_OFF;
    }
    if (tab === 'bank') loadBank(); else renderTeacher();
}

const classStudents = () => students.filter((s) => s.className === teacher.className);

async function loadStudents() {
    const snap = await getDocs(query(collection(db, 'students'), where('teacherUid', '==', teacher.uid)));
    students = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
        .sort((a, b) => (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0));
    const ps = await getDocs(query(collection(db, 'studentPins'), where('teacherUid', '==', teacher.uid)));
    pins = Object.fromEntries(ps.docs.map((d) => [d.id, d.data().pin]));
    renderTeacher();
}

function el(tag, cls = '', text = '') {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== '') e.textContent = text;
    return e;
}

function cell(text, cls = 'p-3') {
    return el('td', cls, text);
}

function emptyRow(text, cols = 5) {
    const tr = el('tr');
    const td = cell(text, 'p-6 text-center text-slate-400');
    td.colSpan = cols;
    tr.append(td);
    return tr;
}

function actionButton(text, action, id, cls) {
    const b = el('button', cls, text);
    b.dataset.action = action;
    if (id) b.dataset.id = id;
    return b;
}

const TONE_BADGE = { good: 'bg-emerald-100 text-emerald-800', mid: 'bg-amber-100 text-amber-800', low: 'bg-red-100 text-red-700', none: 'bg-slate-100 text-slate-500' };
const TONE_BAR = { good: 'bg-emerald-500', mid: 'bg-amber-400', low: 'bg-red-400', none: 'bg-slate-200' };

function badge(pct) {
    const m = masteryLevel(pct);
    return el('span', `inline-block px-2.5 py-1 rounded-full text-[11px] font-bold whitespace-nowrap ${TONE_BADGE[m.tone]}`, m.label);
}

function statRow(name, stat, hint = '') {
    const pct = stat ? stat.pct : null;
    const row = el('div', 'space-y-1');
    const top = el('div', 'flex justify-between items-center gap-3 text-xs');
    const label = el('span', 'font-semibold text-slate-700', name);
    if (hint) label.title = hint;
    const right = el('span', 'flex items-center gap-2 shrink-0');
    right.append(el('span', 'font-black text-slate-800', pct === null ? '—' : pct + '%'), badge(pct));
    top.append(label, right);
    const track = el('div', 'h-2 bg-slate-100 rounded-full overflow-hidden');
    const fill = el('div', `h-full rounded-full ${TONE_BAR[masteryLevel(pct).tone]}`);
    fill.style.width = (pct ?? 0) + '%';
    track.append(fill);
    row.append(top, track);
    if (stat?.t) row.append(el('p', 'text-[11px] text-slate-400', `${stat.c} صحيحة من ${stat.t}`));
    return row;
}

const ms = (ts) => ts?.toMillis?.() ?? 0;
function inViewYear(created) {
    const i = schoolYears.findIndex((y) => y.label === viewYear);
    if (i < 0 || schoolYears.length < 2) return true;
    const from = i === 0 ? -Infinity : schoolYears[i].start, to = i === schoolYears.length - 1 ? Infinity : schoolYears[i + 1].start;
    const t = ms(created);
    return t >= from && t < to;
}
const classTests = () => tests.filter((t) => t.className === teacher.className && inViewYear(t.createdAt));
const currentGrade = () => gradeOfClass(teacher.className);

// subject = null: كل المواد (للمستوى العام)؛ وإلا اختبارات تلك المادة فقط.
function classReport(subject = null) {
    const ct = Object.fromEntries(classTests().filter((t) => !subject || testSubject(t) === subject).map((t) => [t.id, t]));
    return buildReport(classStudents(), attempts.filter((a) => ct[a.testId]), ct, keys);
}

async function loadTeacherTests() {
    const mine = (name) => getDocs(query(collection(db, name), where('teacherUid', '==', teacher.uid)));
    const [t, k, a] = await Promise.all([mine('tests'), mine('testKeys'), mine('attempts')]);
    tests = t.docs.map((d) => ({ id: d.id, ...d.data() })).sort((x, y) => ms(y.createdAt) - ms(x.createdAt));
    keys = Object.fromEntries(k.docs.map((d) => [d.id, d.data().answers]));
    attempts = a.docs.map((d) => ({ id: d.id, ...d.data(), submittedAt: ms(d.data().submittedAt) }));
    renderTeacher();
}

function renderTeacher() {
    if (!teacher) return;
    if (teacherTab === 'students') renderStudentsTab(classReport());
    else if (teacherTab === 'tests') renderTestsTab();
    else if (teacherTab === 'bank') renderBank();
    else renderReports(classReport(repSubject));
}

function renderStudentsTab(report) {
    const list = classStudents();
    const byId = Object.fromEntries(report.students.map((s) => [s.id, s]));
    $('studentCount').textContent = list.length;
    const tbody = $('studentsTableBody');
    tbody.replaceChildren();
    if (!list.length) tbody.append(emptyRow('لا يوجد طلاب مسجلين بعد. قم بإضافة طلاب أو ارفع ملف أكسل.'));
    list.forEach((s, i) => {
        const tr = el('tr', 'hover:bg-slate-50/80 transition');
        const r = byId[s.id];
        const level = cell('');
        level.append(el('span', 'font-black text-slate-800 ml-2', r?.pct === null || !r ? '' : r.pct + '%'), badge(r?.pct ?? null));
        const actions = cell('', 'p-3 text-center');
        actions.append(actionButton('حذف', 'delete-student', s.id, 'text-red-500 hover:text-red-700 font-bold px-2 py-1 rounded'));
        tr.append(cell(i + 1, 'p-3 font-bold'), cell(s.name, 'p-3 font-semibold text-slate-800'), cell(s.id, 'p-3 font-mono text-slate-600'), cell(pins[s.id] ?? '—', 'p-3 font-mono font-bold text-teal-700'), level, actions);
        tbody.append(tr);
    });
}

// ---------- التقارير ----------

function subjectChips(box, subjects, current, action) {
    box.replaceChildren(...subjects.map((id) => {
        const on = id === current;
        const b = actionButton(SUBJECTS[id].name, action, id, 'px-4 py-2 rounded-xl text-xs font-bold border transition ' + (on ? 'bg-emerald-600 text-white border-emerald-600 shadow' : 'bg-white text-slate-600 border-slate-200 hover:border-emerald-400'));
        b.setAttribute('aria-pressed', String(on));
        return b;
    }));
}

function renderReports(report) {
    const grade = currentGrade();
    if (!mySubjects(grade).includes(repSubject)) repSubject = mySubjects(grade)[0];
    subjectChips($('repSubject'), mySubjects(grade), repSubject, 'rep-subject');
    $('repTotalStudents').textContent = report.students.length;
    $('repTests').textContent = classTests().filter((t) => testSubject(t) === repSubject && t.status === 'published').length;
    $('repCompletedCount').textContent = report.tested;
    $('repAvgMastery').textContent = report.avg === null ? '—' : report.avg + '%';

    // المؤشرات المقاسة تُعرض بشريط تحت ناتج تعلمها، وما لم يُقَس يُلخَّص بنواتج التعلم في قائمة مطوية
    const skillsBox = $('repSkills');
    skillsBox.replaceChildren();
    const untestedOutcomes = [];
    let untestedCount = 0;
    for (const g of groupsFor(repSubject, grade)) {
        const group = el('div', 'space-y-3');
        let shown = false;
        for (const o of g.outcomes) {
            const done = o.skills.filter((sk) => report.skills[sk.id]);
            if (!done.length) { untestedOutcomes.push(o); untestedCount += o.skills.length; continue; }
            untestedCount += o.skills.length - done.length;
            if (!shown) {
                group.append(el('p', 'text-[11px] font-bold text-emerald-700 bg-emerald-50 rounded-lg px-3 py-2', g.title ? `${g.domain} — ${g.title}` : g.domain));
                shown = true;
            }
            const sub = el('div', 'space-y-2 pr-3 border-r-2 border-emerald-100');
            sub.append(el('p', 'text-xs font-black text-slate-700', o.name));
            for (const sk of done) sub.append(statRow(sk.name, report.skills[sk.id], sk.desc));
            group.append(sub);
        }
        if (shown) skillsBox.append(group);
    }
    if (untestedCount === skillIdsFor(repSubject, grade).length) {
        skillsBox.append(el('p', 'text-sm text-slate-400 text-center py-6', 'لم يُقَس أي طالب في هذه المادة بعد. انشر اختباراً وانتظر إجابات طلابك.'));
    }
    if (untestedCount) {
        const det = el('details', 'text-xs text-slate-500');
        det.append(el('summary', 'cursor-pointer font-bold text-slate-600', `مؤشرات لم تُقَس بعد (${untestedCount})${untestedOutcomes.length ? ` — منها ${untestedOutcomes.length} ناتج تعلم لم يُقَس إطلاقاً` : ''}`));
        const chips = el('div', 'flex flex-wrap gap-1.5 mt-3');
        for (const o of untestedOutcomes) {
            const c = el('span', 'text-[11px] bg-slate-100 text-slate-600 rounded-lg px-2 py-0.5', `${o.name} (${o.skills.length})`);
            c.title = o.desc;
            chips.append(c);
        }
        det.append(chips);
        skillsBox.append(det);
    }

    const levelsBox = $('repLevels');
    levelsBox.replaceChildren(...LEVELS.map((l) => statRow(l.name, report.levels[l.id])));

    const tbody = $('reportsTableBody');
    tbody.replaceChildren();
    if (!report.students.length) tbody.append(emptyRow('لا يوجد طلاب في هذا الفصل.', 7));
    const sorted = [...report.students].sort((a, b) => (b.pct ?? -1) - (a.pct ?? -1));
    for (const s of sorted) {
        const tr = el('tr', 'hover:bg-slate-50/80');
        const lvl = cell('');
        lvl.append(badge(s.pct));
        const prog = s.progress === null ? cell('—', 'p-3 text-slate-400')
            : cell((s.progress > 0 ? '▲ +' : s.progress < 0 ? '▼ ' : '') + s.progress + '%', 'p-3 font-bold ' + (s.progress > 0 ? 'text-emerald-600' : s.progress < 0 ? 'text-red-600' : 'text-slate-500'));
        const weak = s.weakest && s.skills[s.weakest].pct < 80 ? skillById(s.weakest).name : '—';
        const act = cell('', 'p-3 text-left');
        if (s.history.length) act.append(actionButton('التفاصيل', 'student-detail', s.id, 'text-teal-700 hover:text-teal-900 font-bold'));
        tr.append(cell(s.name, 'p-3 font-bold text-slate-800'), cell(s.history.length), cell(s.pct === null ? '—' : s.pct + '%', 'p-3 font-black'), lvl, prog, cell(weak, 'p-3 text-slate-600'), act);
        tbody.append(tr);
    }
}

function showStudentDetail(id) {
    const s = classReport(repSubject).students.find((x) => x.id === id);
    if (!s) return;
    $('smName').textContent = s.name;
    $('smMeta').textContent = `${SUBJECTS[repSubject].name} · السجل المدني: ${s.id} · النسبة: ${s.pct ?? '—'}% · ${masteryLevel(s.pct).label}`
        + (s.progress === null ? '' : ` · التقدّم من أول اختبار: ${s.progress > 0 ? '+' : ''}${s.progress}%`);
    $('smHistory').replaceChildren(...s.history.map((h) => statRow(`${h.title} — ${new Date(h.at).toLocaleDateString('ar-SA')}`, { pct: h.pct })));
    const box = $('smSkills');
    box.replaceChildren();
    for (const o of outcomesFor(repSubject, currentGrade())) {
        const done = o.skills.filter((sk) => s.skills[sk.id]);
        if (!done.length) continue;
        box.append(el('p', 'text-xs font-black text-slate-700 pt-1', o.name));
        for (const sk of done) box.append(statRow(sk.name, s.skills[sk.id], sk.desc));
    }
    $('studentModal').classList.remove('hidden');
}

function exportReport() {
    const report = classReport(repSubject);
    if (!report.students.length) return showAlert('لا توجد بيانات طلاب لتصديرها.', 'تنبيه');
    const ids = skillIdsFor(repSubject, currentGrade());
    downloadBlob(new Blob([reportCsv(report, ids, (id) => { const sk = skillById(id); return `${sk.outcome.name} — ${sk.name}`; })], { type: 'text/csv;charset=utf-8;' }), `تقرير_${SUBJECTS[repSubject].name}_${teacher.className}.csv`);
    showAlert(`تم تصدير تقرير مادة ${SUBJECTS[repSubject].name} بنجاح!`, 'نجاح التصدير');
}

// ---------- بناء الاختبارات ----------

function renderTestsTab() {
    const grade = currentGrade();
    $('testsClassName').textContent = teacher.className;
    $('testsGradeName').textContent = GRADES[grade].name;
    const archive = viewYear !== currentYear;
    for (const a of ['show-official', 'show-bankpanel', 'new-test']) document.querySelector(`#testsListView [data-action="${a}"], [data-action="${a}"]`)?.classList.toggle('hidden', archive);
    if (draft) return renderBuilder();
    $('testsListView').classList.remove('hidden');
    $('testBuilder').classList.add('hidden');
    const box = $('testsList');
    box.replaceChildren();
    const list = classTests();
    const total = classStudents().length;
    if (!list.length) box.append(el('p', 'text-sm text-slate-400 bg-white rounded-3xl border border-slate-100 p-8 text-center md:col-span-2', 'لا توجد اختبارات لهذا الفصل بعد. اضغط «بناء اختبار جديد».'));
    for (const t of list) {
        const done = attempts.filter((a) => a.testId === t.id).length;
        const card = el('div', 'bg-white p-5 rounded-3xl shadow-sm border border-slate-100 space-y-3');
        const head = el('div', 'flex justify-between items-start gap-3');
        head.append(el('h4', 'font-bold text-slate-800', t.title),
            el('span', 'text-[11px] font-bold px-2.5 py-1 rounded-full whitespace-nowrap ' + (t.status === 'published' ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600'), t.status === 'published' ? 'منشور' : 'مسودة'));
        const meta = el('p', 'text-xs text-slate-500', `${SUBJECTS[testSubject(t)].name} · ${t.questions.length} سؤالاً · ${t.skills.length} مهارات · أجاب ${done} من ${total} طالباً`);
        const chips = el('div', 'flex flex-wrap gap-1.5');
        for (const id of t.skills) chips.append(el('span', 'text-[11px] bg-teal-50 text-teal-800 border border-teal-100 rounded-lg px-2 py-0.5', skillById(id)?.name ?? id));
        const btns = el('div', 'flex flex-wrap gap-3 pt-1 text-xs font-bold');
        btns.append(actionButton(t.status === 'published' ? 'إيقاف النشر' : 'نشر للطلاب', 'toggle-publish', t.id, 'text-emerald-700 hover:text-emerald-900'));
        // النماذج الرسمية أسئلتها صور: لا تُعدَّل (تُحذف وتُضاف من جديد)
        if (!isImageTest(t)) btns.append(actionButton(done ? 'نسخ كاختبار جديد' : 'تعديل', 'edit-test', t.id, 'text-slate-700 hover:text-slate-900'));
        btns.append(actionButton('🖨️ ورقة إجابة (تظليل يدوي)', 'print-omr', t.id, 'text-teal-700 hover:text-teal-900'), actionButton('كتيّب الأسئلة', 'print-book', t.id, 'text-teal-700 hover:text-teal-900'), actionButton('📷 مسح الأوراق وتصحيحها', 'scan-omr', t.id, 'text-indigo-700 hover:text-indigo-900'), actionButton('مفتاح التصحيح', 'print-key', t.id, 'text-teal-700 hover:text-teal-900'));
        btns.append(actionButton('حذف', 'delete-test', t.id, 'text-red-500 hover:text-red-700'));
        card.append(head, meta, chips, btns);
        box.append(card);
    }
}

// طباعة ورقة الإجابة أو مفتاح التصحيح في نافذة جديدة
// ---------- مسح أوراق الإجابة وتصحيحها آلياً ----------
const OMR_MAX_SIDE = 1800;
let omrTest = null, omrRows = [];

function openOmrScan(id) {
    const t = classTests().find((x) => x.id === id);
    if (!t) return;
    if (t.questions.length > OMR_PER_PAGE) return showAlert(`المسح يدعم حتى ${OMR_PER_PAGE} سؤالاً. هذا الاختبار فيه ${t.questions.length}.`, 'عدد الأسئلة كبير');
    if (!keys[t.id]) return showAlert('لا يتوفر مفتاح هذا الاختبار.', 'تنبيه');
    omrTest = t; omrRows = [];
    $('omrTitle').textContent = `مسح أوراق الإجابة — ${t.title}`;
    $('omrFiles').value = '';
    $('omrStatus').textContent = '';
    $('omrApprove').disabled = true;
    renderOmrRows();
    $('omrModal').classList.remove('hidden');
}

async function fileToGray(file) {
    const bmp = await createImageBitmap(file);
    const k = Math.min(1, OMR_MAX_SIDE / Math.max(bmp.width, bmp.height));
    const w = Math.round(bmp.width * k), h = Math.round(bmp.height * k);
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const g = c.getContext('2d', { willReadFrequently: true });
    g.fillStyle = '#fff'; g.fillRect(0, 0, w, h);
    g.drawImage(bmp, 0, 0, w, h);
    const d = g.getImageData(0, 0, w, h).data;
    const gray = new Uint8Array(w * h);
    for (let i = 0; i < gray.length; i++) gray[i] = (d[i * 4] * 299 + d[i * 4 + 1] * 587 + d[i * 4 + 2] * 114) / 1000;
    bmp.close?.();
    return { gray, w, h };
}

function omrRowState(r) {
    const st = classStudents().find((s) => s.id === r.id);
    r.student = st ?? null;
    const key = keys[omrTest.id] ?? [];
    r.correct = r.answers ? r.answers.filter((a, i) => a === key[i]).length : 0;
    const prior = st ? attempts.find((a) => a.id === `${omrTest.id}_${st.id}`) : null;
    r.blocked = prior && prior.source !== 'paper' ? 'أجاب إلكترونياً' : '';
    r.replace = !!prior && prior.source === 'paper';
    r.importable = !!(r.ok && st && !r.blocked);
    if (!r.importable) r.include = false;
}

function renderOmrRows() {
    const box = $('omrResults');
    box.replaceChildren();
    for (const r of omrRows) {
        const row = el('div', `border rounded-2xl p-3 text-xs space-y-2 ${r.ok ? 'border-slate-200' : 'border-red-200 bg-red-50'}`);
        const top = el('div', 'flex flex-wrap items-center gap-3');
        const cb = el('input', ''); cb.type = 'checkbox'; cb.checked = !!r.include; cb.disabled = !r.importable;
        cb.addEventListener('change', () => { r.include = cb.checked; updateOmrApprove(); });
        top.append(cb, el('span', 'font-bold text-slate-700', r.name));
        if (!r.ok) { top.append(el('span', 'text-red-700 font-bold', r.error)); row.append(top); box.append(row); continue; }
        const idIn = el('input', 'border border-slate-300 rounded-lg px-2 py-1 w-28 text-center font-mono'); idIn.value = r.id; idIn.maxLength = 10; idIn.setAttribute('aria-label', 'رقم السجل المدني');
        idIn.addEventListener('change', () => { r.id = idIn.value.trim(); omrRowState(r); r.include = r.importable; renderOmrRows(); });
        top.append(idIn);
        top.append(el('span', r.student ? 'text-emerald-700 font-bold' : 'text-red-600 font-bold', r.student ? r.student.name : (isCivilId(r.id) ? 'غير مسجل في هذا الفصل' : 'رقم السجل ناقص: صحّحه')));
        top.append(el('span', 'text-slate-700', `الدرجة: ${r.correct} من ${omrTest.questions.length}`));
        if (r.blanks) top.append(el('span', 'text-amber-700', `${r.blanks} بلا تظليل`));
        if (r.multiples) top.append(el('span', 'text-amber-700', `${r.multiples} تظليل مزدوج`));
        if (r.blocked) top.append(el('span', 'text-red-600 font-bold', r.blocked + ' — لا يُستبدل'));
        else if (r.replace) top.append(el('span', 'text-slate-500', 'سيستبدل محاولة ورقية سابقة'));
        const letters = ['أ', 'ب', 'ج', 'د'];
        const key = keys[omrTest.id] ?? [];
        const det = el('p', 'leading-7 text-slate-600');
        r.answers.forEach((a, i) => {
            const s = el('span', `inline-block mx-0.5 px-1.5 rounded ${a === key[i] ? 'bg-emerald-50 text-emerald-800' : (a < 0 ? 'bg-amber-100 text-amber-800' : 'bg-red-50 text-red-700')}`, `${i + 1}:${a === -1 ? '—' : a === -2 ? '⚠' : letters[a]}`);
            det.append(s);
        });
        row.append(top, det);
        box.append(row);
    }
    updateOmrApprove();
}

function updateOmrApprove() {
    const n = omrRows.filter((r) => r.include).length;
    $('omrApprove').disabled = !n;
    $('omrApprove').textContent = n ? `اعتماد ${n} ورقة` : 'اعتماد النتائج المحددة';
}

async function handleOmrFiles(files) {
    if (!omrTest) return;
    const total = files.length;
    let n = 0;
    for (const f of files) {
        $('omrStatus').textContent = `جارٍ قراءة ${++n} من ${total}…`;
        await new Promise((r) => setTimeout(r)); // لتحديث الواجهة بين الصور
        let res;
        try { const { gray, w, h } = await fileToGray(f); res = scanSheet(gray, w, h, omrTest.questions.length); }
        catch { res = { ok: false, error: 'تعذّرت قراءة الملف كصورة.' }; }
        const r = { name: f.name, ...res, include: false };
        if (r.ok) { omrRowState(r); r.include = r.importable; }
        omrRows.push(r);
        renderOmrRows();
    }
    $('omrStatus').textContent = `تمت قراءة ${total} ملف. راجع النتائج ثم اعتمد.`;
}

async function approveOmr(btn) {
    const chosen = omrRows.filter((r) => r.include && r.importable);
    if (!chosen.length) return;
    await busy(btn, async () => {
        for (let i = 0; i < chosen.length; i += 400) {
            const batch = writeBatch(db);
            for (const r of chosen.slice(i, i + 400)) {
                batch.set(doc(db, 'attempts', `${omrTest.id}_${r.student.id}`), {
                    testId: omrTest.id, studentId: r.student.id, teacherUid: teacher.uid, className: teacher.className,
                    answers: r.answers.map((a) => (a >= 0 ? a : -1)), source: 'paper', submittedAt: serverTimestamp(),
                });
            }
            await batch.commit();
        }
        $('omrModal').classList.add('hidden');
        await loadTeacherTests();
        showAlert(`اعتُمدت نتائج ${chosen.length} ورقة، وظهرت في تقارير الفصل مع نتائج الاختبارات الإلكترونية.`, 'تم التصحيح');
    });
}

function printOmr(id, action) {
    const t = classTests().find((x) => x.id === id);
    if (!t) return;
    const base = { title: t.title, className: teacher.className };
    const subjectName = SUBJECTS[testSubject(t)].name;
    let html;
    if (action === 'print-key') html = omrKeyHtml({ ...base, answers: keys[t.id] ?? [] });
    else if (action === 'print-book') html = bookletHtml({ ...base, subjectName, passageText: t.passage || '', questions: t.questions, baseUrl: `${location.origin}/` });
    else {
        if (t.questions.length > OMR_PER_PAGE) return showAlert(`ورقة الإجابة تتسع لـ ${OMR_PER_PAGE} سؤالاً. هذا الاختبار فيه ${t.questions.length}.`, 'عدد الأسئلة كبير');
        html = omrSheetHtml({ ...base, subjectName, count: t.questions.length });
    }
    html = html.replace('</body>', '<script>addEventListener("load",()=>setTimeout(()=>print(),900))</script></body>');
    const url = URL.createObjectURL(new Blob([html], { type: 'text/html;charset=utf-8' }));
    if (!window.open(url, '_blank')) showAlert('اسمح للموقع بفتح النوافذ المنبثقة ثم أعد المحاولة.', 'تعذّر فتح الطباعة');
}

function openBuilder(test) {
    const copy = test && attempts.some((a) => a.testId === test.id); // اختبار له إجابات يُنسخ ولا يُعدّل
    draft = test ? {
        id: copy ? null : test.id,
        createdAt: copy ? null : test.createdAt,
        status: copy ? 'draft' : test.status,
        title: copy ? `${test.title} (نسخة)` : test.title,
        passage: test.passage,
        subject: testSubject(test),
        className: teacher.className,
        grade: test.grade,
        skills: [...test.skills],
        questions: test.questions.map((q, i) => ({ ...q, options: [...q.options, '', '', ''].slice(0, Math.max(4, q.options.length)), answer: keys[test.id]?.[i] ?? 0 })),
    } : { id: null, title: '', passage: '', subject: 'reading', className: teacher.className, grade: currentGrade(), skills: [], questions: [] };
    renderTestsTab();
}

function closeBuilder() {
    draft = null;
    renderTestsTab();
}

function renderBuilder() {
    $('testsListView').classList.add('hidden');
    $('testBuilder').classList.remove('hidden');
    $('tbError').classList.add('hidden');
    $('tbHeading').textContent = draft.id ? 'تعديل اختبار' : 'اختبار جديد';
    $('tbTitle').value = draft.title;
    $('tbPassage').value = draft.passage;
    $('tbClass').textContent = draft.className;
    $('tbGrade').textContent = GRADES[draft.grade].name;
    if (!mySubjects(draft.grade).includes(draft.subject)) draft.subject = mySubjects(draft.grade)[0];
    subjectChips($('tbSubject'), mySubjects(draft.grade), draft.subject, 'tb-subject');
    const reading = draft.subject === 'reading';
    $('tbPassageTitle').textContent = reading ? '٢. نص القراءة' : '٢. نص أو معطيات (اختياري)';
    $('tbPassageHint').classList.toggle('hidden', reading);
    document.querySelector('[data-action="load-template"]').classList.toggle('hidden', !reading || !TEMPLATES[draft.grade]);
    const box = $('tbSkills');
    box.replaceChildren();
    for (const g of groupsFor(draft.subject, draft.grade)) {
        const group = el('fieldset', 'border border-slate-200 rounded-2xl p-4 space-y-3');
        group.append(el('legend', 'px-2 text-xs font-bold text-emerald-700', g.title ? `${g.domain} — ${g.title}` : g.domain));
        for (const o of g.outcomes) {
            const block = el('div', 'space-y-1 bg-slate-50/60 rounded-xl p-3');
            const head = el('div', 'flex items-start justify-between gap-3');
            const heading = el('div');
            heading.append(el('p', 'text-sm font-black text-slate-800', o.name), el('p', 'text-[11px] text-slate-400 leading-relaxed', o.desc));
            const all = o.skills.every((sk) => draft.skills.includes(sk.id));
            head.append(heading, actionButton(all ? 'إلغاء الكل' : 'تحديد الكل', 'toggle-outcome', o.id, 'shrink-0 text-[11px] font-bold text-emerald-700 hover:text-emerald-900'));
            block.append(head);
            for (const sk of o.skills) {
                const label = el('label', 'flex items-start gap-3 p-2 rounded-lg hover:bg-white cursor-pointer');
                const cb = el('input', 'mt-1 accent-emerald-600 w-4 h-4 shrink-0');
                cb.type = 'checkbox';
                cb.dataset.skill = sk.id;
                cb.checked = draft.skills.includes(sk.id);
                label.append(cb, el('span', 'block text-[13px] leading-relaxed text-slate-700', sk.desc));
                block.append(label);
            }
            group.append(block);
        }
        box.append(group);
    }
    renderQuestions();
}

function toggleOutcome(outcomeId) {
    const o = outcomesFor(draft.subject, draft.grade).find((x) => x.id === outcomeId);
    if (!o) return;
    const ids = o.skills.map((sk) => sk.id);
    draft.skills = ids.every((id) => draft.skills.includes(id))
        ? draft.skills.filter((id) => !ids.includes(id))
        : [...new Set([...draft.skills, ...ids])];
    renderBuilder();
}

async function setBuilderSubject(subject) {
    if (subject === draft.subject) return;
    if ((draft.skills.length || draft.questions.length) && !(await confirmDialog('تغيير المادة يمسح المهارات والأسئلة الحالية. متابعة؟', 'نعم، غيّر المادة'))) return;
    Object.assign(draft, { subject, skills: [], questions: [] });
    renderBuilder();
}

const SKILL_ORDER = () => skillIdsFor(draft.subject, draft.grade);

function renderQuestions() {
    $('tbCount').textContent = draft.questions.length;
    const box = $('tbQuestions');
    box.replaceChildren();
    if (!draft.questions.length) box.append(el('p', 'text-sm text-slate-400 text-center py-6', draft.skills.length ? 'أضف سؤالاً لكل مهارة اخترتها.' : 'اختر المهارات أولاً، ثم أضف الأسئلة.'));
    const chosen = SKILL_ORDER().filter((id) => draft.skills.includes(id));
    draft.questions.forEach((q, i) => {
        const card = el('div', 'border border-slate-200 rounded-2xl p-4 space-y-3 bg-slate-50/50');
        const head = el('div', 'flex justify-between items-center');
        head.append(el('span', 'text-xs font-black text-slate-700', `سؤال ${i + 1}`), actionButton('حذف السؤال', 'remove-question', String(i), 'text-xs text-red-500 font-bold'));
        const selects = el('div', 'grid grid-cols-1 sm:grid-cols-3 gap-2');
        const skill = el('select', 'sm:col-span-2 px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs');
        skill.dataset.q = i; skill.dataset.f = 'skill';
        skill.add(new Option('— اختر مهارة السؤال —', ''));
        for (const id of chosen) { const sk = skillById(id); skill.add(new Option(sk.outcome ? `${sk.outcome.name} — ${sk.name}` : sk.name, id)); }
        skill.value = chosen.includes(q.skill) ? q.skill : '';
        const level = el('select', 'px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs');
        level.dataset.q = i; level.dataset.f = 'level';
        for (const l of LEVELS) level.add(new Option(l.name, l.id));
        level.value = q.level;
        selects.append(skill, level);
        const text = el('textarea', 'w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm');
        text.rows = 2; text.placeholder = 'نص السؤال'; text.value = q.text; text.maxLength = 500;
        text.dataset.q = i; text.dataset.f = 'text';
        const opts = el('div', 'grid grid-cols-1 sm:grid-cols-2 gap-2');
        q.options.forEach((o, j) => {
            const row = el('label', 'flex items-center gap-2 bg-white border border-slate-200 rounded-xl px-3 py-2');
            const radio = el('input', 'accent-emerald-600');
            radio.type = 'radio'; radio.name = `tb-ans-${i}`; radio.checked = q.answer === j; radio.title = 'الإجابة الصحيحة';
            radio.dataset.q = i; radio.dataset.f = 'answer'; radio.dataset.o = j;
            const inp = el('input', 'flex-1 min-w-0 text-sm bg-transparent focus:outline-none');
            inp.value = o; inp.placeholder = `الخيار ${j + 1}`; inp.maxLength = 300;
            inp.dataset.q = i; inp.dataset.f = 'opt'; inp.dataset.o = j;
            row.append(radio, inp);
            opts.append(row);
        });
        card.append(head, selects, text, opts, el('p', 'text-[11px] text-slate-400', 'اختر الدائرة بجانب الإجابة الصحيحة.'));
        box.append(card);
    });
}

function builderInput(e) {
    const t = e.target;
    if (t.id === 'tbTitle') draft.title = t.value;
    else if (t.id === 'tbPassage') draft.passage = t.value;
    else if (t.dataset.skill) {
        draft.skills = t.checked ? [...draft.skills, t.dataset.skill] : draft.skills.filter((id) => id !== t.dataset.skill);
        renderQuestions();
    } else if (t.dataset.q !== undefined) {
        const q = draft.questions[Number(t.dataset.q)];
        if (t.dataset.f === 'opt') q.options[Number(t.dataset.o)] = t.value;
        else if (t.dataset.f === 'answer') q.answer = Number(t.dataset.o);
        else q[t.dataset.f] = t.value;
    }
}

function addQuestion() {
    if (!draft.skills.length) return builderError('اختر مهارة واحدة على الأقل قبل إضافة الأسئلة.');
    const chosen = SKILL_ORDER().filter((id) => draft.skills.includes(id));
    // المهارة الافتراضية: أول مهارة مختارة ليس لها سؤال بعد
    const skill = chosen.find((id) => !draft.questions.some((q) => q.skill === id)) ?? chosen[0];
    draft.questions.push({ skill, level: 'know', text: '', options: ['', '', '', ''], answer: 0 });
    $('tbError').classList.add('hidden');
    renderQuestions();
    $('tbQuestions').lastChild.querySelector('textarea').focus();
}

async function loadTemplate() {
    const t = TEMPLATES[draft.grade];
    if ((draft.passage.trim() || draft.questions.length) && !(await confirmDialog('سيُستبدل النص والأسئلة الحالية بالنموذج الجاهز. متابعة؟', 'نعم، استبدل'))) return;
    draft.title = draft.title.trim() || t.title;
    draft.passage = t.passage;
    draft.questions = t.questions.map((q) => shuffleOptions(q));
    draft.skills = [...new Set(t.questions.map((q) => q.skill))];
    renderBuilder();
}

function builderError(msg) {
    $('tbError').textContent = msg;
    $('tbError').classList.remove('hidden');
    $('tbError').scrollIntoView({ behavior: 'smooth', block: 'center' });
}

async function saveTest(button, publish) {
    if (!draft.title.trim()) return builderError('اكتب عنوان الاختبار.');
    if (draft.subject === 'reading' && !draft.passage.trim()) return builderError('اكتب نص القراءة.');
    if (!draft.questions.length) return builderError('أضف سؤالاً واحداً على الأقل.');
    for (const [i, q] of draft.questions.entries()) {
        const err = questionError(q, draft.skills);
        if (err) return builderError(`سؤال ${i + 1}: ${err}`);
    }
    // حذف الخيارات الفارغة مع تعديل رقم الإجابة الصحيحة
    const clean = draft.questions.map((q) => {
        const kept = q.options.map((o, j) => [o.trim(), j]).filter(([o]) => o);
        return { skill: q.skill, level: q.level, text: q.text.trim(), options: kept.map(([o]) => o), answer: kept.findIndex(([, j]) => j === q.answer) };
    });
    const skills = SKILL_ORDER().filter((id) => clean.some((q) => q.skill === id));
    await busy(button, async () => {
        const ref = draft.id ? doc(db, 'tests', draft.id) : doc(collection(db, 'tests'));
        const batch = writeBatch(db);
        batch.set(ref, {
            teacherUid: teacher.uid, title: draft.title.trim(), className: draft.className, grade: draft.grade, subject: draft.subject,
            passage: draft.passage.trim(), questions: clean.map(({ answer, ...q }) => q), skills,
            status: publish ? 'published' : 'draft', createdAt: draft.createdAt ?? serverTimestamp(), updatedAt: serverTimestamp(),
        });
        batch.set(doc(db, 'testKeys', ref.id), { teacherUid: teacher.uid, answers: clean.map((q) => q.answer) });
        await batch.commit();
        draft = null;
        await loadTeacherTests();
        showAlert(publish ? 'تم حفظ الاختبار ونشره. يظهر الآن لطلاب الفصل عند دخولهم.' : 'تم حفظ الاختبار كمسودة.', 'تم الحفظ');
    });
}

// ---------- نماذج نافس الرسمية ----------

async function showOfficial() {
    const { FORMS } = await import('./forms-data.js'); // يُحمَّل عند المعلم فقط
    const grade = currentGrade();
    const list = $('officialList');
    list.replaceChildren();
    for (const [kind, title] of [['official', 'نماذج التهيئة — نافس 2026'], ['training', 'نماذج تدريبية']]) {
        const forms = FORMS.filter((f) => f.grade === grade && f.kind === kind);
        if (!forms.length) continue;
        const section = el('div', 'space-y-3');
        section.append(el('h4', 'text-xs font-black text-amber-800 bg-amber-50 rounded-lg px-3 py-2', title));
        const grid = el('div', 'grid grid-cols-1 md:grid-cols-2 gap-4');
        for (const form of forms) {
            const card = el('div', 'border border-slate-200 rounded-2xl p-4 space-y-3');
            card.append(el('h4', 'font-bold text-slate-800 text-sm', form.name));
            for (const subject of mySubjects(grade)) {
                const qs = form.subjects[subject];
                if (!qs) continue;
                const source = `${form.id}-${subject}`;
                const added = classTests().some((t) => t.source === source);
                const row = el('div', 'flex items-center justify-between gap-3 text-xs');
                row.append(el('span', 'font-semibold text-slate-700', `${SUBJECTS[subject].name} — ${qs.length} سؤالاً`));
                if (added) row.append(el('span', 'text-emerald-700 font-bold', '✓ مضاف إلى اختبارات الفصل'));
                else row.append(actionButton('إضافة كمسودة', 'add-official', source, 'bg-slate-800 hover:bg-slate-900 text-white font-bold px-3 py-1.5 rounded-lg'));
                card.append(row);
            }
            grid.append(card);
        }
        section.append(grid);
        list.append(section);
    }
    // الاختبارات المحاكية، ثم نماذج حلّها الموقع (مفاتيحها غير رسمية)
    for (const [file, prefix, title] of [['mocks', 'mock', 'الاختبارات المحاكية (مفتاحها مظلَّل في ملف المصدر، من جهة غير الهيئة)'], ['solved', 'sol', 'نماذج تدريبية بمفتاح الموقع — راجع المفتاح قبل النشر']]) {
        let forms = [];
        try { const r = await fetch(`/bank-official/${file}.json`); forms = r.ok ? (await r.json()).filter((m) => m.grade === grade) : []; } catch { forms = []; }
        if (!forms.length) continue;
        const section = el('div', 'space-y-3');
        section.append(el('h4', `text-xs font-black rounded-lg px-3 py-2 ${prefix === 'sol' ? 'text-rose-800 bg-rose-50' : 'text-amber-800 bg-amber-50'}`, title));
        const grid = el('div', 'grid grid-cols-1 md:grid-cols-2 gap-4');
        for (const m of forms) {
            const card = el('div', 'border border-slate-200 rounded-2xl p-4 space-y-3');
            card.append(el('h4', 'font-bold text-slate-800 text-sm', m.name));
            for (const subject of mySubjects(grade)) {
                const qs = m.subjects[subject];
                if (!qs) continue;
                const source = `${prefix}-${m.id}-${subject}`;
                const row = el('div', 'flex items-center justify-between gap-3 text-xs');
                row.append(el('span', 'font-semibold text-slate-700', `${SUBJECTS[subject].name} — ${qs.length} سؤالاً`));
                if (classTests().some((t) => t.source === source)) row.append(el('span', 'text-emerald-700 font-bold', '✓ مضاف إلى اختبارات الفصل'));
                else row.append(actionButton('إضافة كمسودة', 'add-official', source, 'bg-slate-800 hover:bg-slate-900 text-white font-bold px-3 py-1.5 rounded-lg'));
                card.append(row);
            }
            grid.append(card);
        }
        section.append(grid);
        list.append(section);
    }
    $('bankPanel').classList.add('hidden');
    $('officialPanel').classList.remove('hidden');
}

async function addMock(source, button) {
    const [prefix, id, subject] = source.split('-');
    let mocks = [];
    try { mocks = await (await fetch(`/bank-official/${prefix === 'sol' ? 'solved' : 'mocks'}.json`)).json(); } catch { return showAlert('تعذر تحميل النموذج.', 'خطأ'); }
    const m = mocks.find((x) => x.id === id);
    const qs = m?.subjects[subject];
    if (!qs) return;
    await busy(button, async () => {
        const ref = doc(collection(db, 'tests'));
        const batch = writeBatch(db);
        batch.set(ref, {
            teacherUid: teacher.uid, title: prefix === 'sol' ? `${m.name} (مفتاح الموقع)` : `${m.name} — ${SUBJECTS[subject].name}`, className: teacher.className, grade: m.grade, subject,
            source, passage: '',
            questions: qs.map((q) => ({
                skill: q.skill, level: q.level, text: '', options: ['أ', 'ب', 'ج', 'د'], image: `bank-official/${q.img}`, iw: q.w, ih: q.h,
                ...(q.passage ? { passageImage: `bank-official/${q.passage}`, pw: q.pw, ph: q.ph } : {}),
            })),
            skills: skillIdsFor(subject, m.grade).filter((sid) => qs.some((q) => q.skill === sid)),
            status: 'draft', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
        });
        batch.set(doc(db, 'testKeys', ref.id), { teacherUid: teacher.uid, answers: qs.map((q) => q.answer) });
        await batch.commit();
        await loadTeacherTests();
        await showOfficial();
        showAlert(prefix === 'sol' ? 'أُضيف النموذج كمسودة. مفتاحه من حلّ الموقع فراجعه قبل أن تنشره لطلابك.' : 'أُضيف الاختبار المحاكي إلى اختبارات فصلك كمسودة. اضغط «نشر للطلاب» عندما تريد أن يحلّه طلابك.', 'تمت الإضافة');
    });
}

async function addOfficial(source, button) {
    const [formId, subject] = source.split('-');
    const { FORMS } = await import('./forms-data.js');
    const form = FORMS.find((f) => f.id === formId);
    const qs = form?.subjects[subject];
    if (!qs) return;
    await busy(button, async () => {
        const ref = doc(collection(db, 'tests'));
        const batch = writeBatch(db);
        batch.set(ref, {
            teacherUid: teacher.uid, title: form.kind === 'training' ? form.name : `${form.name} — ${SUBJECTS[subject].name}`, className: teacher.className, grade: form.grade, subject,
            source, passage: '',
            questions: qs.map((q) => ({
                skill: q.skill, level: q.level, text: '', options: ['أ', 'ب', 'ج', 'د'], image: q.img, iw: q.w, ih: q.h,
                ...(q.passage ? { passageImage: q.passage.img, pw: q.passage.w, ph: q.passage.h } : {}),
            })),
            skills: skillIdsFor(subject, form.grade).filter((id) => qs.some((q) => q.skill === id)),
            status: 'draft', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
        });
        batch.set(doc(db, 'testKeys', ref.id), { teacherUid: teacher.uid, answers: qs.map((q) => q.answer) });
        await batch.commit();
        await loadTeacherTests();
        await showOfficial();
        showAlert('أُضيف النموذج إلى اختبارات فصلك كمسودة. اضغط «نشر للطلاب» عندما تريد أن يحلّه طلابك.', 'تمت الإضافة');
    });
}

// ---------- اختبار من بنك نافس للأسئلة (صور + مفاتيح) ----------

const bpState = { subject: null, levels: new Set(['know', 'apply', 'reason']), skills: new Set(), data: {} };

async function loadBankOfficial(subject, grade) {
    const key = `${subject}${grade}`;
    if (!(key in bpState.data)) {
        try { const r = await fetch(`/bank-official/${key}.json`); bpState.data[key] = r.ok ? await r.json() : []; } catch { bpState.data[key] = []; }
    }
    return bpState.data[key];
}

async function showBankPanel() {
    const grade = currentGrade();
    const subjects = mySubjects(grade);
    if (!subjects.includes(bpState.subject)) bpState.subject = subjects[0];
    bpState.skills.clear();
    $('officialPanel').classList.add('hidden');
    $('bankPanel').classList.remove('hidden');
    await renderBankPanel();
}

async function renderBankPanel() {
    const grade = currentGrade();
    const subj = $('bpSubject');
    subj.replaceChildren();
    for (const s of mySubjects(grade)) {
        const b = actionButton(SUBJECTS[s].name, 'bp-subject', s, `px-3 py-1.5 rounded-lg text-xs font-bold border ${s === bpState.subject ? 'bg-teal-600 text-white border-teal-600' : 'bg-white text-slate-600 border-slate-200'}`);
        subj.append(b);
    }
    const lv = $('bpLevels');
    lv.replaceChildren(el('span', 'font-bold text-slate-600', 'المستويات:'));
    for (const l of LEVELS) {
        const lab = el('label', 'flex items-center gap-1');
        const cb = el('input', 'accent-teal-600'); cb.type = 'checkbox'; cb.dataset.bpLevel = l.id; cb.checked = bpState.levels.has(l.id);
        lab.append(cb, el('span', '', l.name));
        lv.append(lab);
    }
    const items = await loadBankOfficial(bpState.subject, grade);
    const box = $('bpSkills');
    box.replaceChildren();
    if (!items.length) box.append(el('p', 'text-xs text-slate-400 text-center py-6', 'لا أسئلة جاهزة لهذه المادة والصف بعد.'));
    for (const o of outcomesFor(bpState.subject, grade)) {
        const rows = o.skills.map((sk) => ({ sk, n: items.filter((q) => q.skill === sk.id && bpState.levels.has(q.level)).length })).filter((r) => r.n);
        if (!rows.length) continue;
        const sec = el('div', 'border border-slate-200 rounded-2xl p-3 space-y-1');
        sec.append(el('p', 'text-xs font-black text-slate-700', o.name));
        for (const { sk, n } of rows) {
            const lab = el('label', 'flex items-start gap-2 text-xs text-slate-700 cursor-pointer');
            const cb = el('input', 'mt-0.5 accent-teal-600'); cb.type = 'checkbox'; cb.dataset.bpSkill = sk.id; cb.checked = bpState.skills.has(sk.id);
            lab.append(cb, el('span', 'flex-1', sk.name), el('span', 'text-slate-400 shrink-0', `${n} سؤالاً`));
            sec.append(lab);
        }
        box.append(sec);
    }
    updateBankCount(items);
}

function bankSelection(items) {
    const order = skillIdsFor(bpState.subject, currentGrade());
    const LV = ['know', 'apply', 'reason'];
    return items.filter((q) => bpState.skills.has(q.skill) && bpState.levels.has(q.level))
        .sort((a, b) => (a.passage ?? '').localeCompare(b.passage ?? '') || order.indexOf(a.skill) - order.indexOf(b.skill) || LV.indexOf(a.level) - LV.indexOf(b.level));
}

function updateBankCount(items) {
    $('bpCount').textContent = bankSelection(items ?? bpState.data[`${bpState.subject}${currentGrade()}`] ?? []).length;
}

async function createBankTest(button) {
    const grade = currentGrade();
    const items = bankSelection(await loadBankOfficial(bpState.subject, grade));
    if (!items.length) return showAlert('اختر مؤشراً واحداً على الأقل.', 'لا تحديد');
    if (items.length > 60) return showAlert('الحد الأقصى 60 سؤالاً للاختبار. قلّل المؤشرات أو المستويات.', 'عدد كبير');
    await busy(button, async () => {
        const ref = doc(collection(db, 'tests'));
        const batch = writeBatch(db);
        const skills = skillIdsFor(bpState.subject, grade).filter((id) => items.some((q) => q.skill === id));
        batch.set(ref, {
            teacherUid: teacher.uid, title: `بنك نافس — ${SUBJECTS[bpState.subject].name} (${skills.length} مؤشراً)`, className: teacher.className, grade, subject: bpState.subject,
            source: 'nafs-bank', passage: '',
            questions: items.map((q, i) => ({
                skill: q.skill, level: q.level, text: '', options: ['أ', 'ب', 'ج', 'د'], image: `bank-official/${q.img}`, iw: q.w, ih: q.h,
                // يظهر النص مرة واحدة قبل أول سؤال من كل نص
                ...(q.passage && q.passage !== items[i - 1]?.passage ? { passageImage: `bank-official/${q.passage}`, pw: q.pw, ph: q.ph } : {}),
            })),
            skills, status: 'draft', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
        });
        batch.set(doc(db, 'testKeys', ref.id), { teacherUid: teacher.uid, answers: items.map((q) => q.answer) });
        await batch.commit();
        await loadTeacherTests();
        $('bankPanel').classList.add('hidden');
        showAlert(`أُنشئ اختبار من ${items.length} سؤالاً كمسودة. اضغط «نشر للطلاب» عندما تريد أن يحلّه طلابك.`, 'تم الإنشاء');
    });
}

async function togglePublish(id) {
    const t = tests.find((x) => x.id === id);
    try {
        await updateDoc(doc(db, 'tests', id), { status: t.status === 'published' ? 'draft' : 'published', updatedAt: serverTimestamp() });
        await loadTeacherTests();
    } catch (err) { reportError(err); }
}

async function deleteTest(id) {
    const t = tests.find((x) => x.id === id);
    const n = attempts.filter((a) => a.testId === id).length;
    if (!t || !(await confirmDialog(`حذف اختبار «${t.title}»${n ? ` وإجابات ${n} طالباً عليه` : ''} نهائياً؟`))) return;
    try {
        await deleteInBatches([doc(db, 'tests', id), doc(db, 'testKeys', id), ...attempts.filter((a) => a.testId === id).map((a) => doc(db, 'attempts', a.id))]);
        await loadTeacherTests();
    } catch (err) { reportError(err); }
}

async function deleteInBatches(refs) {
    for (let i = 0; i < refs.length; i += 400) {
        const batch = writeBatch(db);
        refs.slice(i, i + 400).forEach((r) => batch.delete(r));
        await batch.commit();
    }
}

// كلمة مرور سهلة: 6 أرقام عشوائية آمنة، تُولَّد بعد إضافة الطالب وتُطبع في بطاقته
function newPin() { return String(crypto.getRandomValues(new Uint32Array(1))[0] % 1000000).padStart(6, '0'); }
const pinDoc = () => ({ teacherUid: teacher.uid, pin: newPin(), createdAt: serverTimestamp() });

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
        const b = writeBatch(db);
        b.set(doc(db, 'students', id), newStudentDoc(name));
        b.set(doc(db, 'studentPins', id), pinDoc());
        await b.commit();
        $('newStudentName').value = '';
        $('newStudentId').value = '';
        await loadStudents();
        showAlert('تم إضافة الطالب بنجاح!', 'نجاح');
    });
}

async function genPins() {
    const miss = students.filter((s) => !pins[s.id]);
    if (!miss.length) return showAlert('لكل طلابك كلمات مرور.', 'تنبيه');
    try {
        for (let i = 0; i < miss.length; i += 400) {
            const b = writeBatch(db);
            miss.slice(i, i + 400).forEach((s) => b.set(doc(db, 'studentPins', s.id), pinDoc()));
            await b.commit();
        }
        await loadStudents();
        showAlert(`وُلّدت كلمات مرور لـ ${miss.length} طالباً. اطبع البطاقات ووزعها.`, 'تم');
    } catch (err) { reportError(err); }
}

function printCards() {
    const list = classStudents().filter((s) => pins[s.id]);
    if (!list.length) return showAlert('ولّد كلمات المرور أولاً.', 'تنبيه');
    const cards = list.map((s) => `<div class="c"><b>${esc(s.name)}</b><p>السجل المدني: <span>${esc(s.id)}</span></p><p>كلمة المرور: <span>${esc(pins[s.id])}</span></p></div>`).join('');
    const html = `<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>بطاقات دخول الطلاب</title><style>body{font-family:Tahoma,sans-serif;margin:10mm}h1{font-size:14pt}.g{display:grid;grid-template-columns:1fr 1fr;gap:6mm}.c{border:1.5px dashed #555;border-radius:3mm;padding:4mm;break-inside:avoid;font-size:11pt}.c p{margin:2mm 0}.c span{font-family:monospace;font-size:13pt;font-weight:bold;letter-spacing:1px}</style><h1>بطاقات دخول الطلاب — ${esc(teacher.className)}</h1><div class="g">${cards}</div><script>addEventListener("load",()=>setTimeout(()=>print(),600))</script></html>`;
    const url = URL.createObjectURL(new Blob([html], { type: 'text/html;charset=utf-8' }));
    if (!window.open(url, '_blank')) showAlert('اسمح للموقع بفتح النوافذ المنبثقة ثم أعد المحاولة.', 'تعذّر فتح الطباعة');
}

// بيان مطبوع للمعلم: الاسم والسجل المدني وكلمة المرور في جدول واحد
function printRoster() {
    const list = classStudents();
    if (!list.length) return showAlert('لا يوجد طلاب في فصلك بعد.', 'تنبيه');
    const rows = list.map((s, i) => `<tr><td>${i + 1}</td><td>${esc(s.name)}</td><td>${esc(s.id)}</td><td>${esc(pins[s.id] ?? '—')}</td></tr>`).join('');
    const html = `<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>بيان الطلاب</title><style>body{font-family:Tahoma,sans-serif;margin:12mm}h1{font-size:14pt}table{width:100%;border-collapse:collapse;font-size:11pt}th,td{border:1px solid #888;padding:2mm 3mm;text-align:right}th{background:#eee}td:nth-child(3),td:nth-child(4){font-family:monospace;font-weight:bold}</style><h1>بيان الطلاب وكلمات المرور — ${esc(teacher.className)} (${list.length})</h1><p>سري: للمعلم فقط.</p><table><tr><th>م</th><th>اسم الطالب</th><th>السجل المدني</th><th>كلمة المرور</th></tr>${rows}</table><script>addEventListener("load",()=>setTimeout(()=>print(),600))</script></html>`;
    const url = URL.createObjectURL(new Blob([html], { type: 'text/html;charset=utf-8' }));
    if (!window.open(url, '_blank')) showAlert('اسمح للموقع بفتح النوافذ المنبثقة ثم أعد المحاولة.', 'تعذّر فتح الطباعة');
}

async function deleteStudent(id) {
    const s = students.find((x) => x.id === id);
    if (!s || !(await confirmDialog(`حذف الطالب «${s.name}» ونتائجه نهائياً؟`))) return;
    try {
        await deleteInBatches([doc(db, 'students', id), doc(db, 'studentPins', id), ...attempts.filter((a) => a.studentId === id).map((a) => doc(db, 'attempts', a.id))]);
        await Promise.all([loadStudents(), loadTeacherTests()]);
    } catch (err) { reportError(err); }
}

async function clearAllStudents() {
    const list = classStudents();
    if (!list.length) return;
    if (!(await confirmDialog(`حذف جميع طلاب فصل «${teacher.className}» (${list.length}) ونتائجهم نهائياً؟`))) return;
    try {
        const ids = new Set(list.map((s) => s.id));
        await deleteInBatches([...list.map((s) => doc(db, 'students', s.id)), ...list.map((s) => doc(db, 'studentPins', s.id)), ...attempts.filter((a) => ids.has(a.studentId)).map((a) => doc(db, 'attempts', a.id))]);
        await Promise.all([loadStudents(), loadTeacherTests()]);
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
        for (let i = 0; i < toAdd.length; i += 200) {
            const batch = writeBatch(db);
            toAdd.slice(i, i + 200).forEach((s) => { batch.set(doc(db, 'students', s.id), newStudentDoc(s.name)); batch.set(doc(db, 'studentPins', s.id), pinDoc()); });
            await batch.commit();
            added += Math.min(200, toAdd.length - i);
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

// ---------- الطالب ----------

async function studentLogin(e) {
    e.preventDefault();
    const id = $('sIdInput').value.trim();
    const pin = $('sPinInput').value.trim();
    if (!isCivilId(id)) return showAlert('رقم السجل المدني يجب أن يكون 10 أرقام.', 'تنبيه');
    if (!/^\d{6}$/.test(pin)) return showAlert('كلمة المرور 6 أرقام يعطيك إياها معلمك.', 'تنبيه');
    await busy(e.submitter, async () => {
        activeStudent = { id };
        if (!auth.currentUser) await signInAnonymously(auth);
        try { await setDoc(doc(db, 'studentSessions', auth.currentUser.uid), { studentId: id, pin }); } catch (err) {
            activeStudent = null;
            if (err?.code === 'permission-denied') return showAlert('رقم السجل المدني أو كلمة المرور غير صحيحة. اطلب من معلمك بطاقة الدخول.', 'تنبيه دخول');
            throw err;
        }
        $('sPinInput').value = '';
        const snap = await getDoc(doc(db, 'students', id));
        if (!snap.exists()) {
            activeStudent = null;
            return showAlert('عذراً، رقم السجل المدني غير مسجل في النظام. تأكد من المعلم.', 'تنبيه دخول');
        }
        activeStudent = { id, ...snap.data() };
        $('sIdInput').value = '';
        showScreen('studentDashboardScreen');
        $('studentFullNameDisplay').textContent = `أهلاً بك، ${activeStudent.name}`;
        $('studentClassDisplay').textContent = `رقم السجل المدني: ${id} | ${activeStudent.className}`;
        await loadStudentTests();
    });
}

async function loadStudentTests() {
    const snap = await getDocs(query(collection(db, 'tests'),
        where('teacherUid', '==', activeStudent.teacherUid), where('className', '==', activeStudent.className), where('status', '==', 'published')));
    studentTests = snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((x, y) => ms(y.createdAt) - ms(x.createdAt));
    const done = await Promise.all(studentTests.map((t) => getDoc(doc(db, 'attempts', `${t.id}_${activeStudent.id}`)).then((x) => x.exists())));
    studentTests.forEach((t, i) => { t.done = done[i]; });
    renderStudentTests();
}

function renderStudentTests() {
    openTest = null;
    $('studentTestsView').classList.remove('hidden');
    $('studentTestView').classList.add('hidden');
    const box = $('studentTestsList');
    box.replaceChildren();
    if (!studentTests.length) box.append(el('p', 'text-sm text-slate-400 text-center py-8', 'لا توجد اختبارات منشورة لفصلك حالياً.'));
    for (const t of studentTests) {
        const row = el('div', 'flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 rounded-2xl border ' + (t.done ? 'border-slate-200 bg-slate-50' : 'border-teal-200 bg-teal-50/40'));
        const info = el('div');
        info.append(el('p', 'font-bold text-slate-800', t.title), el('p', 'text-xs text-slate-500 mt-1', `${SUBJECTS[testSubject(t)].name} · ${t.questions.length} سؤالاً`));
        row.append(info, t.done ? el('span', 'text-xs font-bold text-emerald-700', '✓ تم الإرسال')
            : actionButton('ابدأ الاختبار ➔', 'open-test', t.id, 'bg-teal-600 hover:bg-teal-700 text-white font-bold px-5 py-2.5 rounded-xl text-xs'));
        box.append(row);
    }
}

const PANEL_W = 708; // عرض صفحة النموذج الرسمي بالبكسل عند 100 نقطة/بوصة

// صورة من نموذج رسمي بمقياس موحّد؛ في الشاشات الضيقة يُمرَّر أفقياً بدل أن يصغر الخط، مع تنبيه.
function formImage(src, w, h, alt) {
    const box = el('div', 'space-y-1');
    const wrap = el('div', 'overflow-x-auto rounded-xl border border-slate-200 bg-white');
    const img = el('img', 'block max-w-none');
    img.src = src; img.alt = alt; img.width = w; img.height = h; img.loading = 'lazy';
    img.style.width = Math.min(100, (w / PANEL_W) * 100) + '%';
    img.style.minWidth = Math.round(w * 0.82) + 'px';
    wrap.append(img);
    const hint = el('p', 'hidden text-[11px] text-amber-700', 'الصورة أوسع من الشاشة: اسحبها يميناً ويساراً لقراءة بقية السؤال، أو أدِر الجهاز أفقياً.');
    const update = () => hint.classList.toggle('hidden', wrap.scrollWidth <= wrap.clientWidth + 2);
    img.addEventListener('load', update);
    new ResizeObserver(update).observe(wrap);
    box.append(wrap, hint);
    return box;
}

function openStudentTest(id) {
    openTest = studentTests.find((t) => t.id === id);
    if (!openTest || openTest.done) return;
    $('studentTestsView').classList.add('hidden');
    $('studentTestView').classList.remove('hidden');
    $('stTitle').textContent = openTest.title;
    $('stPassage').textContent = openTest.passage;
    $('stPassage').classList.toggle('hidden', !openTest.passage);
    const box = $('stQuestions');
    box.replaceChildren();
    openTest.questions.forEach((q, i) => {
        if (q.passageImage) {
            const p = el('div', 'space-y-2');
            p.append(el('p', 'text-xs font-bold text-slate-600', 'اقرأ النص التالي ثم أجب عن الأسئلة التي بعده:'), formImage(q.passageImage, q.pw, q.ph, 'نص القراءة'));
            box.append(p);
        }
        const card = el('div', 'p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-3');
        if (q.image) card.append(formImage(q.image, q.iw, q.ih, `السؤال ${i + 1}`));
        else card.append(el('p', 'text-sm font-bold text-slate-800', `${i + 1}. ${q.text}`));
        const opts = el('div', q.image ? 'grid grid-cols-4 gap-2 text-sm' : 'grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm');
        q.options.forEach((o, j) => {
            const label = el('label', 'p-3 bg-white rounded-xl border border-slate-200 flex items-center justify-center sm:justify-start gap-2 cursor-pointer hover:border-teal-500 has-[:checked]:border-teal-600 has-[:checked]:bg-teal-50');
            const r = el('input', 'accent-teal-600');
            r.type = 'radio'; r.name = `sq-${i}`; r.value = j;
            label.append(r, document.createTextNode(o));
            opts.append(label);
        });
        card.append(opts);
        box.append(card);
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

async function submitTest(e) {
    const answers = openTest.questions.map((_, i) => {
        const r = document.querySelector(`input[name="sq-${i}"]:checked`);
        return r ? Number(r.value) : null;
    });
    const missing = answers.indexOf(null);
    if (missing !== -1) return showAlert(`أجب عن السؤال ${missing + 1} قبل الإرسال.`, 'تنبيه');
    if (!(await confirmDialog('إرسال إجاباتك؟ لا يمكن تعديلها بعد الإرسال.', 'نعم، أرسل'))) return;
    await busy(e.target, async () => {
        try {
            await setDoc(doc(db, 'attempts', `${openTest.id}_${activeStudent.id}`), {
                testId: openTest.id, studentId: activeStudent.id, teacherUid: activeStudent.teacherUid,
                className: activeStudent.className, answers, submittedAt: serverTimestamp(),
            });
        } catch (err) {
            if (err?.code === 'permission-denied') return showAlert('سبق أن أرسلت هذا الاختبار، أو أوقف المعلم نشره.', 'تنبيه');
            throw err;
        }
        openTest.done = true;
        renderStudentTests();
        showAlert('أحسنت! تم إرسال إجاباتك، وسيطّلع معلمك على نتيجتك ومستواك في كل مهارة.', 'تم الإرسال');
    });
}

async function studentLogout(message = 'تم تسجيل خروج الطالب.', title = 'إشعار') {
    activeStudent = null;
    studentTests = [];
    if (auth.currentUser?.isAnonymous) await signOut(auth);
    showScreen(teacher ? 'teacherDashboardScreen' : 'roleSelectionScreen');
    showAlert(message, title);
}

// ---------- مدير المدرسة ----------

const isSchoolNo = (v) => /^[0-9]{3,12}$/.test(v);
function setPrincipalTab(tab) {
    $('principalLoginForm').classList.toggle('hidden', tab !== 'login');
    $('principalSignupForm').classList.toggle('hidden', tab !== 'signup');
    $('pTabLogin').className = tab === 'login' ? 'flex-1 py-2 rounded-lg bg-white shadow text-indigo-700' : 'flex-1 py-2 rounded-lg text-slate-500';
    $('pTabSignup').className = tab === 'signup' ? 'flex-1 py-2 rounded-lg bg-white shadow text-indigo-700' : 'flex-1 py-2 rounded-lg text-slate-500';
}

async function principalLogin(e) {
    e.preventDefault();
    await busy(e.submitter, async () => {
        await signInWithEmailAndPassword(auth, $('pLoginEmail').value.trim(), $('pLoginPassword').value);
        $('pLoginPassword').value = '';
    });
}

async function principalReset() {
    const email = $('pLoginEmail').value.trim();
    if (!email) return showAlert('اكتب بريدك الإلكتروني أولاً ثم اضغط «نسيت كلمة المرور».', 'تنبيه');
    try { await sendPasswordResetEmail(auth, email); showAlert('أرسلنا رابط تغيير كلمة المرور إلى بريدك (إن كان مسجلاً).', 'تم الإرسال'); } catch (err) { reportError(err); }
}

// يسجّل المدير نفسه بحرّية (بلا اعتماد) ويُنشئ مدرسته برقمها الإحصائي، إلا إن كان الرقم مسجلاً لمدير آخر.
async function principalSignup(e) {
    e.preventDefault();
    const p = { name: $('pName').value.trim(), civilId: $('pCivil').value.trim(), email: $('pSignupEmail').value.trim(), schoolNo: $('pSchoolNo').value.trim() };
    const schoolName = $('pSchool').value.trim();
    if (!isCivilId(p.civilId)) return showAlert('السجل المدني يجب أن يكون مكوناً من 10 أرقام.', 'تنبيه خطأ');
    if (!isSchoolNo(p.schoolNo)) return showAlert('الرقم الإحصائي أرقام فقط (من 3 إلى 12 رقماً) دون حروف.', 'تنبيه خطأ');
    await busy(e.submitter, async () => {
        activating = true;
        let user;
        try {
            user = (await createUserWithEmailAndPassword(auth, p.email, $('pSignupPassword').value)).user;
            const batch = writeBatch(db);
            batch.set(doc(db, 'principals', user.uid), { ...p, createdAt: serverTimestamp() });
            const existing = await getDoc(doc(db, 'schools', p.schoolNo));
            if (!existing.exists()) {
                batch.set(doc(db, 'schools', p.schoolNo), { no: p.schoolNo, name: schoolName, principalUid: user.uid, principalName: p.name, classes: [], year: academicYear(), years: [{ label: academicYear(), start: Date.now() }], createdAt: serverTimestamp() });
            }
            await batch.commit();
            // مدرسة بلا مدير (بعد بداية عام جديد): يتسلّمها أول مدير مسجّل برقمها
            const vacant = existing.exists() && existing.data().principalUid == null;
            if (vacant) await updateDoc(doc(db, 'schools', p.schoolNo), { principalUid: user.uid, principalName: p.name });
            $('pSignupPassword').value = '';
            principal = { uid: user.uid, ...p };
            activating = false;
            await openPrincipalDashboard(true);
            showAlert(vacant ? `تسلّمتَ مدرسة «${existing.data().name}» بفصولها واختباراتها ونتائجها المؤرشفة.` : existing.exists() ? `رقم المدرسة ${p.schoolNo} مسجّل لمدير آخر (${existing.data().principalName}). سُجّل حسابك، ويمكنك من لوحتك طلب نقل تبعية المدرسة إليك.` : 'تم تسجيل مدرستك. أضف الفصول ثم المعلمين.', 'تم التسجيل');
        } catch (err) {
            if (user) { await user.delete().catch(() => {}); await signOut(auth).catch(() => {}); }
            throw err;
        } finally { setTimeout(() => { activating = false; }, 600); }
    });
}

let pdEditing = null; // سجل المعلم الذي يعدّله المدير من بطاقته (يستبدل إسناده)؛ غيره: إضافة فصول إلى إسناده السابق
let pdEditClasses = false; // تعديل الفصول بعد حفظها (يُفتح بزر «تعديل» من قسم المعلمين)
let pdOpen; // القسم المفتوح في لوحة المدير (undefined = أول عرض، null = الكل مغلق)
async function openPrincipalDashboard(fresh = false) {
    if (fresh) { pdOpen = undefined; pdEditClasses = false; }
    school = null; roster = []; transferIn = null; otherSchool = null; transferOut = null;
    const sc = await getDoc(doc(db, 'schools', principal.schoolNo));
    const tr = await getDoc(doc(db, 'schoolTransfers', principal.schoolNo)).catch(() => null);
    if (sc.exists() && sc.data().principalUid === principal.uid) {
        school = { id: sc.id, ...sc.data() };
        if (tr?.exists()) transferIn = tr.data();
        const r = await getDocs(query(collection(db, 'teacherRoster'), where('schoolNo', '==', school.no)));
        roster = r.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.name.localeCompare(b.name, 'ar'));
    } else {
        otherSchool = sc.exists() ? sc.data() : null;
        if (tr?.exists() && tr.data().requesterUid === principal.uid) transferOut = tr.data();
    }
    showScreen('principalDashboardScreen');
    renderPrincipal();
}

function renderPrincipal() {
    const body = $('pdBody');
    body.replaceChildren();
    $('pdTitle').textContent = `مرحباً بك أستاذ/ة: ${principal.name}`;
    if (!school) {
        $('pdMeta').textContent = `الرقم الإحصائي: ${principal.schoolNo}`;
        const box = el('div', 'bg-amber-50 border-2 border-amber-300 rounded-3xl p-6 space-y-3');
        box.append(el('p', 'text-sm font-bold text-amber-900 leading-relaxed', otherSchool
            ? `المدرسة «${otherSchool.name}» (الرقم ${principal.schoolNo}) تتبع حالياً المدير: ${otherSchool.principalName}. لا تظهر لك بياناتها حتى تُنقل إليك.`
            : 'لا توجد مدرسة مسجّلة بهذا الرقم.'));
        const row = el('div', 'flex flex-wrap gap-3 text-xs font-bold');
        if (otherSchool && transferOut) {
            box.append(el('p', 'text-sm text-slate-700', `أُرسل تنبيه إلى ${otherSchool.principalName} ليحذف المدرسة من عنده. بعد موافقته اضغط «تحقق من التبعية».`));
            row.append(actionButton('إلغاء الطلب', 'pd-cancel-transfer', '', 'text-red-600 hover:text-red-800'));
        } else if (otherSchool) {
            row.append(actionButton(`إرسال تنبيه إلى ${otherSchool.principalName} بحذف المدرسة من عنده`, 'pd-request-transfer', '', 'bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl'));
        }
        row.append(actionButton('تحقق من التبعية', 'pd-refresh', '', 'text-indigo-700 hover:text-indigo-900'));
        box.append(row);
        body.append(box);
        return;
    }
    if (transferIn) {
        const box = el('div', 'bg-amber-50 border-2 border-amber-300 rounded-3xl p-5 space-y-3');
        box.append(el('p', 'text-sm font-bold text-amber-900 leading-relaxed', `تنبيه: المدير ${transferIn.requesterName} سجّل برقم مدرستك ويطلب أن تُنقل تبعيتها إليه. إن كنتَ انتقلتَ من المدرسة فاحذفها من عندك لتُضاف له بمعلميها وفصولها، وإن لم تكن ذلك فارفض الطلب.`));
        const row = el('div', 'flex flex-wrap gap-3 text-xs font-bold');
        row.append(actionButton('حذف المدرسة من عندي', 'pd-approve-transfer', '', 'bg-red-600 hover:bg-red-700 text-white px-5 py-2.5 rounded-xl'), actionButton('رفض الطلب', 'pd-reject-transfer', '', 'text-slate-700 hover:text-slate-900'));
        box.append(row);
        body.append(box);
    }
    $('pdMeta').textContent = `${school.name} · الرقم الإحصائي: ${school.no} · العام الدراسي: ${school.year}`;

    // مراحل لوحة المدير: ١) اختيار الفصول ← ٢) إسناد المعلمين لفصولهم وتخصصاتهم ← ٣) التقارير.
    // ما انتهى منه يختفي إلى قائمة منسدلة، وتبقى الواجهة لما يلي.
    // الإسناد يكتمل حين يكون لكل فصل معلم لكل مادة من مواد صفه (الثالث: لغتي ورياضيات، والسادس والمتوسط: الثلاث)
    const ALL_SUBJ = ['reading', 'math', 'science'];
    const holders = (c, sub) => roster.filter((r) => r.classes.includes(c) && (r.subjects ?? ALL_SUBJ).includes(sub));
    const needed = school.classes.flatMap((c) => subjectsOfGrade(gradeOfClass(c)).map((sub) => [c, sub]));
    const uncovered = needed.filter(([c, sub]) => !holders(c, sub).length);
    const stage = !school.classes.length ? 'classes' : uncovered.length || !roster.length ? 'assign' : 'reports';
    // كل قسم قائمة منسدلة، يُفتح واحد في كل مرة: افتح ← حدّد ← احفظ فيُطوى
    const nextStep = stage === 'classes' ? 'classes' : stage === 'assign' ? 'teachers' : null;
    if (pdOpen === undefined) pdOpen = nextStep ?? 'reports';
    const sections = {};
    const fold = (key, title, node) => {
        const d = el('details', 'bg-white rounded-3xl shadow-sm border border-slate-100'); d.dataset.pdSection = key;
        d.open = pdOpen === key;
        const sm = el('summary', 'cursor-pointer select-none px-6 py-4 font-bold text-slate-800 text-sm flex items-center justify-between gap-3');
        sm.append(el('span', '', title), key === nextStep ? el('span', 'text-xs font-bold bg-amber-100 text-amber-800 rounded-full px-3 py-1', 'الخطوة التالية') : el('span', 'text-slate-400 text-xs', '▾'));
        d.append(sm, node);
        d.addEventListener('toggle', () => {
            if (d.open) {
                pdOpen = key;
                for (const [k, o] of Object.entries(sections)) if (k !== key && o.open) o.open = false;
                if (key === 'reports' && !d.dataset.loaded) { d.dataset.loaded = '1'; loadPrincipalReport(repBody); }
            } else if (pdOpen === key) pdOpen = null;
        });
        sections[key] = d;
        return d;
    };
    const panel = (cls = 'p-6 space-y-4') => el('div', cls);

    // الفصول
    const classes = panel();
    classes.append(el('h3', 'font-black text-slate-800', 'الصفوف والفصول في مدرستك'), el('p', 'text-xs text-slate-500', 'اختر الفصول المستهدفة باختبارات نافس (الثالث الابتدائي، السادس الابتدائي، الثالث المتوسط).'));
    const grid = el('div', 'grid grid-cols-1 sm:grid-cols-3 gap-2');
    for (const c of CLASSES) {
        const lab = el('label', 'flex items-center gap-2 text-sm bg-slate-50 border border-slate-200 rounded-xl px-3 py-2');
        const cb = el('input', ''); cb.type = 'checkbox'; cb.value = c; cb.checked = school.classes.includes(c); cb.dataset.pdClass = c;
        lab.append(cb, el('span', '', c));
        grid.append(lab);
    }
    classes.append(grid, actionButton('حفظ الفصول', 'pd-save-classes', '', 'bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl'));

    // المعلمون: الإسناد بالفصول والتخصص
    const t = panel();
    t.append(el('h3', 'font-black text-slate-800', 'المعلمون وإسنادهم للفصول والتخصصات'));
    if (school.classes.length) {
        const cl = el('div', 'flex flex-wrap items-center gap-3 text-xs bg-slate-50 rounded-xl p-3 border border-slate-100');
        cl.append(el('span', 'text-slate-600', `الفصول المعتمدة: ${school.classes.join('، ')}`), actionButton('تعديل الفصول', 'pd-edit-classes', '', 'text-indigo-700 hover:text-indigo-900 font-bold'));
        t.append(cl);
        t.append(el('p', `text-sm font-bold ${uncovered.length ? 'text-amber-700' : 'text-emerald-700'}`,
            `أضفتَ ${roster.length} معلماً · أُسند ${needed.length - uncovered.length} من ${needed.length} خانة (فصل × مادة)${uncovered.length ? ' — أكمل الخانات الناقصة أدناه.' : ' — الإسناد مكتمل ✓'}`));
        const m = el('table', 'w-full text-right text-xs border border-slate-100 rounded-xl overflow-hidden');
        const h = el('tr', 'bg-slate-50 text-slate-500');
        ['الفصل', 'لغتي', 'الرياضيات', 'العلوم'].forEach((x) => h.append(el('th', 'p-2', x)));
        m.append(h);
        for (const c of school.classes) {
            const tr = el('tr', 'border-t border-slate-100');
            tr.append(el('td', 'p-2 font-bold text-slate-800', c));
            for (const sub of ALL_SUBJ) {
                if (!subjectsOfGrade(gradeOfClass(c)).includes(sub)) { tr.append(el('td', 'p-2 text-slate-300', '—')); continue; }
                const hs = holders(c, sub);
                tr.append(el('td', `p-2 ${hs.length ? 'text-emerald-800' : 'text-amber-700 font-bold'}`, hs.length ? hs.map((x) => x.name).join('، ') : 'لم يُسند'));
            }
            m.append(tr);
        }
        t.append(m);
    }
    if (school.classes.length) {
        const f = el('form', 'space-y-3 bg-slate-50 rounded-2xl p-4 border border-slate-100'); f.id = 'pdTeacherForm';
        const row = el('div', 'grid grid-cols-1 md:grid-cols-2 gap-3');
        const name = el('input', 'px-3 py-2.5 border border-slate-200 rounded-xl text-sm'); name.id = 'pdTName'; name.placeholder = 'اسم المعلم الثلاثي'; name.required = true; name.maxLength = 100;
        const cid = el('input', 'px-3 py-2.5 border border-slate-200 rounded-xl text-sm'); cid.id = 'pdTCivil'; cid.placeholder = 'السجل المدني (10 أرقام)'; cid.required = true; cid.pattern = '[0-9]{10}'; cid.maxLength = 10; cid.inputMode = 'numeric';
        row.append(name, cid);
        const checks = (items, attr, label) => {
            const box = el('div', 'flex flex-wrap gap-2 text-xs');
            for (const [value, text] of items) {
                const lab = el('label', 'flex items-center gap-1.5 bg-white border border-slate-200 rounded-lg px-2.5 py-1.5');
                const cb = el('input', ''); cb.type = 'checkbox'; cb.value = value; cb.dataset[attr] = value;
                lab.append(cb, el('span', '', text)); box.append(lab);
            }
            return [el('p', 'text-xs font-bold text-slate-600', label), box];
        };
        const add = el('button', 'bg-indigo-600 hover:bg-indigo-700 text-white font-bold px-5 py-2.5 rounded-xl text-xs', 'إضافة المعلم'); add.type = 'submit';
        f.append(row,
            ...checks(school.classes.map((c) => [c, c]), 'pdTClass', 'الفصول المسندة له:'),
            ...checks([['reading', 'لغتي (القراءة)'], ['math', 'الرياضيات'], ['science', 'العلوم']], 'pdTSubject', 'تخصصه (المواد التي يدرّسها):'),
            el('p', 'text-xs text-slate-500', 'إن كان المعلم مضافاً من قبل فتُضاف هذه الفصول إلى فصوله السابقة دون حذف شيء. لتغيير إسناده أو حذف فصل منه استعمل «تعديل الإسناد» في بطاقته.'),
            add);
        f.addEventListener('submit', addRosterTeacher);
        t.append(f);
    }
    const list = el('div', 'space-y-2');
    if (!roster.length) list.append(el('p', 'text-sm text-slate-400', 'لم تُضف معلمين بعد.'));
    for (const r of roster) {
        const card = el('div', 'border border-slate-200 rounded-2xl p-3 text-xs flex flex-wrap items-center gap-3 justify-between');
        const info = el('div', 'space-y-1');
        const subs = (r.subjects ?? []).map((x) => SUBJECTS[x].name).join('، ') || 'كل المواد (لم يُحدَّد تخصصه)';
        info.append(el('p', 'font-bold text-slate-800 text-sm', `${r.name} — ${r.id}`), el('p', 'text-slate-500', `الفصول: ${r.classes.join('، ')}`), el('p', 'text-emerald-700 font-semibold', `التخصص: ${subs}`));
        const btns = el('div', 'flex flex-wrap items-center gap-3 font-bold');
        btns.append(el('span', `px-2.5 py-1 rounded-full ${r.uid ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600'}`, r.uid ? 'مفعّل' : 'لم يُفعّل حسابه'));
        if (r.uid) btns.append(actionButton('إعادة ضبط التفعيل', 'pd-reset-teacher', r.id, 'text-amber-700 hover:text-amber-900'));
        btns.append(actionButton('تعديل الإسناد', 'pd-edit-teacher', r.id, 'text-indigo-700 hover:text-indigo-900'), actionButton('حذف', 'pd-del-teacher', r.id, 'text-red-500 hover:text-red-700'));
        card.append(info, btns);
        list.append(card);
    }
    t.append(list);

    // التقارير
    const rep = panel();
    rep.append(el('h3', 'font-black text-slate-800', 'تقارير المدرسة'));
    const repBody = el('div', 'space-y-3 text-sm text-slate-600', 'جارٍ تحميل نتائج الفصول...');
    rep.append(repBody);

    // أرشفة العام الدراسي: قائمة منسدلة بعيدة عن العرض الدائم
    const yr = panel('p-6 space-y-3');
    yr.append(el('p', 'text-sm text-slate-600 leading-relaxed', `العام الحالي: ${school.year}. عند نهاية العام يُؤرشف بما فيه من اختبارات ونتائج ولا يُحذف شيء، ويُفتح عام جديد بتاريخه. يرى المعلمون الأعوام السابقة للاطلاع.`));
    const ys = (school.years?.length ? school.years : [{ label: school.year }]).map((y) => y.label);
    yr.append(el('p', 'text-xs text-slate-500', `الأعوام المحفوظة: ${ys.join(' ، ')}`), actionButton('إنهاء العام الدراسي وفتح عام جديد', 'pd-new-year', '', 'bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-5 py-2.5 rounded-xl'));
    const archList = el('p', 'text-sm text-slate-600 pt-2 border-t border-slate-100', 'جارٍ تحميل الأرشيف...');
    yr.append(el('h4', 'font-bold text-slate-700 text-sm', 'أرشيف الاختبارات والنتائج'), archList);
    getDocs(query(collection(db, 'tests'), where('schoolNo', '==', school.no))).then((snap) => {
        const byYear = {};
        snap.docs.forEach((d) => { const y = d.data().year || 'بلا عام'; byYear[y] = (byYear[y] || 0) + 1; });
        const rows = Object.entries(byYear);
        archList.textContent = rows.length ? rows.map(([y, n]) => `${y}: ${n} اختبار`).join(' ، ') : 'لا توجد اختبارات مؤرشفة بعد.';
    }).catch(() => { archList.textContent = 'تعذّر تحميل الأرشيف.'; });

    body.append(
        ...(!school.classes.length || pdEditClasses ? [fold('classes', 'الصفوف والفصول — ' + (school.classes.length ? 'تعديل' : 'لم تُختر بعد'), classes)] : []),
        fold('teachers', `المعلمون وإسنادهم — ${roster.length} معلماً · ${needed.length - uncovered.length}/${needed.length} خانة${stage === 'reports' ? ' ✓' : ''}`, t),
        fold('reports', 'تقارير المدرسة', rep),
        fold('archive', 'أرشفة العام الدراسي', yr),
    );
    if (pdOpen === 'reports') { sections.reports.dataset.loaded = '1'; loadPrincipalReport(repBody); }
}

// تقرير المدرسة: لكل فصل ومادة متوسط النسبة وعدد من اختبروا، من اختبارات المعلمين المفعّلين في العام الحالي
async function loadPrincipalReport(box) {
    try {
        const uids = [...new Set(roster.filter((r) => r.uid).map((r) => r.uid))];
        const mine = (name, uid) => getDocs(query(collection(db, name), where('teacherUid', '==', uid)));
        const got = await Promise.all(uids.map((u) => Promise.all(['students', 'tests', 'testKeys', 'attempts'].map((n) => mine(n, u)))));
        const stu = [], tst = {}, key = {}, att = [];
        for (const [a, b, c, d] of got) {
            a.docs.forEach((x) => stu.push({ id: x.id, ...x.data() }));
            b.docs.forEach((x) => { tst[x.id] = { id: x.id, ...x.data() }; });
            c.docs.forEach((x) => { key[x.id] = x.data().answers; });
            d.docs.forEach((x) => att.push({ id: x.id, ...x.data(), submittedAt: ms(x.data().submittedAt) }));
        }
        const years = school.years?.length ? school.years : [{ label: school.year, start: 0 }];
        const cur = Object.fromEntries(Object.entries(tst).filter(([, t]) => (t.year ?? yearOf(years, ms(t.createdAt))) === school.year));
        const table = el('table', 'w-full text-right text-xs');
        const head = el('tr', 'bg-slate-50 text-slate-500');
        ['الفصل', 'الطلاب', 'لغتي', 'الرياضيات', 'العلوم'].forEach((h) => head.append(el('th', 'p-2', h)));
        table.append(head);
        for (const c of school.classes) {
            const sc = stu.filter((x) => x.className === c);
            const tr = el('tr', 'border-t border-slate-100');
            tr.append(el('td', 'p-2 font-bold text-slate-800', c), el('td', 'p-2', String(sc.length)));
            for (const sub of ['reading', 'math', 'science']) {
                const ts = Object.fromEntries(Object.entries(cur).filter(([, t]) => testSubject(t) === sub && t.className === c));
                if (!Object.keys(ts).length) { tr.append(el('td', 'p-2 text-slate-300', '—')); continue; }
                const r = buildReport(sc, att.filter((a) => ts[a.testId]), ts, key);
                tr.append(el('td', 'p-2', r.avg === null ? 'لا نتائج' : `${r.avg}% (${r.tested} طالباً)`));
            }
            table.append(tr);
        }
        box.replaceChildren(el('p', 'text-xs text-slate-500', `العام الدراسي ${school.year}: متوسط نسبة الإتقان لكل فصل ومادة.`), table);
    } catch (err) { box.textContent = 'تعذّر تحميل التقارير.'; reportError(err); }
}

async function openNewYear(btn) {
    const next = nextYearLabel(school.year);
    if (!(await confirmDialog(`إنهاء العام ${school.year} وفتح العام ${next}؟ يُؤرشف العام الحالي بكل بياناته ولا يُحذف منه شيء.`, 'نعم، افتح العام الجديد'))) return;
    await busy(btn, async () => {
        const years = school.years?.length ? school.years : [{ label: school.year, start: 0 }];
        await updateDoc(doc(db, 'schools', school.no), { year: next, years: [...years, { label: next, start: Date.now() }] });
        await openPrincipalDashboard();
        showAlert(`فُتح العام الدراسي ${next}، وأُرشف العام السابق.`, 'عام دراسي جديد');
    });
}

async function requestTransfer(btn) {
    await busy(btn, async () => {
        await setDoc(doc(db, 'schoolTransfers', principal.schoolNo), { schoolNo: principal.schoolNo, requesterUid: principal.uid, requesterName: principal.name, createdAt: serverTimestamp() });
        await openPrincipalDashboard();
        showAlert('أُرسل التنبيه إلى المدير الحالي ليحذف المدرسة من عنده. عند موافقته اضغط «تحقق من التبعية».', 'تم الإرسال');
    });
}

async function cancelTransfer() {
    await deleteDoc(doc(db, 'schoolTransfers', principal.schoolNo));
    await openPrincipalDashboard();
}

async function approveTransfer(btn) {
    if (!transferIn || !(await confirmDialog(`حذف المدرسة «${school.name}» من عندك ونقل تبعيتها إلى ${transferIn.requesterName}؟ تبقى بياناتها محفوظة عند المدير الجديد.`, 'نعم، احذفها من عندي'))) return;
    await busy(btn, async () => {
        const batch = writeBatch(db);
        batch.update(doc(db, 'schools', school.no), { principalUid: transferIn.requesterUid, principalName: transferIn.requesterName });
        batch.delete(doc(db, 'schoolTransfers', school.no));
        await batch.commit();
        await openPrincipalDashboard();
        showAlert('نُقلت تبعية المدرسة إلى المدير الجديد.', 'تم النقل');
    });
}

async function rejectTransfer() {
    await deleteDoc(doc(db, 'schoolTransfers', school.no));
    await openPrincipalDashboard();
}

async function deleteRosterTeacher(id) {
    const r = roster.find((x) => x.id === id);
    if (!r || !(await confirmDialog(`حذف المعلم ${r.name} من كشف المدرسة؟ لن يستطيع تفعيل حساب جديد، وتبقى بيانات طلابه واختباراته محفوظة.`, 'نعم، احذف'))) return;
    await deleteDoc(doc(db, 'teacherRoster', id));
    await openPrincipalDashboard();
}

async function resetRosterTeacher(id) {
    const r = roster.find((x) => x.id === id);
    if (!r || !(await confirmDialog(`إعادة ضبط تفعيل ${r.name}؟ سيحتاج لتفعيل حسابه من جديد برقم سجله (استعمله إن شككت أن غيره فعّل حسابه).`, 'نعم، أعد الضبط'))) return;
    await updateDoc(doc(db, 'teacherRoster', id), { uid: null, email: null, activatedAt: null });
    await openPrincipalDashboard();
}

async function savePrincipalClasses(btn) {
    const classes = [...document.querySelectorAll('[data-pd-class]')].filter((c) => c.checked).map((c) => c.dataset.pdClass);
    await busy(btn, async () => {
        await updateDoc(doc(db, 'schools', school.no), { classes });
        school.classes = classes;
        pdEditClasses = false;
        pdOpen = null;
        renderPrincipal();
        showAlert('حُفظت فصول المدرسة.', 'تم الحفظ');
    });
}

async function addRosterTeacher(e) {
    e.preventDefault();
    const name = $('pdTName').value.trim(), cid = $('pdTCivil').value.trim();
    let classes = [...document.querySelectorAll('[data-pd-t-class]')].filter((c) => c.checked).map((c) => c.dataset.pdTClass);
    if (!isCivilId(cid)) return showAlert('السجل المدني يجب أن يكون مكوناً من 10 أرقام.', 'تنبيه خطأ');
    let subjects = [...document.querySelectorAll('[data-pd-t-subject]')].filter((c) => c.checked).map((c) => c.dataset.pdTSubject);
    if (!classes.length) return showAlert('اختر فصلاً واحداً على الأقل للمعلم.', 'تنبيه');
    if (!subjects.length) return showAlert('حدّد تخصص المعلم: لغتي أو رياضيات أو علوم (واحداً على الأقل).', 'تنبيه');
    await busy(e.submitter, async () => {
        const prior = await getDoc(doc(db, 'teacherRoster', cid)).catch(() => null);
        if (prior?.exists() && prior.data().schoolNo === school.no) {
            // معلم مضاف سابقاً: من «تعديل الإسناد» يُستبدل إسناده بما حُدِّد، وإلا تُضاف الفصول والمواد الجديدة إلى إسناده السابق (التفعيل لا يُمسّ)
            const old = prior.data(), replace = pdEditing === cid;
            if (!replace) { classes = [...new Set([...old.classes, ...classes])]; subjects = [...new Set([...(old.subjects ?? []), ...subjects])]; }
            await updateDoc(doc(db, 'teacherRoster', cid), { name, classes, subjects });
        } else {
            try { await setDoc(doc(db, 'teacherRoster', cid), { schoolNo: school.no, name, classes, subjects, uid: null, createdAt: serverTimestamp() }); }
            catch (err) { if (err?.code === 'permission-denied') return showAlert('هذا السجل المدني مسجّل لمعلم في مدرسة أخرى. يلزم أن يحذفه مدير تلك المدرسة أولاً.', 'تعذّرت الإضافة'); throw err; }
        }
        pdOpen = null; pdEditing = null;
        await openPrincipalDashboard();
        if (prior?.exists() && prior.data().schoolNo === school.no) return showAlert(`حُدّث إسناد المعلم ${name}: فصوله الآن ${classes.join('، ')}، وتخصصه: ${subjects.map((x) => SUBJECTS[x].name).join('، ')}.`, 'تم التحديث');
        showAlert(`أُضيف المعلم ${name}. يدخل من بوابة المعلم ← «تفعيل حسابي» برقم سجله المدني، فينشئ كلمة مروره.`, 'تمت الإضافة');
    });
}

// ---------- مقدم خدمات التميز ----------

function setProviderTab(tab) {
    $('providerLoginForm').classList.toggle('hidden', tab !== 'login');
    $('providerSignupForm').classList.toggle('hidden', tab !== 'signup');
    $('vTabLogin').className = tab === 'login' ? 'flex-1 py-2 rounded-lg bg-white shadow text-rose-700' : 'flex-1 py-2 rounded-lg text-slate-500';
    $('vTabSignup').className = tab === 'signup' ? 'flex-1 py-2 rounded-lg bg-white shadow text-rose-700' : 'flex-1 py-2 rounded-lg text-slate-500';
}

async function providerLogin(e) {
    e.preventDefault();
    await busy(e.submitter, async () => { await signInWithEmailAndPassword(auth, $('vLoginEmail').value.trim(), $('vLoginPassword').value); $('vLoginPassword').value = ''; });
}

async function providerReset() {
    const email = $('vLoginEmail').value.trim();
    if (!email) return showAlert('اكتب بريدك الإلكتروني أولاً ثم اضغط «نسيت كلمة المرور».', 'تنبيه');
    try { await sendPasswordResetEmail(auth, email); showAlert('أرسلنا رابط تغيير كلمة المرور إلى بريدك (إن كان مسجلاً).', 'تم الإرسال'); } catch (err) { reportError(err); }
}

async function providerSignup(e) {
    e.preventDefault();
    const p = { name: $('vName').value.trim(), civilId: $('vCivil').value.trim(), email: $('vSignupEmail').value.trim() };
    if (!isCivilId(p.civilId)) return showAlert('السجل المدني يجب أن يكون مكوناً من 10 أرقام.', 'تنبيه خطأ');
    await busy(e.submitter, async () => {
        activating = true;
        let user;
        try {
            user = (await createUserWithEmailAndPassword(auth, p.email, $('vSignupPassword').value)).user;
            await setDoc(doc(db, 'providers', user.uid), { ...p, createdAt: serverTimestamp() });
            $('vSignupPassword').value = '';
            provider = { uid: user.uid, ...p };
            activating = false;
            await openProviderDashboard();
        } catch (err) {
            if (user) { await user.delete().catch(() => {}); await signOut(auth).catch(() => {}); }
            throw err;
        } finally { setTimeout(() => { activating = false; }, 600); }
    });
}

async function openProviderDashboard() {
    const q = await getDocs(query(collection(db, 'providerLinks'), where('providerUid', '==', provider.uid)));
    providerSchools = await Promise.all(q.docs.map(async (d) => {
        const no = d.id;
        const sc = await getDoc(doc(db, 'schools', no)).catch(() => null);
        const rq = await getDoc(doc(db, 'providerRequests', no)).catch(() => null);
        return { no, schoolName: sc?.exists() ? sc.data().name : '—', principalName: sc?.exists() ? sc.data().principalName : '—', incoming: rq?.exists() ? rq.data() : null };
    }));
    showScreen('providerDashboardScreen');
    renderProvider();
}

function renderProvider() {
    $('pvTitle').textContent = `مرحباً بك: ${provider.name}`;
    const body = $('pvBody');
    body.replaceChildren();
    const add = el('form', 'bg-white p-6 rounded-3xl shadow-sm border border-slate-100 space-y-3'); add.id = 'pvAddForm';
    add.append(el('h3', 'font-black text-slate-800', 'إضافة مدرسة تابعة لك'), el('p', 'text-xs text-slate-500', 'اكتب الرقم الإحصائي للمدرسة بعد أن يسجّلها مديرها في الموقع.'));
    const row = el('div', 'flex flex-wrap gap-3');
    const no = el('input', 'flex-1 min-w-0 w-full sm:w-auto px-4 py-2.5 border border-slate-200 rounded-xl text-sm'); no.id = 'pvSchoolNo'; no.placeholder = 'الرقم الإحصائي (أرقام فقط)'; no.required = true; no.pattern = '[0-9]{3,12}'; no.maxLength = 12; no.inputMode = 'numeric'; no.dir = 'ltr';
    const go = el('button', 'bg-rose-600 hover:bg-rose-700 text-white font-bold px-5 py-2.5 rounded-xl text-xs', 'إضافة المدرسة'); go.type = 'submit';
    row.append(no, go); add.append(row);
    add.addEventListener('submit', addProviderSchool);
    body.append(add);
    const list = el('section', 'space-y-3');
    list.append(el('h3', 'font-black text-slate-800', `مدارسي (${providerSchools.length})`));
    if (!providerSchools.length) list.append(el('p', 'text-sm text-slate-400', 'لم تضف مدارس بعد.'));
    for (const s of providerSchools) {
        const card = el('div', 'bg-white border border-slate-200 rounded-2xl p-4 text-sm space-y-2');
        card.append(el('p', 'font-bold text-slate-800', `${s.schoolName} — ${s.no}`), el('p', 'text-xs text-slate-500', `مدير المدرسة: ${s.principalName}`));
        if (s.incoming) {
            const n = el('div', 'bg-amber-50 border border-amber-300 rounded-xl p-3 text-xs space-y-2');
            n.append(el('p', 'font-bold text-amber-900', `تنبيه: المقدم ${s.incoming.requesterName} يطلب أن تُضاف هذه المدرسة إليه.`));
            const r = el('div', 'flex gap-3 font-bold');
            r.append(actionButton('حذف المدرسة من عندي', 'pv-approve', s.no, 'bg-red-600 text-white px-4 py-2 rounded-lg'), actionButton('رفض', 'pv-reject', s.no, 'text-slate-700'));
            n.append(r); card.append(n);
        }
        card.append(actionButton('إزالة المدرسة من عندي', 'pv-remove', s.no, 'text-xs font-bold text-red-500 hover:text-red-700'));
        list.append(card);
    }
    body.append(list);
}

async function addProviderSchool(e) {
    e.preventDefault();
    const no = $('pvSchoolNo').value.trim();
    await busy(e.submitter, async () => {
        const sc = await getDoc(doc(db, 'schools', no));
        if (!sc.exists()) return showAlert('لا توجد مدرسة بهذا الرقم الإحصائي. يسجّلها مديرها أولاً من بوابة المدير.', 'غير مسجّلة');
        const link = await getDoc(doc(db, 'providerLinks', no));
        if (link.exists() && link.data().providerUid === provider.uid) return showAlert('هذه المدرسة في قائمتك بالفعل.', 'تنبيه');
        if (link.exists()) {
            if (!(await confirmDialog(`المدرسة «${sc.data().name}» تتبع حالياً مقدم الخدمة: ${link.data().providerName}. نرسل له تنبيهاً ليحذفها من عنده فتُضاف إليك؟`, 'نعم، أرسل التنبيه'))) return;
            await setDoc(doc(db, 'providerRequests', no), { schoolNo: no, requesterUid: provider.uid, requesterName: provider.name, createdAt: serverTimestamp() });
            return showAlert(`أُرسل التنبيه إلى ${link.data().providerName}. تُضاف المدرسة إليك بعد موافقته، فأعد إضافتها عندئذٍ أو حدّث الصفحة.`, 'تم الإرسال');
        }
        await setDoc(doc(db, 'providerLinks', no), { schoolNo: no, providerUid: provider.uid, providerName: provider.name, createdAt: serverTimestamp() });
        await openProviderDashboard();
        showAlert(`أُضيفت المدرسة «${sc.data().name}» إلى مدارسك.`, 'تمت الإضافة');
    });
}

async function approveProviderTransfer(no) {
    const s = providerSchools.find((x) => x.no === no);
    if (!s?.incoming || !(await confirmDialog(`حذف المدرسة «${s.schoolName}» من عندك ونقلها إلى ${s.incoming.requesterName}؟`, 'نعم، احذفها من عندي'))) return;
    const batch = writeBatch(db);
    batch.update(doc(db, 'providerLinks', no), { providerUid: s.incoming.requesterUid, providerName: s.incoming.requesterName });
    batch.delete(doc(db, 'providerRequests', no));
    await batch.commit();
    await openProviderDashboard();
}

async function removeProviderSchool(no) {
    if (!(await confirmDialog('إزالة هذه المدرسة من قائمة مدارسك؟', 'نعم، أزلها'))) return;
    await deleteDoc(doc(db, 'providerLinks', no));
    await openProviderDashboard();
}

// ---------- كيف يعمل الموقع (إنفوجرافيك) ----------
let howFrom = 'roleSelectionScreen';
function showHow() {
    const current = document.querySelector('.screen:not(.hidden)')?.id;
    if (current && current !== 'howScreen' && current !== 'loadingScreen') howFrom = current;
    showScreen('howScreen');
    window.scrollTo({ top: 0 });
}

// ---------- عن اختبارات نافس ----------

function showAbout() {
    const current = document.querySelector('.screen:not(.hidden)')?.id;
    if (current && current !== 'aboutScreen' && current !== 'loadingScreen') aboutFrom = current;
    setAboutTab('student');
    showScreen('aboutScreen');
    window.scrollTo({ top: 0 });
}

function setAboutTab(tab) {
    const on = 'flex-1 py-2.5 rounded-lg bg-white shadow text-emerald-700';
    const off = 'flex-1 py-2.5 rounded-lg text-slate-500';
    for (const [name, label] of [['student', 'Student'], ['parent', 'Parent'], ['format', 'Format']]) {
        $(`aboutPanel${label}`).classList.toggle('hidden', tab !== name);
        $(`aboutTab${label}`).className = tab === name ? on : off;
    }
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

function confirmDialog(message, okLabel = 'نعم، احذف') {
    showAlert(message, 'تأكيد');
    $('modalCancel').classList.remove('hidden');
    $('modalOk').textContent = okLabel;
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

// ---------- مستويات الأداء (هيئة تقويم التعليم والتدريب) ----------

const PERF_PAGES = {
    reading3: [2, 3], reading6: [4], reading9: [5], math3: [6], math6: [7], math9: [8], science6: [9, 10], science9: [11, 12],
};

function showPerf() {
    const grade = currentGrade();
    const pages = PERF_PAGES[`${repSubject}${grade}`] ?? [];
    $('perfTitle').textContent = `مستويات الأداء — ${SUBJECTS[repSubject].name} (${GRADES[grade].name})`;
    const body = $('perfBody');
    body.replaceChildren();
    if (!pages.length) body.append(el('p', 'text-sm text-slate-500', 'لا يتوفر وصف لهذه المادة والصف.'));
    for (const n of pages) {
        const img = el('img', 'w-full rounded-xl border border-slate-200');
        img.src = `performance/p${n}.webp`; img.alt = 'مستويات الأداء'; img.loading = 'lazy';
        body.append(img);
    }
    $('perfModal').classList.remove('hidden');
}

// ---------- بنك الأسئلة ----------

async function loadBank() {
    try {
        const snap = await getDocs(query(collection(db, 'bank'), where('teacherUid', '==', teacher.uid)));
        bank = snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => ms(b.createdAt) - ms(a.createdAt));
        renderBank();
    } catch (err) { reportError(err); }
}

function bankSkillOptions() {
    const grade = gradeOfClass(teacher.className);
    const subSel = $('bankSubject');
    const subjects = mySubjects(grade);
    if (subSel.options.length !== subjects.length) {
        subSel.replaceChildren(...subjects.map((s) => new Option(SUBJECTS[s].name, s)));
    }
    const skSel = $('bankSkill');
    const keep = skSel.value;
    skSel.replaceChildren();
    for (const sk of skillsFor(subSel.value || subjects[0], grade)) {
        const full = skillById(sk.id);
        skSel.add(new Option(`${full.outcome.name} — ${sk.name}`, sk.id));
    }
    if (keep && [...skSel.options].some((o) => o.value === keep)) skSel.value = keep;
}

function bankCard(q) {
    const sk = skillById(q.skill);
    const card = el('div', 'bg-white border border-slate-200 rounded-2xl p-4 space-y-2');
    const head = el('div', 'flex flex-wrap items-center gap-2 text-[11px]');
    const tone = { approved: 'bg-emerald-100 text-emerald-800', generated: 'bg-amber-100 text-amber-800', rejected: 'bg-red-100 text-red-700', na: 'bg-slate-100 text-slate-500' }[q.status];
    head.append(el('span', `px-2 py-0.5 rounded-lg font-bold ${tone}`, BANK_STATUS[q.status]), el('span', 'px-2 py-0.5 rounded-lg bg-teal-50 text-teal-800', LEVELS.find((l) => l.id === q.level)?.name ?? q.level), el('span', 'text-slate-500', `${sk?.outcome?.name ?? ''} — ${sk?.name ?? q.skill}`), el('span', 'text-slate-400', q.source === 'ai' ? 'مولَّد' : 'يدوي'));
    card.append(head);
    if (q.status === 'na') {
        card.append(el('p', 'text-sm text-slate-600', `غير منطبق: ${q.reason || '—'}`), actionButton('حذف', 'bank-delete', q.id, 'text-xs text-red-500 font-bold'));
        return card;
    }
    card.append(el('p', 'text-sm font-bold text-slate-800', q.text));
    const ol = el('div', 'grid grid-cols-1 sm:grid-cols-2 gap-1 text-xs');
    q.options.forEach((o, i) => ol.append(el('span', `rounded-lg px-2 py-1 ${i === q.answer ? 'bg-emerald-50 text-emerald-800 font-bold' : 'bg-slate-50 text-slate-600'}`, `${'أبجد'[i]}) ${o}`)));
    card.append(ol, el('p', 'text-[11px] text-slate-500', `التفسير: ${q.explanation || '—'}`));
    const issues = qualityIssues(q);
    if (issues.length) card.append(el('p', 'text-[11px] text-amber-700 bg-amber-50 rounded-lg px-2 py-1', 'ملاحظات الجودة: ' + issues.join(' · ')));
    const row = el('div', 'flex flex-wrap gap-3 pt-1');
    if (canTransition(q.status, 'approved')) { const b = actionButton('اعتماد', 'bank-set', q.id, 'text-xs text-emerald-700 font-bold'); b.dataset.to = 'approved'; row.append(b); }
    if (canTransition(q.status, 'rejected')) { const b = actionButton('رفض', 'bank-set', q.id, 'text-xs text-red-600 font-bold'); b.dataset.to = 'rejected'; row.append(b); }
    row.append(actionButton('تحرير', 'bank-edit', q.id, 'text-xs text-slate-700 font-bold'), actionButton('حذف', 'bank-delete', q.id, 'text-xs text-red-500 font-bold'));
    card.append(row);
    return card;
}

function bankEditor(q) {
    const card = el('div', 'bg-white border-2 border-emerald-300 rounded-2xl p-4 space-y-2');
    card.id = 'bankEditor';
    const text = el('textarea', 'w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm'); text.rows = 2; text.id = 'beText'; text.value = q.text ?? ''; text.maxLength = 600; text.placeholder = 'نص السؤال';
    const lvl = el('select', 'px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs'); lvl.id = beLevelId;
    for (const l of LEVELS) lvl.add(new Option(l.name, l.id)); lvl.value = q.level ?? 'know';
    const opts = el('div', 'grid grid-cols-1 sm:grid-cols-2 gap-2');
    for (let j = 0; j < 4; j++) {
        const row = el('label', 'flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2');
        const r = el('input', 'accent-emerald-600'); r.type = 'radio'; r.name = 'beAns'; r.value = j; r.checked = (q.answer ?? 0) === j;
        const i = el('input', 'flex-1 min-w-0 text-sm bg-transparent focus:outline-none'); i.className += ' beOpt'; i.value = q.options?.[j] ?? ''; i.maxLength = 300; i.placeholder = `الخيار ${j + 1}`;
        row.append(r, i); opts.append(row);
    }
    const ex = el('input', 'w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm'); ex.id = 'beExplain'; ex.value = q.explanation ?? ''; ex.maxLength = 400; ex.placeholder = 'تفسير الإجابة الصحيحة';
    const row = el('div', 'flex gap-3');
    row.append(actionButton('حفظ', 'bank-save', '', 'bg-emerald-600 text-white font-bold px-4 py-2 rounded-xl text-xs'), actionButton('إلغاء', 'bank-cancel', '', 'text-xs text-slate-500 font-bold'));
    card.append(lvl, text, opts, ex, row);
    return card;
}
const beLevelId = 'beLevel';

function renderBank() {
    if (!teacher) return;
    bankSkillOptions();
    const f = $('bankFilter').value;
    const list = bank.filter((q) => f === 'all' || q.status === f);
    $('bankCount').textContent = list.length;
    const box = $('bankList');
    box.replaceChildren();
    if (bankEditing === 'new') box.append(bankEditor({ skill: $('bankSkill').value }));
    if (!list.length && bankEditing !== 'new') box.append(el('p', 'text-sm text-slate-400 text-center py-8', 'لا أسئلة هنا بعد. اختر مؤشراً ثم ولّد مسودات أو أدخل سؤالاً.'));
    for (const q of list) box.append(bankEditing === q.id ? bankEditor(q) : bankCard(q));
    renderDrafts();
}

function bankData(q, over = {}) {
    const { id, createdAt, ...rest } = { ...q, ...over };
    const data = { ...rest, teacherUid: teacher.uid, updatedAt: serverTimestamp() };
    for (const k of Object.keys(data)) if (data[k] === undefined || (k === 'passageId' && data[k] === null)) delete data[k];
    return data;
}

// ---------- مسودات جاهزة: يختار المعلم أو مقدم الدعم ويعتمد بنفسه ----------

let drafts = [];            // مسودات المادة والصف الحاليين (من الملف)
const draftPick = new Set();

async function loadDrafts() {
    const subject = $('bankSubject').value;
    const grade = gradeOfClass(teacher.className);
    try {
        const res = await fetch(`/bank-drafts/${subject}-${grade}.json`);
        drafts = res.ok ? await res.json() : [];
    } catch { drafts = []; }
    draftPick.clear();
    renderDrafts();
}

function draftKey(r) { return `${r.skill}|${r.level}`; }

function renderDrafts() {
    const box = $('draftList');
    if (!box) return;
    const skill = $('bankSkill').value;
    const mine = new Set(bank.filter((q) => q.status !== 'rejected').map((q) => draftKey(q)));
    const list = drafts.filter((r) => r.applicable !== false && r.skill === skill && !mine.has(draftKey(r)));
    box.replaceChildren();
    if (!list.length) box.append(el('p', 'text-xs text-slate-400 text-center py-3', drafts.length ? 'لا مسودات جديدة لهذا المؤشر (أضفتَها من قبل أو لا توجد بعد).' : 'لا مسودات جاهزة لهذه المادة والصف بعد.'));
    for (const r of list) {
        const row = el('label', 'flex gap-3 items-start bg-slate-50 border border-slate-200 rounded-xl p-3 cursor-pointer');
        const cb = el('input', 'mt-1 accent-emerald-600'); cb.type = 'checkbox'; cb.dataset.draft = draftKey(r); cb.checked = draftPick.has(draftKey(r));
        const body = el('div', 'space-y-1 min-w-0');
        body.append(el('p', 'text-[11px] text-teal-800 font-bold', LEVELS.find((l) => l.id === r.level)?.name ?? r.level), el('p', 'text-sm font-bold text-slate-800', r.text));
        const ol = el('div', 'grid grid-cols-1 sm:grid-cols-2 gap-1 text-xs');
        r.options.forEach((o, i) => ol.append(el('span', `rounded-lg px-2 py-1 ${i === r.answer ? 'bg-emerald-50 text-emerald-800 font-bold' : 'bg-white text-slate-600'}`, `${'أبجد'[i]}) ${o}`)));
        body.append(ol, el('p', 'text-[11px] text-slate-500', `التفسير: ${r.explanation}`));
        row.append(cb, body);
        box.append(row);
    }
    $('draftSel').textContent = draftPick.size;
}

async function approveDrafts(button) {
    const chosen = drafts.filter((r) => draftPick.has(draftKey(r)));
    if (!chosen.length) return showAlert('حدّد سؤالاً واحداً على الأقل.', 'لا تحديد');
    await busy(button, async () => {
        let n = 0;
        const have = [...bank];
        for (const r of chosen) {
            const rec = { ...newBankQuestion({ skill: r.skill, level: r.level, text: r.text, options: r.options, answer: r.answer, explanation: r.explanation, source: 'ai' }), status: 'approved' };
            if (qualityIssues(rec).length || isDuplicate(rec, have)) continue;
            await addDoc(collection(db, 'bank'), { ...bankData(rec), createdAt: serverTimestamp() });
            have.push(rec); n++;
        }
        draftPick.clear();
        await loadBank();
        showAlert(`اعتُمد ${n} سؤالاً وأُضيف إلى بنكك.`, 'تم الاعتماد');
    });
}

// استيراد مسودات من ملف JSON: [{skill, level, text, options, answer, explanation} | {skill, level, applicable:false, reason}]
async function importBank(e) {
    const file = e.target.files[0];
    e.target.value = '';
    if (!file) return;
    let rows;
    try { rows = JSON.parse(await file.text()); if (!Array.isArray(rows) || rows.length > 300) throw new Error(); } catch { return showAlert('الملف غير صالح: يجب أن يكون قائمة JSON (حتى 300 عنصر).', 'تعذر الاستيراد'); }
    const have = [...bank];
    const records = [], skipped = [];
    for (const r of rows) {
        const sk = skillById(r?.skill);
        if (!sk || sk.grade !== gradeOfClass(teacher.className) || !['know', 'apply', 'reason'].includes(r.level)) { skipped.push('مهارة أو مستوى غير صحيح'); continue; }
        const rec = r.applicable === false
            ? { skill: r.skill, level: r.level, status: 'na', reason: String(r.reason ?? 'لم يحدَّد سبب').slice(0, 300), version: 1, source: 'ai' }
            : newBankQuestion({ skill: r.skill, level: r.level, text: String(r.text ?? ''), options: (r.options ?? []).map(String), answer: r.answer, explanation: String(r.explanation ?? ''), source: 'ai' });
        if (rec.status !== 'na' && (!Array.isArray(r.options) || r.options.length !== 4 || !Number.isInteger(r.answer) || r.answer < 0 || r.answer > 3)) { skipped.push('خيارات أو مفتاح غير صحيح'); continue; }
        if (rec.status !== 'na' && isDuplicate(rec, have)) { skipped.push('مكرر'); continue; }
        records.push(rec); have.push(rec);
    }
    try {
        for (const r of records) await addDoc(collection(db, 'bank'), { ...bankData(r), createdAt: serverTimestamp() });
        await loadBank();
        showAlert(`أُضيف ${records.length} إلى «بانتظار المراجعة»${skipped.length ? `، وتُجوهل ${skipped.length} (${[...new Set(skipped)].join('، ')})` : ''}.`, 'تم الاستيراد');
    } catch (err) { reportError(err); }
}

async function saveBankQuestion(button) {
    const options = [...document.querySelectorAll('#bankEditor .beOpt')].map((i) => i.value.trim());
    const q = { skill: bankEditing === 'new' ? $('bankSkill').value : bank.find((x) => x.id === bankEditing).skill, level: $(beLevelId).value, text: $('beText').value.trim(), options, answer: Number(document.querySelector('#bankEditor input[name=beAns]:checked')?.value ?? 0), explanation: $('beExplain').value.trim() };
    await busy(button, async () => {
        if (bankEditing === 'new') {
            await addDoc(collection(db, 'bank'), { ...bankData(newBankQuestion({ ...q, source: 'manual' })), createdAt: serverTimestamp() });
        } else {
            const old = bank.find((x) => x.id === bankEditing);
            // أي تحرير يعيد السؤال إلى المراجعة ويرفع الإصدار
            await setDoc(doc(db, 'bank', old.id), { ...bankData(old, { ...q, status: 'generated', version: old.version + 1 }), createdAt: old.createdAt ?? serverTimestamp() });
        }
        bankEditing = null;
        await loadBank();
    });
}

async function setBankStatus(id, to, button) {
    const q = bank.find((x) => x.id === id);
    if (!q || !canTransition(q.status, to)) return;
    if (to === 'approved') {
        const issues = qualityIssues(q);
        if (issues.length) return showAlert('لا يمكن اعتماد السؤال قبل معالجة: ' + issues.join(' · '), 'ملاحظات الجودة');
    }
    await busy(button, async () => {
        await updateDoc(doc(db, 'bank', id), { status: to, version: q.version + 1, updatedAt: serverTimestamp() });
        await loadBank();
    });
}

async function deleteBank(id) {
    if (!(await confirmDialog('حذف هذا السؤال من البنك نهائياً؟'))) return;
    try { await deleteDoc(doc(db, 'bank', id)); await loadBank(); } catch (err) { reportError(err); }
}

// في منشئ الاختبار: المعتمد فقط، لمهارات الاختبار المختارة
async function showBankPicker() {
    if (!draft.skills.length) return builderError('اختر مهارة واحدة على الأقل أولاً.');
    const box = $('bankPicker');
    if (!box.classList.contains('hidden')) return box.classList.add('hidden');
    try { await loadBankQuiet(); } catch (err) { return reportError(err); }
    const usable = bank.filter((q) => usableInTest(q) && draft.skills.includes(q.skill));
    box.replaceChildren(el('p', 'text-xs font-bold text-emerald-800', 'أسئلة معتمدة من بنكك لمهاراتك المختارة:'));
    if (!usable.length) box.append(el('p', 'text-xs text-slate-500', 'لا أسئلة معتمدة لهذه المهارات بعد. أضفها من تبويب «بنك الأسئلة».'));
    for (const q of usable) {
        const row = el('div', 'flex items-center justify-between gap-3 bg-white rounded-xl px-3 py-2 border border-slate-200');
        row.append(el('span', 'text-xs text-slate-700', `${LEVELS.find((l) => l.id === q.level)?.name}: ${q.text}`), actionButton('إضافة', 'bank-use', q.id, 'text-xs text-emerald-700 font-bold shrink-0'));
        box.append(row);
    }
    box.classList.remove('hidden');
}
async function loadBankQuiet() {
    const snap = await getDocs(query(collection(db, 'bank'), where('teacherUid', '==', teacher.uid)));
    bank = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}
function useBankQuestion(id) {
    const q = bank.find((x) => x.id === id);
    if (!q || !usableInTest(q)) return;
    draft.questions.push({ skill: q.skill, level: q.level, text: q.text, options: [...q.options], answer: q.answer, bankId: q.id, bankVersion: q.version });
    renderQuestions();
}

// ---------- الأحداث ----------

function bindEvents() {
    $('teacherLoginForm').addEventListener('submit', teacherLogin);
    $('teacherSignupForm').addEventListener('submit', teacherSignup);
    $('principalLoginForm').addEventListener('submit', principalLogin);
    $('providerLoginForm').addEventListener('submit', providerLogin);
    $('providerSignupForm').addEventListener('submit', providerSignup);
    $('principalSignupForm').addEventListener('submit', principalSignup);
    $('addStudentForm').addEventListener('submit', addStudent);
    $('studentLoginForm').addEventListener('submit', studentLogin);
    $('excelFile').addEventListener('change', handleExcelUpload);
    $('omrFiles').addEventListener('change', (e) => handleOmrFiles([...e.target.files]));
    $('dashClass').addEventListener('change', changeClass);
    $('yearSel').addEventListener('change', () => { viewYear = $('yearSel').value; renderTeacher(); });
    $('bankImport').addEventListener('change', importBank);
    $('bankPanel').addEventListener('change', (e) => {
        const t = e.target;
        if (t.dataset.bpSkill) { t.checked ? bpState.skills.add(t.dataset.bpSkill) : bpState.skills.delete(t.dataset.bpSkill); updateBankCount(); }
        else if (t.dataset.bpLevel) { t.checked ? bpState.levels.add(t.dataset.bpLevel) : bpState.levels.delete(t.dataset.bpLevel); renderBankPanel(); }
    });
    $('bankFilter').addEventListener('change', renderBank);
    $('bankSubject').addEventListener('change', () => { renderBank(); if (!$('draftPanel').classList.contains('hidden')) loadDrafts(); });
    $('bankSkill').addEventListener('change', renderDrafts);
    $('draftList').addEventListener('change', (e) => { const k = e.target.dataset.draft; if (k) { e.target.checked ? draftPick.add(k) : draftPick.delete(k); $('draftSel').textContent = draftPick.size; } });
    $('modalOk').addEventListener('click', () => closeModal(true));
    $('modalCancel').addEventListener('click', () => closeModal(false));
    $('testBuilder').addEventListener('input', builderInput);
    $('testBuilder').addEventListener('change', builderInput);

    document.addEventListener('click', (e) => {
        const el = e.target.closest('[data-action]');
        if (!el) return;
        const { action, id, tab, publish } = el.dataset;
        switch (action) {
            case 'show-teacher-login': showScreen('teacherLoginScreen'); setAuthMode('login'); break;
            case 'show-provider-login': showScreen('providerAuthScreen'); setProviderTab('login'); break;
            case 'v-auth-tab': setProviderTab(tab); break;
            case 'v-reset-password': providerReset(); break;
            case 'pv-approve': approveProviderTransfer(id); break;
            case 'pv-reject': deleteDoc(doc(db, 'providerRequests', id)).then(openProviderDashboard); break;
            case 'pv-remove': removeProviderSchool(id); break;
            case 'show-principal-login': showScreen('principalAuthScreen'); setPrincipalTab('login'); break;
            case 'p-auth-tab': setPrincipalTab(tab); break;
            case 'p-reset-password': principalReset(); break;
            case 'pd-save-classes': savePrincipalClasses(el); break;
            case 'pd-edit-classes': pdEditClasses = true; pdOpen = 'classes'; renderPrincipal(); break;
            case 'pd-new-year': openNewYear(el); break;
            case 'pd-request-transfer': requestTransfer(el); break;
            case 'pd-cancel-transfer': cancelTransfer(); break;
            case 'pd-approve-transfer': approveTransfer(el); break;
            case 'pd-reject-transfer': rejectTransfer(); break;
            case 'pd-refresh': openPrincipalDashboard(); break;
            case 'pd-del-teacher': deleteRosterTeacher(id); break;
            case 'pd-edit-teacher': {
                const r = roster.find((x) => x.id === id);
                if (!r) break;
                pdEditing = id;
                $('pdTName').value = r.name; $('pdTCivil').value = r.id;
                document.querySelectorAll('[data-pd-t-class]').forEach((c) => { c.checked = r.classes.includes(c.value); });
                document.querySelectorAll('[data-pd-t-subject]').forEach((c) => { c.checked = (r.subjects ?? []).includes(c.value); });
                $('pdTeacherForm').scrollIntoView({ behavior: 'smooth', block: 'center' });
                break;
            }
            case 'pd-reset-teacher': resetRosterTeacher(id); break;
            case 'show-student-login': showScreen('studentLoginScreen'); break;
            case 'back': showScreen('roleSelectionScreen'); break;
            case 'auth-tab': setAuthMode(tab); break;
            case 'reset-password': resetPassword(); break;
            case 'logout': logout(); break;
            case 'teacher-tab': switchTeacherTab(tab); break;
            case 'export': exportReport(); break;
            case 'clear-all': clearAllStudents(); break;
            case 'delete-student': deleteStudent(id); break;
            case 'gen-pins': genPins(); break;
            case 'print-cards': printCards(); break;
            case 'print-roster': printRoster(); break;
            case 'download-upload': downloadUpload(id); break;
            case 'delete-upload': deleteUpload(id); break;
            case 'show-about': showAbout(); break;
            case 'show-how': showHow(); break;
            case 'back-from-how': showScreen(howFrom === 'teacherDashboardScreen' && !teacher ? 'roleSelectionScreen' : howFrom); break;
            case 'back-from-about': showScreen(aboutFrom === 'loadingScreen' || (aboutFrom === 'teacherDashboardScreen' && !teacher) ? 'roleSelectionScreen' : aboutFrom); break;
            case 'about-tab': setAboutTab(tab); break;
            case 'rep-subject': repSubject = id; renderTeacher(); break;
            case 'tb-subject': setBuilderSubject(id); break;
            case 'toggle-outcome': toggleOutcome(id); break;
            case 'show-official': showOfficial(); break;
            case 'show-bankpanel': showBankPanel(); break;
            case 'hide-bankpanel': $('bankPanel').classList.add('hidden'); break;
            case 'bp-subject': bpState.subject = id; bpState.skills.clear(); renderBankPanel(); break;
            case 'bp-create': createBankTest(el); break;
            case 'hide-official': $('officialPanel').classList.add('hidden'); break;
            case 'add-official': (id.startsWith('mock-') || id.startsWith('sol-') ? addMock(id, el) : addOfficial(id, el)); break;
            case 'draft-toggle': $('draftPanel').classList.toggle('hidden'); if (!$('draftPanel').classList.contains('hidden')) loadDrafts(); break;
            case 'draft-all': document.querySelectorAll('#draftList input[data-draft]').forEach((c) => { c.checked = true; draftPick.add(c.dataset.draft); }); $('draftSel').textContent = draftPick.size; break;
            case 'draft-none': draftPick.clear(); renderDrafts(); break;
            case 'draft-approve': approveDrafts(el); break;
            case 'bank-new': bankEditing = 'new'; renderBank(); break;
            case 'bank-edit': bankEditing = id; renderBank(); break;
            case 'bank-cancel': bankEditing = null; renderBank(); break;
            case 'bank-save': saveBankQuestion(el); break;
            case 'bank-set': setBankStatus(id, el.dataset.to, el); break;
            case 'bank-delete': deleteBank(id); break;
            case 'add-from-bank': showBankPicker(); break;
            case 'bank-use': useBankQuestion(id); break;
            case 'new-test': openBuilder(null); break;
            case 'edit-test': openBuilder(tests.find((t) => t.id === id)); break;
            case 'cancel-test': closeBuilder(); break;
            case 'load-template': loadTemplate(); break;
            case 'add-question': addQuestion(); break;
            case 'remove-question': draft.questions.splice(Number(id), 1); renderQuestions(); break;
            case 'save-test': saveTest(el, publish === '1'); break;
            case 'toggle-publish': togglePublish(id); break;
            case 'delete-test': deleteTest(id); break;
            case 'print-omr': case 'print-key': case 'print-book': printOmr(id, action); break;
            case 'scan-omr': openOmrScan(id); break;
            case 'close-omr': $('omrModal').classList.add('hidden'); break;
            case 'approve-omr': approveOmr(el); break;
            case 'student-detail': showStudentDetail(id); break;
            case 'show-perf': showPerf(); break;
            case 'close-perf': $('perfModal').classList.add('hidden'); break;
            case 'close-student': $('studentModal').classList.add('hidden'); break;
            case 'open-test': openStudentTest(id); break;
            case 'back-to-tests': renderStudentTests(); break;
            case 'submit-test': submitTest(e); break;
            case 'student-logout': studentLogout(); break;
        }
    });
}

start();
