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

export function scoreQuiz(answers) {
    return answers.filter((a) => a === 'correct').length * Math.round(100 / answers.length);
}

export function summarize(students) {
    const done = students.filter((s) => typeof s.score === 'number');
    const avg = done.length ? Math.round(done.reduce((sum, s) => sum + s.score, 0) / done.length) : 0;
    return { total: students.length, completed: done.length, avg };
}

const csvCell = (v) => `"${String(v).replace(/"/g, '""')}"`;

export function reportCsv(students) {
    let csv = '﻿اسم الطالب,السجل المدني,نسبة الإتقان,الحالة\n';
    for (const s of students) {
        const done = typeof s.score === 'number';
        csv += [s.name, s.id, done ? s.score + '%' : 'غير مختبر', done ? 'منجز' : 'بانتظار الاختبار'].map(csvCell).join(',') + '\n';
    }
    return csv;
}
