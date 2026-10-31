import test from 'node:test';
import assert from 'node:assert/strict';
import { computeMetrics, byType } from '../metrics.mjs';
import { parseCsv, toExpertRows } from '../csv.mjs';
import { validateResult } from '../prompts.mjs';

const run = (score, ms = 3000, cost = 0.001) => ({ score, ms, cost });
const row = (expert, s1, s2, extra = {}) => ({ image: 'x', type: 'bean', expert, runs: [run(s1), run(s2)], ...extra });

test('نسب الفرق والثبات ببيانات اصطناعية', () => {
  // 10 صور: 7 ضمن 10 عن الخبير، 9 ثابتة
  const rows = [];
  for (let i = 0; i < 7; i++) rows.push(row(80, 78, 82));      // فرق 0 ثبات 4
  for (let i = 0; i < 2; i++) rows.push(row(80, 60, 62));      // فرق 19 ثبات 2
  rows.push(row(80, 60, 70));                                   // فرق 15 ثبات 10
  const m = computeMetrics(rows);
  assert.equal(m.n, 10);
  assert.equal(m.criteria.expertDiff.value, 0.7);
  assert.equal(m.criteria.expertDiff.pass, true);
  assert.equal(m.criteria.stability.value, 0.9);
  assert.equal(m.criteria.stability.pass, true);
});

test('الحد: 69% يفشل', () => {
  const rows = [];
  for (let i = 0; i < 69; i++) rows.push(row(50, 50, 50));
  for (let i = 0; i < 31; i++) rows.push(row(50, 90, 90));
  assert.equal(computeMetrics(rows).criteria.expertDiff.pass, false);
});

test('التفريق بين ضعيفة وممتازة', () => {
  const good = [row(30, 35, 38, { expertClass: 'poor' }), row(95, 90, 92, { expertClass: 'excellent' })];
  assert.equal(computeMetrics(good).criteria.separation.pass, true);
  const bad = [row(30, 35, 91, { expertClass: 'poor' }), row(95, 90, 92, { expertClass: 'excellent' })];
  assert.equal(computeMetrics(bad).criteria.separation.pass, false);
  assert.equal(computeMetrics([row(50, 50, 50)]).criteria.separation.pass, null);
});

test('الملاحظات والزمن والتكلفة', () => {
  const rows = [row(50, 50, 50, { notesCorrect: 3 }), row(50, 50, 50, { notesCorrect: 1 })];
  rows[1].runs[0].ms = 12000;
  const m = computeMetrics(rows);
  assert.equal(m.criteria.notes.value, 4 / 6);
  assert.equal(m.criteria.notes.pass, false);
  assert.equal(m.criteria.latency.value, 0.75);
  assert.equal(m.criteria.latency.pass, false);
  assert.equal(m.criteria.latency.p90, 12);
  assert.ok(Math.abs(m.criteria.cost.perScan - 0.001) < 1e-12);
});

test('تشغيلات فاشلة تُستبعد، وغير المقاس ليس نجاحاً', () => {
  const m = computeMetrics([row(50, 50, 50), { image: 'y', type: 'bean', expert: 50, runs: [run(NaN), run(50)] }]);
  assert.equal(m.n, 1);
  assert.equal(m.skipped, 1);
  assert.equal(m.overallPass, false);
  assert.ok(m.unmeasured >= 1);
});

test('تقسيم حسب النوع', () => {
  const r = byType([row(50, 50, 50), { ...row(50, 90, 90), type: 'coffee' }]);
  assert.equal(r.bean.criteria.expertDiff.value, 1);
  assert.equal(r.coffee.criteria.expertDiff.value, 0);
});

test('CSV وصيغة المخرجات', () => {
  const rows = toExpertRows(parseCsv('image,type,expert_score,expert_class,notes_correct\n"a,b.jpg",bean,80,excellent,3\nc.jpg,coffee,40,,\n'));
  assert.equal(rows[0].image, 'a,b.jpg');
  assert.equal(rows[1].notesCorrect, undefined);
  assert.throws(() => toExpertRows(parseCsv('image,type,expert_score\nz.jpg,tea,50\n')));
  assert.throws(() => validateResult({ status: 'ok', score: 50, notes: ['a', 'b'] }));
  assert.ok(validateResult({ status: 'ok', score: 50, notes: ['a', 'b', 'c'] }));
});

const bean = (extra, r1, r2) => ({ image: 'b', type: 'bean', expert: undefined, runs: [{ score: 70, ms: 1000, cost: 0, ...r1 }, { score: 70, ms: 1000, cost: 0, ...(r2 ?? r1) }], ...extra });

test('مطابقة التحميص وكشف العيوب مقابل الوسوم (بلا خبير)', () => {
  const rows = [
    bean({ roastLabel: 'dark' }, { roast: 'dark' }),
    bean({ roastLabel: 'light' }, { roast: 'light' }, { roast: 'medium' }),
    bean({ roastLabel: 'medium' }, { roast: 'dark' }),
    bean({ defectLabel: 'defect' }, { hasDefects: true }),
    bean({ defectLabel: 'defect' }, { hasDefects: false }),
    bean({ defectLabel: 'ok' }, { hasDefects: false }),
    bean({ defectLabel: 'ok' }, { hasDefects: false }),
  ];
  const c = computeMetrics(rows).criteria;
  assert.equal(c.roast.n, 6);
  assert.equal(c.roast.value, 3 / 6);
  assert.equal(c.roast.pass, false);
  assert.equal(c.roast.confusion.light.medium, 1);
  assert.equal(c.defect.n, 8);
  assert.equal(c.defect.value, 6 / 8);
  assert.equal(c.defect.recall, 2 / 4);
  assert.equal(c.defect.specificity, 1);
  assert.equal(c.defect.pass, true);
  assert.equal(c.expertDiff.value, null); // لا خبير: غير مقاس وليس نجاحاً
  assert.equal(computeMetrics(rows).overallPass, false);
});

test('بلا وسوم: المعياران غير مقاسين ولا يمنعان الحكم', () => {
  const c = computeMetrics([row(50, 50, 50)]).criteria;
  assert.equal(c.roast.pass, null);
  assert.equal(c.defect.pass, null);
});

test('التفريق بفئة واضحة مفتوحة clearClass، والخبير يتقدم', () => {
  const rows = [row(undefined, 30, 32, { clearClass: 'poor' }), row(undefined, 90, 91, { clearClass: 'excellent' })];
  assert.equal(computeMetrics(rows).criteria.separation.pass, true);
  const mixed = [row(undefined, 30, 32, { clearClass: 'excellent', expertClass: 'poor' }), row(undefined, 90, 91, { clearClass: 'poor', expertClass: 'excellent' })];
  assert.equal(computeMetrics(mixed).criteria.separation.pass, true);
});

test('ثبات المشروب بلا خبير', () => {
  const m = computeMetrics([row(undefined, 70, 73), row(undefined, 60, 75)]);
  assert.equal(m.criteria.stability.value, 0.5);
  assert.equal(m.criteria.expertDiff.pass, null);
});

test('CSV مفتوح: expert_score فارغ والوسوم', () => {
  const rows = toExpertRows(parseCsv('image,type,expert_score,roast_label,defect_label,clear_class\na.png,bean,,dark,,\nb.png,bean,,,defect,\nc.jpg,coffee,,,,poor\n'));
  assert.equal(rows[0].expert, undefined);
  assert.equal(rows[0].roastLabel, 'dark');
  assert.equal(rows[1].defectLabel, 'defect');
  assert.equal(rows[2].clearClass, 'poor');
  assert.throws(() => toExpertRows(parseCsv('image,type,expert_score,roast_label\na.png,bean,,green\n')));
  assert.throws(() => toExpertRows(parseCsv('image,type,expert_score\na.png,bean,150\n')));
});

test('مخرجات roast_level/has_defects اختيارية لكن تُتحقق', () => {
  assert.ok(validateResult({ status: 'ok', score: 50, notes: ['a', 'b', 'c'], roast_level: 'dark', has_defects: false }));
  assert.throws(() => validateResult({ status: 'ok', score: 50, notes: ['a', 'b', 'c'], roast_level: 'burnt' }));
  assert.throws(() => validateResult({ status: 'ok', score: 50, notes: ['a', 'b', 'c'], has_defects: 'no' }));
});
