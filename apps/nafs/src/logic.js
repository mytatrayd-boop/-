// منطق لا يعتمد على المتصفح ولا على Firebase — مختبر في test/logic.test.mjs.

export const CLASSES = [
    'الثالث الابتدائي - أ', 'الثالث الابتدائي - ب', 'الثالث الابتدائي - ج',
    'السادس الابتدائي - أ', 'السادس الابتدائي - ب', 'السادس الابتدائي - ج',
    'الثالث المتوسط - أ', 'الثالث المتوسط - ب', 'الثالث المتوسط - ج',
];

export const MAX_UPLOAD_BYTES = 700 * 1024;

export const isCivilId = (v) => /^\d{10}$/.test(v);

// صفوف الأكسل (مصفوفة مصفوفات) → [{name, id}]. العمودان بأي ترتيب، وتُتجاوز العناوين والصفوف الناقصة والمكرر.
export function parseStudentRows(rows) {
    const out = [];
    const seen = new Set();
    for (const row of rows) {
        if (!row || row.length < 2) continue;
        const a = String(row[0] ?? '').trim();
        const b = String(row[1] ?? '').trim();
        let name, id;
        if (isCivilId(b)) { name = a; id = b; }
        else if (isCivilId(a)) { id = a; name = b; }
        else continue;
        name = name.slice(0, 100);
        if (!name || seen.has(id)) continue;
        seen.add(id);
        out.push({ name, id });
    }
    return out;
}

// ---------- الاختبارات والتقارير ----------

const pctOf = ({ c, t }) => (t ? Math.round((c / t) * 100) : null);
const add = (map, key, ok) => {
    const e = (map[key] ??= { c: 0, t: 0 });
    e.t++;
    if (ok) e.c++;
};

// تصحيح محاولة: questions [{skill, level}], key [رقم الإجابة الصحيحة], answers [رقم اختيار الطالب]
export function gradeAttempt(questions, key, answers) {
    const skills = {}, levels = {};
    let c = 0;
    questions.forEach((q, i) => {
        const ok = answers[i] === key[i];
        if (ok) c++;
        add(skills, q.skill, ok);
        add(levels, q.level, ok);
    });
    return { c, t: questions.length, pct: pctOf({ c, t: questions.length }), skills, levels };
}

export function masteryLevel(pct) {
    if (pct === null || pct === undefined) return { label: 'لم يُختبر', tone: 'none' };
    if (pct >= 80) return { label: 'متقن', tone: 'good' };
    if (pct >= 50) return { label: 'قريب من الإتقان', tone: 'mid' };
    return { label: 'يحتاج دعمًا', tone: 'low' };
}

const merge = (into, from) => {
    for (const [k, v] of Object.entries(from)) {
        const e = (into[k] ??= { c: 0, t: 0 });
        e.c += v.c;
        e.t += v.t;
    }
};
const withPct = (map) => Object.fromEntries(Object.entries(map).map(([k, v]) => [k, { ...v, pct: pctOf(v) }]));

// attempts: [{studentId, testId, answers, submittedAt (ms)}]، tests: {id: {title, questions}}، keys: {id: [..]}
// → إحصاءات كل طالب، وإحصاءات الفصل لكل مهارة ومستوى.
export function buildReport(students, attempts, tests, keys) {
    const byStudent = {};
    const classSkills = {}, classLevels = {};
    for (const s of students) byStudent[s.id] = { id: s.id, name: s.name, history: [], skills: {}, levels: {}, c: 0, t: 0 };
    for (const a of attempts) {
        const st = byStudent[a.studentId];
        const test = tests[a.testId];
        const key = keys[a.testId];
        if (!st || !test || !key) continue;
        const g = gradeAttempt(test.questions, key, a.answers);
        st.history.push({ testId: a.testId, title: test.title, at: a.submittedAt, pct: g.pct });
        merge(st.skills, g.skills);
        merge(st.levels, g.levels);
        merge(classSkills, g.skills);
        merge(classLevels, g.levels);
        st.c += g.c;
        st.t += g.t;
    }
    const list = Object.values(byStudent).map((st) => {
        st.history.sort((x, y) => x.at - y.at);
        const skills = withPct(st.skills);
        const tested = Object.entries(skills);
        const weakest = tested.length ? tested.reduce((w, cur) => (cur[1].pct < w[1].pct ? cur : w))[0] : null;
        const h = st.history;
        return {
            ...st, skills, levels: withPct(st.levels), pct: pctOf(st), weakest,
            progress: h.length >= 2 ? h[h.length - 1].pct - h[0].pct : null,
        };
    });
    const done = list.filter((s) => s.pct !== null);
    return {
        students: list,
        skills: withPct(classSkills),
        levels: withPct(classLevels),
        tested: done.length,
        avg: done.length ? Math.round(done.reduce((sum, s) => sum + s.pct, 0) / done.length) : null,
    };
}

const csvCell = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;

// skillName(id) → اسم المهارة
export function reportCsv(report, skillIds, skillName) {
    const head = ['اسم الطالب', 'السجل المدني', 'عدد الاختبارات', 'النسبة العامة', 'المستوى', 'التقدم', ...skillIds.map(skillName)];
    let csv = '﻿' + head.map(csvCell).join(',') + '\n';
    for (const s of report.students) {
        csv += [
            s.name, s.id, s.history.length, s.pct === null ? '' : s.pct + '%', masteryLevel(s.pct).label,
            s.progress === null ? '' : (s.progress > 0 ? '+' : '') + s.progress + '%',
            ...skillIds.map((id) => (s.skills[id] ? s.skills[id].pct + '%' : '')),
        ].map(csvCell).join(',') + '\n';
    }
    return csv;
}

export function shuffleOptions(question, rand = Math.random) {
    const order = question.options.map((_, i) => i);
    for (let i = order.length - 1; i > 0; i--) {
        const j = Math.floor(rand() * (i + 1));
        [order[i], order[j]] = [order[j], order[i]];
    }
    return { ...question, options: order.map((i) => question.options[i]), answer: order.indexOf(question.answer) };
}

// يتحقق من سؤال قبل الحفظ؛ يرجع نص الخطأ أو null
export function questionError(q, allowedSkills) {
    if (!q.text.trim()) return 'اكتب نص السؤال.';
    if (!allowedSkills.includes(q.skill)) return 'اختر مهارة السؤال.';
    const filled = q.options.filter((o) => o.trim());
    if (filled.length < 2) return 'اكتب خيارين على الأقل.';
    if (!q.options[q.answer]?.trim()) return 'حدّد الإجابة الصحيحة.';
    return null;
}
