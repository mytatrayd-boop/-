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
