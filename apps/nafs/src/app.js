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
import { GRADES, LEVELS, DOMAINS, gradeOfClass, skillById, levelName } from './skills.js';
import { TEMPLATES } from './templates.js';

const $ = (id) => document.getElementById(id);

let auth, db;
let teacher = null;        // {uid, name, civilId, school, className, email}
let students = [];         // طلاب المعلم كلهم (كل الفصول)
let uploads = [];
let activeStudent = null;  // {id, name, ...}
let teacherTab = 'students';
let authMode = 'login';
let tests = [];            // اختبارات المعلم (كل الفصول)
let keys = {};             // testId → الإجابات الصحيحة
let attempts = [];         // محاولات طلاب المعلم
let draft = null;          // الاختبار قيد البناء
let studentTests = [];     // اختبارات فصل الطالب المنشورة
let openTest = null;

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
    await Promise.all([loadStudents(), loadUploads(), loadTeacherTests()]);
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

const TAB_ON = 'pb-3 border-b-2 border-emerald-600 font-bold text-emerald-700 text-sm transition whitespace-nowrap';
const TAB_OFF = 'pb-3 border-b-2 border-transparent text-slate-500 hover:text-slate-800 font-bold text-sm transition whitespace-nowrap';

function switchTeacherTab(tab) {
    teacherTab = tab;
    for (const [name, panel, btn] of [['students', 'teacherTabStudents', 'tabBtnStudents'], ['tests', 'teacherTabTests', 'tabBtnTests'], ['reports', 'teacherTabReports', 'tabBtnReports']]) {
        $(panel).classList.toggle('hidden', tab !== name);
        $(btn).className = tab === name ? TAB_ON : TAB_OFF;
    }
    renderTeacher();
}

const classStudents = () => students.filter((s) => s.className === teacher.className);

async function loadStudents() {
    const snap = await getDocs(query(collection(db, 'students'), where('teacherUid', '==', teacher.uid)));
    students = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
        .sort((a, b) => (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0));
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
const classTests = () => tests.filter((t) => t.className === teacher.className);
const currentGrade = () => gradeOfClass(teacher.className);

function classReport() {
    const ct = Object.fromEntries(classTests().map((t) => [t.id, t]));
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
    const report = classReport();
    if (teacherTab === 'students') renderStudentsTab(report);
    else if (teacherTab === 'tests') renderTestsTab();
    else renderReports(report);
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
        tr.append(cell(i + 1, 'p-3 font-bold'), cell(s.name, 'p-3 font-semibold text-slate-800'), cell(s.id, 'p-3 font-mono text-slate-600'), level, actions);
        tbody.append(tr);
    });
}

// ---------- التقارير ----------

function renderReports(report) {
    const grade = currentGrade();
    $('repTotalStudents').textContent = report.students.length;
    $('repTests').textContent = classTests().filter((t) => t.status === 'published').length;
    $('repCompletedCount').textContent = report.tested;
    $('repAvgMastery').textContent = report.avg === null ? '—' : report.avg + '%';

    const skillsBox = $('repSkills');
    skillsBox.replaceChildren();
    for (const o of GRADES[grade].outcomes) {
        const group = el('div', 'space-y-3');
        group.append(el('p', 'text-[11px] font-bold text-emerald-700 bg-emerald-50 rounded-lg px-3 py-2', `${DOMAINS[o.domain]} — ${o.text}`));
        for (const ind of o.indicators) group.append(statRow(ind.name, report.skills[ind.id], ind.desc));
        skillsBox.append(group);
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
    const s = classReport().students.find((x) => x.id === id);
    if (!s) return;
    $('smName').textContent = s.name;
    $('smMeta').textContent = `السجل المدني: ${s.id} · النسبة العامة: ${s.pct ?? '—'}% · ${masteryLevel(s.pct).label}`
        + (s.progress === null ? '' : ` · التقدّم من أول اختبار: ${s.progress > 0 ? '+' : ''}${s.progress}%`);
    $('smHistory').replaceChildren(...s.history.map((h) => statRow(`${h.title} — ${new Date(h.at).toLocaleDateString('ar-SA')}`, { pct: h.pct })));
    const box = $('smSkills');
    box.replaceChildren();
    for (const o of GRADES[currentGrade()].outcomes) {
        for (const ind of o.indicators) if (s.skills[ind.id]) box.append(statRow(ind.name, s.skills[ind.id], ind.desc));
    }
    $('studentModal').classList.remove('hidden');
}

function exportReport() {
    const report = classReport();
    if (!report.students.length) return showAlert('لا توجد بيانات طلاب لتصديرها.', 'تنبيه');
    const ids = GRADES[currentGrade()].outcomes.flatMap((o) => o.indicators.map((i) => i.id));
    downloadBlob(new Blob([reportCsv(report, ids, (id) => skillById(id).name)], { type: 'text/csv;charset=utf-8;' }), `تقرير_مهارات_القراءة_${teacher.className}.csv`);
    showAlert('تم تصدير تقرير المهارات بنجاح!', 'نجاح التصدير');
}

// ---------- بناء الاختبارات ----------

function renderTestsTab() {
    const grade = currentGrade();
    $('testsClassName').textContent = teacher.className;
    $('testsGradeName').textContent = GRADES[grade].name;
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
        const meta = el('p', 'text-xs text-slate-500', `${t.questions.length} سؤالاً · ${t.skills.length} مهارات · أجاب ${done} من ${total} طالباً`);
        const chips = el('div', 'flex flex-wrap gap-1.5');
        for (const id of t.skills) chips.append(el('span', 'text-[11px] bg-teal-50 text-teal-800 border border-teal-100 rounded-lg px-2 py-0.5', skillById(id)?.name ?? id));
        const btns = el('div', 'flex flex-wrap gap-3 pt-1 text-xs font-bold');
        btns.append(actionButton(t.status === 'published' ? 'إيقاف النشر' : 'نشر للطلاب', 'toggle-publish', t.id, 'text-emerald-700 hover:text-emerald-900'));
        btns.append(actionButton(done ? 'نسخ كاختبار جديد' : 'تعديل', 'edit-test', t.id, 'text-slate-700 hover:text-slate-900'));
        btns.append(actionButton('حذف', 'delete-test', t.id, 'text-red-500 hover:text-red-700'));
        card.append(head, meta, chips, btns);
        box.append(card);
    }
}

function openBuilder(test) {
    const copy = test && attempts.some((a) => a.testId === test.id); // اختبار له إجابات يُنسخ ولا يُعدّل
    draft = test ? {
        id: copy ? null : test.id,
        createdAt: copy ? null : test.createdAt,
        status: copy ? 'draft' : test.status,
        title: copy ? `${test.title} (نسخة)` : test.title,
        passage: test.passage,
        className: teacher.className,
        grade: test.grade,
        skills: [...test.skills],
        questions: test.questions.map((q, i) => ({ ...q, options: [...q.options, '', '', ''].slice(0, Math.max(4, q.options.length)), answer: keys[test.id]?.[i] ?? 0 })),
    } : { id: null, title: '', passage: '', className: teacher.className, grade: currentGrade(), skills: [], questions: [] };
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
    const box = $('tbSkills');
    box.replaceChildren();
    for (const o of GRADES[draft.grade].outcomes) {
        const group = el('fieldset', 'border border-slate-200 rounded-2xl p-4 space-y-2');
        group.append(el('legend', 'px-2 text-xs font-bold text-emerald-700', DOMAINS[o.domain]));
        group.append(el('p', 'text-[11px] text-slate-500 mb-2', o.text));
        for (const ind of o.indicators) {
            const label = el('label', 'flex items-start gap-3 p-2.5 rounded-xl hover:bg-slate-50 cursor-pointer');
            const cb = el('input', 'mt-1 accent-emerald-600 w-4 h-4 shrink-0');
            cb.type = 'checkbox';
            cb.dataset.skill = ind.id;
            cb.checked = draft.skills.includes(ind.id);
            const txt = el('span');
            txt.append(el('span', 'block text-sm font-bold text-slate-800', ind.name), el('span', 'block text-[11px] text-slate-500 leading-relaxed', ind.desc));
            label.append(cb, txt);
            group.append(label);
        }
        box.append(group);
    }
    renderQuestions();
}

const SKILL_ORDER = (grade) => GRADES[grade].outcomes.flatMap((o) => o.indicators.map((i) => i.id));

function renderQuestions() {
    $('tbCount').textContent = draft.questions.length;
    const box = $('tbQuestions');
    box.replaceChildren();
    if (!draft.questions.length) box.append(el('p', 'text-sm text-slate-400 text-center py-6', draft.skills.length ? 'أضف سؤالاً لكل مهارة اخترتها.' : 'اختر المهارات أولاً، ثم أضف الأسئلة.'));
    const chosen = SKILL_ORDER(draft.grade).filter((id) => draft.skills.includes(id));
    draft.questions.forEach((q, i) => {
        const card = el('div', 'border border-slate-200 rounded-2xl p-4 space-y-3 bg-slate-50/50');
        const head = el('div', 'flex justify-between items-center');
        head.append(el('span', 'text-xs font-black text-slate-700', `سؤال ${i + 1}`), actionButton('حذف السؤال', 'remove-question', String(i), 'text-xs text-red-500 font-bold'));
        const selects = el('div', 'grid grid-cols-1 sm:grid-cols-3 gap-2');
        const skill = el('select', 'sm:col-span-2 px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs');
        skill.dataset.q = i; skill.dataset.f = 'skill';
        skill.add(new Option('— اختر مهارة السؤال —', ''));
        for (const id of chosen) skill.add(new Option(skillById(id).name, id));
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
    const chosen = SKILL_ORDER(draft.grade).filter((id) => draft.skills.includes(id));
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
    if (!draft.passage.trim()) return builderError('اكتب نص القراءة.');
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
    const skills = SKILL_ORDER(draft.grade).filter((id) => clean.some((q) => q.skill === id));
    await busy(button, async () => {
        const ref = draft.id ? doc(db, 'tests', draft.id) : doc(collection(db, 'tests'));
        const batch = writeBatch(db);
        batch.set(ref, {
            teacherUid: teacher.uid, title: draft.title.trim(), className: draft.className, grade: draft.grade,
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
    if (!s || !(await confirmDialog(`حذف الطالب «${s.name}» ونتائجه نهائياً؟`))) return;
    try {
        await deleteInBatches([doc(db, 'students', id), ...attempts.filter((a) => a.studentId === id).map((a) => doc(db, 'attempts', a.id))]);
        await Promise.all([loadStudents(), loadTeacherTests()]);
    } catch (err) { reportError(err); }
}

async function clearAllStudents() {
    const list = classStudents();
    if (!list.length) return;
    if (!(await confirmDialog(`حذف جميع طلاب فصل «${teacher.className}» (${list.length}) ونتائجهم نهائياً؟`))) return;
    try {
        const ids = new Set(list.map((s) => s.id));
        await deleteInBatches([...list.map((s) => doc(db, 'students', s.id)), ...attempts.filter((a) => ids.has(a.studentId)).map((a) => doc(db, 'attempts', a.id))]);
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
        info.append(el('p', 'font-bold text-slate-800', t.title), el('p', 'text-xs text-slate-500 mt-1', `${t.questions.length} سؤالاً`));
        row.append(info, t.done ? el('span', 'text-xs font-bold text-emerald-700', '✓ تم الإرسال')
            : actionButton('ابدأ الاختبار ➔', 'open-test', t.id, 'bg-teal-600 hover:bg-teal-700 text-white font-bold px-5 py-2.5 rounded-xl text-xs'));
        box.append(row);
    }
}

function openStudentTest(id) {
    openTest = studentTests.find((t) => t.id === id);
    if (!openTest || openTest.done) return;
    $('studentTestsView').classList.add('hidden');
    $('studentTestView').classList.remove('hidden');
    $('stTitle').textContent = openTest.title;
    $('stPassage').textContent = openTest.passage;
    const box = $('stQuestions');
    box.replaceChildren();
    openTest.questions.forEach((q, i) => {
        const card = el('div', 'p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-3');
        card.append(el('p', 'text-sm font-bold text-slate-800', `${i + 1}. ${q.text}`));
        const opts = el('div', 'grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm');
        q.options.forEach((o, j) => {
            const label = el('label', 'p-3 bg-white rounded-xl border border-slate-200 flex items-center gap-2 cursor-pointer hover:border-teal-500');
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
    $('testBuilder').addEventListener('input', builderInput);
    $('testBuilder').addEventListener('change', builderInput);

    document.addEventListener('click', (e) => {
        const el = e.target.closest('[data-action]');
        if (!el) return;
        const { action, id, tab, publish } = el.dataset;
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
            case 'new-test': openBuilder(null); break;
            case 'edit-test': openBuilder(tests.find((t) => t.id === id)); break;
            case 'cancel-test': closeBuilder(); break;
            case 'load-template': loadTemplate(); break;
            case 'add-question': addQuestion(); break;
            case 'remove-question': draft.questions.splice(Number(id), 1); renderQuestions(); break;
            case 'save-test': saveTest(el, publish === '1'); break;
            case 'toggle-publish': togglePublish(id); break;
            case 'delete-test': deleteTest(id); break;
            case 'student-detail': showStudentDetail(id); break;
            case 'close-student': $('studentModal').classList.add('hidden'); break;
            case 'open-test': openStudentTest(id); break;
            case 'back-to-tests': renderStudentTests(); break;
            case 'submit-test': submitTest(e); break;
            case 'student-logout': studentLogout(); break;
        }
    });
}

start();
