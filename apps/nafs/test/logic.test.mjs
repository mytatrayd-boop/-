import test from 'node:test';
import assert from 'node:assert/strict';
import { parseStudentRows, isCivilId, gradeAttempt, buildReport, masteryLevel, reportCsv, shuffleOptions, questionError } from '../src/logic.js';
import { GRADES, gradeOfClass, skillById } from '../src/skills.js';
import { TEMPLATES } from '../src/templates.js';

test('parseStudentRows: يقبل العمودين بأي ترتيب ويتجاوز العنوان والناقص والمكرر', () => {
    const rows = [
        ['اسم الطالب', 'رقم السجل المدني'],
        ['سعد علي', 1234567890],
        ['2234567890', 'فهد محمد'],
        ['ناقص'],
        ['رقم قصير', '12345'],
        ['مكرر', '1234567890'],
        ['', '3234567890'],
    ];
    assert.deepEqual(parseStudentRows(rows), [
        { name: 'سعد علي', id: '1234567890' },
        { name: 'فهد محمد', id: '2234567890' },
    ]);
});

const Q = [{ skill: 'a', level: 'know' }, { skill: 'a', level: 'apply' }, { skill: 'b', level: 'know' }];

test('gradeAttempt يحسب الإجمالي ولكل مهارة ومستوى', () => {
    const g = gradeAttempt(Q, [0, 1, 2], [0, 0, 2]);
    assert.equal(g.pct, 67);
    assert.deepEqual(g.skills, { a: { c: 1, t: 2 }, b: { c: 1, t: 1 } });
    assert.deepEqual(g.levels, { know: { c: 2, t: 2 }, apply: { c: 0, t: 1 } });
});

test('buildReport: تاريخ الطالب وتقدّمه وأضعف مهارة ومتوسط الفصل', () => {
    const tests = { t1: { title: 'أ', questions: Q }, t2: { title: 'ب', questions: Q } };
    const keys = { t1: [0, 0, 0], t2: [0, 0, 0] };
    const r = buildReport(
        [{ id: 's1', name: 'سعد' }, { id: 's2', name: 'فهد' }],
        [
            { studentId: 's1', testId: 't2', answers: [0, 0, 0], submittedAt: 200 },
            { studentId: 's1', testId: 't1', answers: [0, 1, 1], submittedAt: 100 },
            { studentId: 'ghost', testId: 't1', answers: [0, 0, 0], submittedAt: 100 },
        ],
        tests, keys,
    );
    const s1 = r.students.find((s) => s.id === 's1');
    assert.deepEqual(s1.history.map((h) => h.pct), [33, 100]);
    assert.equal(s1.progress, 67);
    assert.equal(s1.pct, 67);
    assert.equal(s1.weakest, 'b');
    assert.equal(r.students.find((s) => s.id === 's2').pct, null);
    assert.equal(r.tested, 1);
    assert.equal(r.avg, 67);
    assert.deepEqual(r.skills.a, { c: 3, t: 4, pct: 75 });
});

test('masteryLevel', () => {
    assert.equal(masteryLevel(80).label, 'متقن');
    assert.equal(masteryLevel(50).label, 'قريب من الإتقان');
    assert.equal(masteryLevel(49).label, 'يحتاج دعمًا');
    assert.equal(masteryLevel(null).label, 'لم يُختبر');
});

test('reportCsv يهرّب علامات التنصيص ويضيف أعمدة المهارات', () => {
    const r = buildReport([{ id: '1234567890', name: 'a"b' }], [{ studentId: '1234567890', testId: 't', answers: [0, 0, 0], submittedAt: 1 }],
        { t: { title: 'x', questions: Q } }, { t: [0, 0, 0] });
    const csv = reportCsv(r, ['a', 'b'], (id) => 'مهارة ' + id);
    assert.ok(csv.includes('"مهارة a","مهارة b"'));
    assert.ok(csv.includes('"a""b","1234567890","1","100%","متقن","","100%","100%"'));
});

test('shuffleOptions يحافظ على الإجابة الصحيحة', () => {
    for (let k = 0; k < 20; k++) {
        const s = shuffleOptions({ options: ['ص', 'خ1', 'خ2', 'خ3'], answer: 0 });
        assert.equal(s.options[s.answer], 'ص');
        assert.equal(new Set(s.options).size, 4);
    }
});

test('questionError', () => {
    const ok = { text: 'س', skill: 'a', options: ['1', '2', '', ''], answer: 1 };
    assert.equal(questionError(ok, ['a']), null);
    assert.match(questionError({ ...ok, text: ' ' }, ['a']), /نص السؤال/);
    assert.match(questionError(ok, ['b']), /مهارة/);
    assert.match(questionError({ ...ok, options: ['1', '', '', ''] }, ['a']), /خيارين/);
    assert.match(questionError({ ...ok, answer: 2 }, ['a']), /الإجابة الصحيحة/);
});

test('المهارات: الصفوف الثلاثة من الوثيقة، والتاسع = الثالث المتوسط', () => {
    assert.deepEqual(Object.keys(GRADES), ['3', '6', '9']);
    for (const g of Object.values(GRADES)) assert.equal(g.outcomes.length, 3);
    assert.equal(GRADES[3].outcomes.flatMap((o) => o.indicators).length, 13);
    assert.equal(GRADES[6].outcomes.flatMap((o) => o.indicators).length, 14);
    assert.equal(GRADES[9].outcomes.flatMap((o) => o.indicators).length, 16);
    assert.equal(gradeOfClass('الثالث المتوسط - ب'), 9);
    assert.equal(gradeOfClass('السادس الابتدائي - أ'), 6);
    assert.equal(gradeOfClass('الثالث الابتدائي - ج'), 3);
});

test('النماذج الجاهزة: كل سؤال مربوط بمهارة من صفه وإجابته صحيحة', () => {
    for (const [grade, t] of Object.entries(TEMPLATES)) {
        assert.ok(t.passage.length > 200);
        for (const q of t.questions) {
            assert.equal(skillById(q.skill)?.grade, Number(grade), q.skill);
            assert.equal(questionError(q, [q.skill]), null, q.text);
            assert.equal(q.options.length, 4);
        }
    }
});

test('isCivilId', () => {
    assert.ok(isCivilId('1234567890'));
    assert.ok(!isCivilId('123456789'));
    assert.ok(!isCivilId('12345678901'));
    assert.ok(!isCivilId('12345a7890'));
});
