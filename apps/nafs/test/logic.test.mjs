import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseStudentRows, isCivilId, gradeAttempt, buildReport, masteryLevel, reportCsv, shuffleOptions, questionError } from '../src/logic.js';
import { canTransition, qualityIssues, usableInTest, isDuplicate, fromGeneration } from '../src/bank.js';
import { GRADES, SUBJECTS, gradeOfClass, skillById, groupsFor, skillIdsFor, subjectsOfGrade } from '../src/skills.js';
import { FORMS } from '../src/forms-data.js';
import { existsSync, statSync } from 'node:fs';
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

test('المواد: العلوم للسادس والتاسع فقط، ومعرّفات المهارات فريدة ومرتبطة بصفها ومادتها', () => {
    assert.deepEqual(subjectsOfGrade(3), ['reading', 'math']);
    assert.deepEqual(subjectsOfGrade(6), ['reading', 'math', 'science']);
    assert.deepEqual(Object.keys(SUBJECTS), ['reading', 'math', 'science']);
    const seen = new Set();
    for (const grade of [3, 6, 9]) {
        for (const subject of subjectsOfGrade(grade)) {
            const groups = groupsFor(subject, grade);
            assert.ok(groups.length > 0, `${subject} ${grade}`);
            for (const g of groups) {
                assert.ok(g.domain && g.outcomes.length, `${subject} ${grade} ${g.title}`);
                for (const sk of g.outcomes.flatMap((o) => o.skills)) {
                    assert.ok(sk.id && sk.name && sk.desc, sk.id);
                    assert.ok(!seen.has(sk.id), 'معرّف مكرر ' + sk.id);
                    seen.add(sk.id);
                    assert.equal(skillById(sk.id).grade, grade);
                    assert.equal(skillById(sk.id).subject, subject);
                }
            }
            assert.deepEqual(skillIdsFor(subject, grade), groups.flatMap((g) => g.outcomes.flatMap((o) => o.skills.map((sk) => sk.id))));
        }
    }
    assert.equal(skillIdsFor('math', 3).length, 45);
    assert.equal(skillIdsFor('math', 6).length, 81);
    assert.equal(skillIdsFor('math', 9).length, 95);
    assert.equal(skillIdsFor('science', 6).length, 110);
    assert.equal(skillIdsFor('science', 9).length, 159);
    assert.deepEqual(groupsFor('science', 3), []);
});

test('النماذج الجاهزة: ست رسمية وتدريبيان، كل سؤال مربوط بمهارة من صفه ومادته، وصوره موجودة', () => {
    assert.deepEqual(FORMS.map((f) => f.id), ['a3', 'b3', 'a6', 'b6', 'a9', 'b9', 't1', 't2']);
    assert.deepEqual(FORMS.map((f) => f.kind), ['official', 'official', 'official', 'official', 'official', 'official', 'training', 'training']);
    const expected = { a3: [13, 8], b3: [13, 8], a6: [28, 10], b6: [27, 10], a9: [26, 10], b9: [27, 10], t1: [12, 0], t2: [12, 0] };
    for (const f of FORMS) {
        const total = Object.values(f.subjects).reduce((n, qs) => n + qs.length, 0);
        assert.equal(total, expected[f.id][0], f.id);
        assert.equal((f.subjects.math ?? []).length, expected[f.id][1], f.id + ' math');
        if (f.kind === 'official') assert.equal(Boolean(f.subjects.science), f.grade !== 3, f.id + ' science');
        for (const [subject, qs] of Object.entries(f.subjects)) {
            let passages = 0;
            for (const q of qs) {
                const sk = skillById(q.skill);
                assert.ok(sk && sk.grade === f.grade && sk.subject === subject, `${f.id} q${q.n} ${q.skill}`);
                assert.ok(['know', 'apply', 'reason'].includes(q.level), `${f.id} q${q.n}`);
                assert.ok([0, 1, 2, 3].includes(q.answer), `${f.id} q${q.n}`);
                for (const img of [q.img, q.passage?.img].filter(Boolean)) {
                    const path = new URL('../public/' + img, import.meta.url);
                    assert.ok(existsSync(path) && statSync(path).size > 1000, img);
                }
                if (q.passage) passages++;
            }
            assert.equal(passages, subject === 'reading' ? 1 : 0, `${f.id} ${subject} passage`);
        }
    }
});

test('البنك: فحص الجودة والمسار والتوليد مع «غير منطبق»', () => {
    const good = { skill: '3-1.1', level: 'know', text: 'ما مرادف كلمة «سعيد» في الجملة السابقة؟', options: ['حزين', 'فرِح', 'غاضب', 'متعب'], answer: 1, explanation: 'سعيد بمعنى فرِح.' };
    assert.deepEqual(qualityIssues(good), []);
    assert.ok(qualityIssues({ ...good, options: ['أ', 'أ', 'ب', 'ج'] }).some((m) => m.includes('مكررة')));
    assert.ok(qualityIssues({ ...good, options: ['حزين', 'فرِح', 'كل ما سبق', 'متعب'] }).some((m) => m.includes('كل ما سبق')));
    assert.ok(qualityIssues({ ...good, explanation: '' }).length);
    assert.ok(qualityIssues({ ...good, skill: 'zzz' }).length);
    assert.ok(qualityIssues({ ...good, options: ['ص', 'فرِح بما حدث له اليوم في المدرسة مع أصدقائه الكثيرين', 'ع', 'ق'] }).some((m) => m.includes('تفاوت')));
    assert.ok(canTransition('generated', 'approved') && !canTransition('na', 'approved') && !canTransition('generated', 'generated'));
    assert.ok(usableInTest({ status: 'approved' }) && !usableInTest({ status: 'generated' }));
    assert.ok(isDuplicate(good, [{ ...good, text: ' ما مرادف  كلمة «سعيد» في الجملة السابقة؟ ' }]));
    const recs = fromGeneration('3-1.1', { know: { text: good.text, options: good.options, answer: 1, explanation: 'ش' }, apply: { applicable: false, reason: 'لا يناسب' } });
    assert.deepEqual(recs.map((r) => r.status), ['generated', 'na', 'na']);
    assert.equal(recs[1].reason, 'لا يناسب');
    assert.equal(recs[2].reason, 'لم يحدَّد سبب');
});

test('مسودات البنك الجاهزة: مؤشرات صحيحة، بلا ملاحظات جودة، ولكل مؤشر ثلاثة مستويات', () => {
    for (const [file, subject, grade] of [['reading-3', 'reading', 3], ['reading-6', 'reading', 6], ['reading-9', 'reading', 9]]) {
        const rows = JSON.parse(readFileSync(new URL(`../public/bank-drafts/${file}.json`, import.meta.url), 'utf8'));
        for (const r of rows) {
            assert.equal(skillById(r.skill)?.grade, grade, r.skill);
            assert.equal(skillById(r.skill)?.subject, subject, r.skill);
            if (r.applicable === false) assert.ok(r.reason, r.skill);
            else assert.deepEqual(qualityIssues(r), [], `${r.skill} ${r.level}`);
        }
        for (const id of skillIdsFor(subject, grade)) assert.deepEqual(rows.filter((r) => r.skill === id).map((r) => r.level).sort(), ['apply', 'know', 'reason'], id);
    }
});

test('بنك نافس الرسمي: كل سؤال بمؤشر صحيح وصورة موجودة ومفتاح 0-3', () => {
    for (const [key, subject, grade] of [['math3', 'math', 3], ['math6', 'math', 6], ['math9', 'math', 9], ['science6', 'science', 6], ['science9', 'science', 9], ['reading3', 'reading', 3], ['reading6', 'reading', 6], ['reading9', 'reading', 9]]) {
        const items = JSON.parse(readFileSync(new URL(`../public/bank-official/${key}.json`, import.meta.url), 'utf8'));
        assert.ok(items.length > 30, key);
        const ids = new Set();
        for (const q of items) {
            assert.ok(!ids.has(q.id), q.id); ids.add(q.id);
            const sk = skillById(q.skill);
            assert.ok(sk && sk.grade === grade && sk.subject === subject, `${q.id} ${q.skill}`);
            assert.ok(['know', 'apply', 'reason'].includes(q.level), q.id);
            assert.ok([0, 1, 2, 3].includes(q.answer), q.id);
            assert.ok(existsSync(new URL(`../public/bank-official/${q.img}`, import.meta.url)), q.img);
            if (q.passage) assert.ok(existsSync(new URL(`../public/bank-official/${q.passage}`, import.meta.url)), q.passage);
        }
    }
});

test('الاختبارات المحاكية: مؤشرات صحيحة وصور موجودة ومفاتيح 0-3', () => {
    const mocks = JSON.parse(readFileSync(new URL('../public/bank-official/mocks.json', import.meta.url), 'utf8'));
    assert.equal(mocks.length, 6);
    let n = 0;
    for (const m of mocks) {
        for (const [subject, qs] of Object.entries(m.subjects)) {
            for (const q of qs) {
                n++;
                const sk = skillById(q.skill);
                assert.ok(sk && sk.grade === m.grade && sk.subject === subject, `${m.id} ${q.skill}`);
                assert.ok(['know', 'apply', 'reason'].includes(q.level) && [0, 1, 2, 3].includes(q.answer), m.id);
                for (const f of [q.img, q.passage].filter(Boolean)) assert.ok(existsSync(new URL(`../public/bank-official/${f}`, import.meta.url)), f);
            }
        }
    }
    assert.ok(n > 280, String(n));
});

test('نماذج حلّها الموقع: مؤشرات صحيحة وصور موجودة ومفاتيح 0-3', () => {
    const forms = JSON.parse(readFileSync(new URL('../public/bank-official/solved.json', import.meta.url), 'utf8'));
    assert.ok(forms.length >= 5);
    for (const m of forms) {
        for (const [subject, qs] of Object.entries(m.subjects)) {
            for (const q of qs) {
                const sk = skillById(q.skill);
                assert.ok(sk && sk.grade === m.grade && sk.subject === subject, `${m.id} ${q.skill}`);
                assert.ok(['know', 'apply', 'reason'].includes(q.level) && [0, 1, 2, 3].includes(q.answer), m.id);
                for (const f of [q.img, q.passage].filter(Boolean)) assert.ok(existsSync(new URL(`../public/bank-official/${f}`, import.meta.url)), f);
            }
        }
    }
});
