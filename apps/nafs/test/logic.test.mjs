import test from 'node:test';
import assert from 'node:assert/strict';
import { parseStudentRows, scoreQuiz, summarize, reportCsv, isCivilId } from '../src/logic.js';

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

test('scoreQuiz', () => {
    assert.equal(scoreQuiz(['correct', 'correct']), 100);
    assert.equal(scoreQuiz(['correct', 'wrong']), 50);
    assert.equal(scoreQuiz(['wrong', 'wrong']), 0);
});

test('summarize يحسب المتوسط من المنجزين فقط', () => {
    assert.deepEqual(summarize([{ score: 100 }, { score: 50 }, {}]), { total: 3, completed: 2, avg: 75 });
    assert.deepEqual(summarize([]), { total: 0, completed: 0, avg: 0 });
});

test('reportCsv يهرّب علامات التنصيص', () => {
    const csv = reportCsv([{ name: 'a"b', id: '1234567890', score: 50 }, { name: 'c', id: '2234567890' }]);
    assert.ok(csv.includes('"a""b","1234567890","50%","منجز"'));
    assert.ok(csv.includes('"c","2234567890","غير مختبر","بانتظار الاختبار"'));
});

test('isCivilId', () => {
    assert.ok(isCivilId('1234567890'));
    assert.ok(!isCivilId('123456789'));
    assert.ok(!isCivilId('12345678901'));
    assert.ok(!isCivilId('12345a7890'));
});
