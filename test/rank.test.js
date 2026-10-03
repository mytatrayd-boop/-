import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTop5, rankSymbols, oosCheck, shrink, WEIGHTS } from '../lab/rank.mjs';
import { renderReport } from '../lab/report.mjs';

// أسابيع اصطناعية: الاثنين من 2026-01-05 فصاعدًا
const wk = (i) => new Date(Date.UTC(2026, 0, 5) + i * 7 * 86400000).toISOString().slice(0, 10);

// rsBySym: { SYM: [r للأسبوع 0, r للأسبوع 1, …] } — null = لا صفقة ذلك الأسبوع
function makeBt(rsBySym, nWeeks) {
  const trades = [];
  for (const [sym, rs] of Object.entries(rsBySym)) {
    rs.forEach((r, i) => {
      if (r === null || r === undefined) return;
      trades.push({ sym, weekKey: wk(i), entryT: 0, entry: 100, stop: 99, target: 102, exitT: 0, exit: 100 + r, how: 'friday', r, pct: r / 100, shares: 10, pnl: r * 10 });
    });
  }
  const n = nWeeks ?? Math.max(...Object.values(rsBySym).map((a) => a.length));
  let eq = 10000;
  const weeks = Array.from({ length: n }, (_, i) => {
    const tw = trades.filter((t) => t.weekKey === wk(i));
    const pnl = tw.reduce((s, t) => s + t.pnl, 0);
    eq += pnl;
    return { weekKey: wk(i), trades: tw.length, wins: tw.filter((t) => t.r > 0).length, pnl, equityEnd: eq, returnPct: (pnl / (eq - pnl)) * 100 };
  });
  return {
    generatedAt: '2026-03-01T00:00:00Z', source: 'yahoo', dataFrom: wk(0), dataTo: wk(n - 1), params: {},
    universe: Object.keys(rsBySym), weeks, trades, perSymbol: {},
    account: { start: 10000, end: eq, returnPct: (eq / 10000 - 1) * 100, maxDrawdownPct: 1.2, trades: trades.length, winRate: 0.5, avgR: 0.1, profitFactor: 1.3 },
  };
}

test('weights sum to 1 and shrink formula', () => {
  assert.ok(Math.abs(Object.values(WEIGHTS).reduce((s, x) => s + x, 0) - 1) < 1e-12);
  assert.equal(shrink(4, 1, 4, 0), 0.5);
  assert.ok(Math.abs(shrink(0, 9, 3, 0.2) - 0.2) < 1e-12);
});

test('min-trades filter: symbols below minTrades are not in top', () => {
  const bt = makeBt({ AAA: [1, 1, 1], BBB: [0.5, -1, 0.5, 0.5, 0.5], CCC: [0.2, 0.2, -1, 0.2] });
  const out = buildTop5(bt, { minTrades: 4 });
  const syms = out.top.map((t) => t.sym);
  assert.ok(!syms.includes('AAA'));
  assert.deepEqual(syms.sort(), ['BBB', 'CCC']);
  assert.equal(out.all.length, 3);
  assert.equal(out.all.find((r) => r.sym === 'AAA').eligible, false);
  assert.equal(out.minTrades, 4);
  const out2 = buildTop5(bt, { minTrades: 3 });
  assert.ok(out2.top.some((t) => t.sym === 'AAA'));
});

test('shrinkage: one lucky +3R trade does not win even with minTrades = 1', () => {
  const steady = [0.6, 0.8, -1, 0.7, 0.6, 0.9, -1, 0.8, 0.6, 0.7];
  const bt = makeBt({
    LUCK: [3],
    GOOD: steady,
    MID1: [0.1, -1, 0.2, 0.3, -1, 0.1, 0.2, -1, 0.3, 0.1],
    MID2: [-1, 0.2, 0.1, -1, 0.4, 0.1, -1, 0.2, 0.1, 0.3],
  }, 10);
  const out = buildTop5(bt, { minTrades: 1 });
  assert.equal(out.top[0].sym, 'GOOD');
  assert.ok(out.top.findIndex((t) => t.sym === 'LUCK') > 0);
  // متوسط R المنكمش للمحظوظ أقرب للكون من قيمته الخام
  const luck = out.all.find((r) => r.sym === 'LUCK');
  assert.ok(luck.shrunkAvgR < 1.5 && luck.avgR === 3);
});

test('deterministic tie-breaking: identical records sort by symbol regardless of input order', () => {
  const rs = [0.5, -1, 0.5, 0.5, 1];
  const a = buildTop5(makeBt({ ZED: rs, ALF: rs, MOO: rs }));
  const b = buildTop5(makeBt({ MOO: rs, ZED: rs, ALF: rs }));
  assert.deepEqual(a.top.map((t) => t.sym), ['ALF', 'MOO', 'ZED']);
  assert.deepEqual(b.top.map((t) => t.sym), a.top.map((t) => t.sym));
  assert.equal(a.top[0].score, a.top[2].score);
});

test('OOS split ranks on older weeks only', () => {
  // OLD يربح في النصف الأقدم ويخسر في الأحدث؛ NEW العكس
  const OLD = [1, 1, 1, 1, -1, -1, -1, -1];
  const NEW = [-1, -1, -1, -1, 1.5, 1.5, 1.5, 1.5];
  const FLAT = [0, 0, 0, 0, 0, 0, 0, 0];
  const bt = makeBt({ OLD, NEW, FLAT });
  const o = oosCheck(bt, { minTrades: 4, topN: 1 });
  assert.equal(o.olderWeeks, 4);
  assert.equal(o.newerWeeks, 4);
  assert.equal(o.newerFrom, wk(4));
  assert.equal(o.picks[0].sym, 'OLD');
  assert.equal(o.picks[0].olderTrades, 4);
  assert.equal(o.picks[0].avgR, -1);
  assert.equal(o.heldUp, false);
  assert.equal(o.beatUniverse, false);
  // تغيير النصف الأحدث لا يغيّر ترتيب الأقدم
  const bt2 = makeBt({ OLD, NEW: [-1, -1, -1, -1, 3, 3, 3, 3], FLAT });
  const ranked1 = rankSymbols(bt, { weeks: [wk(0), wk(1), wk(2), wk(3)] }).rows.map((r) => [r.sym, r.score]);
  const ranked2 = rankSymbols(bt2, { weeks: [wk(0), wk(1), wk(2), wk(3)] }).rows.map((r) => [r.sym, r.score]);
  assert.deepEqual(ranked1, ranked2);
  // ويظهر في top5.json
  const out = buildTop5(bt, { minTrades: 4 });
  assert.ok(out.oosSummary.available);
  assert.ok(out.top.every((t) => typeof t.oos.trades === 'number' && typeof t.oos.avgR === 'number'));
});

test('fewer than 5 eligible: outputs what qualifies and says so', () => {
  const bt = makeBt({ A: [1, -1, 1, 1], B: [0.5, 0.5, -1, 0.5], C: [1], D: [] }, 4);
  const out = buildTop5(bt, { minTrades: 4 });
  assert.equal(out.top.length, 2);
  assert.equal(out.eligibleCount, 2);
  assert.match(out.method, /المؤهَّل 2 فقط/);
  assert.equal(out.all.length, 4);
  assert.ok(out.top.every((t) => /صفقات، متوسط/.test(t.why)));
});

test('why sentence matches example shape', () => {
  const out = buildTop5(makeBt({ X: [1, 0.5, -1, 1, 0.8, -1, 0.5, 1] }), { minTrades: 4 });
  assert.equal(out.top[0].why, '8 صفقات، متوسط +0.35R، ربحت 6 أسابيع من 8');
});

test('report renders weekly table with no undefined / NaN', () => {
  const bt = makeBt({ A: [1, -1, 1, 1, 0.5, -1], B: [0.5, 0.5, -1, 0.5, null, 1], C: [1] });
  const top5 = buildTop5(bt, { minTrades: 4 });
  const md = renderReport({ backtest: bt, top5, sweep: { walkForward: { folds: 3, oosAvgR: 0.12, note: 'ثابت نسبيًا' } } });
  assert.match(md, /\| الأسبوع \| الصفقات \| الرابحة \|/);
  for (let i = 0; i < 6; i++) assert.ok(md.includes(`| ${wk(i)} |`), 'week row ' + i);
  assert.ok(!/undefined|NaN/.test(md));
  assert.ok(!/[٠-٩]/.test(md), 'Western digits only');
  assert.match(md, /ليس نصيحة مالية/);
  assert.match(md, /walk-forward/);
  // ملفات ناقصة أو فارغة لا تُظهر undefined
  const empty = renderReport({ backtest: {}, top5: {} });
  assert.ok(!/undefined|NaN/.test(empty));
});
