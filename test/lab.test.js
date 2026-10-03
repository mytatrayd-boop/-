import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseYahooChart, parseMassiveAggs, isRegularSession, etClock, mergeBars, dateChunks, adjustmentChanged, sliceFrom } from '../lab/fetch.mjs';
import { runBacktest, runAccount, simulateSignals, positionSize, gridCombos, walkForwardSplit, pickBest, runSweep } from '../lab/backtest.mjs';

const M = 60000;
// 2026-03-06 جمعة (EST = UTC-5)، 2026-03-09 إثنين بعد بدء التوقيت الصيفي (EDT = UTC-4)
const FRI_OPEN = Date.UTC(2026, 2, 6, 14, 30);
const MON_OPEN = Date.UTC(2026, 2, 9, 13, 30);

/* ---------- الجلسة العادية + التوقيت الصيفي ---------- */

test('isRegularSession follows New York time across DST', () => {
  assert.equal(isRegularSession(FRI_OPEN), true);              // 09:30 EST
  assert.equal(isRegularSession(FRI_OPEN - 5 * M), false);     // 09:25 ما قبل السوق
  assert.equal(isRegularSession(Date.UTC(2026, 2, 6, 13, 30)), false); // 08:30 EST
  assert.equal(isRegularSession(Date.UTC(2026, 2, 6, 20, 55)), true);  // 15:55 EST آخر شمعة
  assert.equal(isRegularSession(Date.UTC(2026, 2, 6, 21, 0)), false);  // 16:00 بعد السوق
  assert.equal(isRegularSession(MON_OPEN), true);              // 09:30 EDT
  assert.equal(isRegularSession(Date.UTC(2026, 2, 9, 19, 55)), true);  // 15:55 EDT
  assert.equal(isRegularSession(Date.UTC(2026, 2, 9, 20, 0)), false);  // 16:00 EDT
  assert.equal(isRegularSession(Date.UTC(2026, 2, 9, 20, 55)), false); // 16:55 EDT (كانت 15:55 قبل الصيفي)
  assert.equal(isRegularSession(Date.UTC(2026, 10, 2, 14, 30)), true);  // 2026-11-02 إثنين بعد نهاية الصيفي: 09:30 EST
  assert.equal(isRegularSession(Date.UTC(2026, 10, 2, 13, 30)), false); // 08:30 EST
  assert.equal(isRegularSession(Date.UTC(2026, 2, 7, 15, 0)), false);   // سبت
  assert.equal(isRegularSession(NaN), false);
  assert.deepEqual(etClock(MON_OPEN), { date: '2026-03-09', weekday: 1, minutes: 570 });
});

/* ---------- تحليل Yahoo ---------- */

test('parseYahooChart keeps regular-session bars and drops nulls, pre/post and the live tick', () => {
  const s = ms => ms / 1000;
  const ts = [FRI_OPEN - 5 * M, FRI_OPEN, FRI_OPEN + 5 * M, Date.UTC(2026, 2, 6, 20, 55), Date.UTC(2026, 2, 6, 21, 0), Date.UTC(2026, 2, 6, 20, 59, 58)].map(s);
  const payload = { chart: { error: null, result: [{ meta: { symbol: 'AAPL' }, timestamp: ts, indicators: { quote: [{
    open:   [99, 100, null, 104, 105, 104.5],
    high:   [99, 101, null, 105, 106, 104.6],
    low:    [98, 99.5, null, 103, 104, 104.4],
    close:  [99, 100.5, null, 104.5, 105.5, 104.5],
    volume: [10, 1000, null, 2000, 50, 1],
  }] } }] } };
  const bars = parseYahooChart(payload);
  assert.deepEqual(bars, { t: [FRI_OPEN, Date.UTC(2026, 2, 6, 20, 55)], o: [100, 104], h: [101, 105], l: [99.5, 103], c: [100.5, 104.5], v: [1000, 2000] });
  assert.throws(() => parseYahooChart({ chart: { result: null, error: { code: 'Not Found', description: 'No data found' } } }), e => e.code === 'yahoo_error');
  assert.throws(() => parseYahooChart({ foo: 1 }), e => e.code === 'bad_shape');
  assert.deepEqual(parseYahooChart({ chart: { result: [{ timestamp: null, indicators: { quote: [{}] } }] } }).t, []);
});

/* ---------- تحليل Massive ---------- */

test('parseMassiveAggs keeps regular-session bars, drops broken rows and returns next_url', () => {
  const pre = MON_OPEN - 90 * M, post = Date.UTC(2026, 2, 9, 20, 30);
  const { bars, next } = parseMassiveAggs({ ticker: 'NVDA', status: 'OK', adjusted: true, resultsCount: 5, next_url: 'https://api.polygon.io/v2/aggs/next?cursor=x', results: [
    { t: MON_OPEN + 5 * M, o: 11, h: 12, l: 10.5, c: 11.5, v: 200, vw: 11, n: 3 },
    { t: MON_OPEN, o: 10, h: 11, l: 9.5, c: 10.5, v: 100 },
    { t: pre, o: 9, h: 9, l: 9, c: 9, v: 1 },
    { t: post, o: 12, h: 12, l: 12, c: 12, v: 1 },
    { t: MON_OPEN + 10 * M, o: 11, h: 12, l: 10, c: null, v: 5 },
  ] });
  assert.deepEqual(bars, { t: [MON_OPEN, MON_OPEN + 5 * M], o: [10, 11], h: [11, 12], l: [9.5, 10.5], c: [10.5, 11.5], v: [100, 200] });
  assert.equal(next, 'https://api.polygon.io/v2/aggs/next?cursor=x');
  assert.deepEqual(parseMassiveAggs({ status: 'OK', resultsCount: 0 }), { bars: { t: [], o: [], h: [], l: [], c: [], v: [] }, next: null });
  assert.throws(() => parseMassiveAggs({ status: 'ERROR', error: "You've exceeded the maximum requests per minute" }), e => e.code === 'rate_limited');
  assert.throws(() => parseMassiveAggs({ status: 'NOT_AUTHORIZED', message: "Your plan doesn't include this data timeframe" }), e => e.code === 'not_authorized');
  assert.throws(() => parseMassiveAggs({ foo: 1 }), e => e.code === 'bad_shape');
});

test('fetch helpers: merge, date chunks, adjustment check, history slice', () => {
  const a = { t: [3, 1], o: [3, 1], h: [3, 1], l: [3, 1], c: [3, 1], v: [3, 1] };
  const b = { t: [2, 3], o: [2, 30], h: [2, 30], l: [2, 30], c: [2, 30], v: [2, 30] };
  assert.deepEqual(mergeBars(a, b).t, [1, 2, 3]);
  assert.equal(mergeBars(a, b).c[2], 30); // الأحدث يغلب
  assert.equal(adjustmentChanged(a, b), true);
  assert.equal(adjustmentChanged(a, { ...a }), false);
  assert.deepEqual(sliceFrom(mergeBars(a, b), 2).t, [2, 3]);
  assert.deepEqual(sliceFrom(mergeBars(a, b), 9).t, []);
  const ch = dateChunks(Date.UTC(2024, 9, 3), Date.UTC(2026, 9, 3), 240);
  assert.equal(ch[0][0], '2024-10-03');
  assert.equal(ch[ch.length - 1][1], '2026-10-03');
  for (let i = 1; i < ch.length; i++) assert.equal(Date.parse(ch[i][0]) - Date.parse(ch[i - 1][1]), 86400000); // بدون فجوات أو تداخل
  for (const [f, t] of ch) assert.ok((Date.parse(t) - Date.parse(f)) / 86400000 < 240);
});

/* ---------- الحساب الوهمي باستراتيجية وهمية ---------- */

// كل سهم = شموع وهمية تحمل أسابيعها؛ الاستراتيجية ترجع نتيجة مُعدّة مسبقًا لكل (سهم، أسبوع)
const fakeSplitWeeks = bars => bars.weeks.map((weekKey, i) => ({ weekKey, start: i, end: i, firstDay: weekKey, lastDay: weekKey }));
function fakeWorld(table) {
  const barsBySym = {};
  for (const [sym, weeks] of Object.entries(table)) barsBySym[sym] = { t: [1], o: [1], h: [1], l: [1], c: [1], v: [1], weeks: Object.keys(weeks), table: weeks };
  const strategy = (bars, week) => {
    const x = bars.table[week.weekKey];
    if (!x) return { weekKey: week.weekKey, signal: null, exit: null, r: null, pct: null };
    const r = (x.exit - x.entry) / (x.entry - x.stop);
    return { weekKey: week.weekKey, signal: { idx: 0, t: x.inT ?? 1, entryIdx: 1, entryT: x.inT ?? 1, entry: x.entry, stop: x.stop, target: x.target ?? x.entry * 2, line: null, reason: 'fake' },
      exit: { idx: 2, t: x.outT ?? 100, price: x.exit, how: x.how || 'friday' }, r, pct: x.exit / x.entry - 1 };
  };
  return { barsBySym, strategy, splitWeeks: fakeSplitWeeks };
}
const noSlip = { slippage: 0 };

test('positionSize: 1% risk, value cap, whole shares', () => {
  const base = { equity: 10000, riskPct: 0.01, maxPositions: 5 };
  assert.equal(positionSize({ ...base, entry: 100, stop: 90 }), 10);  // خطر: 100 ÷ 10
  assert.equal(positionSize({ ...base, entry: 100, stop: 99 }), 20);  // سقف القيمة: 2000 ÷ 100 (الخطر يعطي 100)
  assert.equal(positionSize({ ...base, maxPositions: 1, entry: 100, stop: 97 }), 33); // 33.3 → 33
  assert.equal(positionSize({ ...base, entry: 100, stop: 100 }), 0);
  assert.equal(positionSize({ ...base, entry: 3000, stop: 2900 }), 0); // سهم واحد يتجاوز السقف
  assert.equal(positionSize({ ...base, cash: 500, entry: 100, stop: 99 }), 5); // النقد المتاح
  const w = fakeWorld({ A: { w1: { entry: 100, stop: 90, exit: 110 } } });
  const res = runBacktest({ ...w, params: {}, account: noSlip });
  assert.equal(res.trades[0].shares, 10);
  assert.equal(res.trades[0].pnl, 100);
});

test('maxPositions: signals taken in entry-time order, slot freed after an earlier exit', () => {
  const w = fakeWorld({
    A: { w1: { entry: 10, stop: 9, exit: 11, inT: 30, outT: 100 } },
    B: { w1: { entry: 10, stop: 9, exit: 11, inT: 10, outT: 100 } },
    C: { w1: { entry: 10, stop: 9, exit: 11, inT: 20, outT: 100 } },
  });
  const r1 = runBacktest({ ...w, params: {}, account: { ...noSlip, maxPositions: 2 } });
  assert.deepEqual(r1.trades.map(t => t.sym), ['B', 'C']);
  assert.equal(r1.weeks[0].trades, 2);
  assert.equal(r1.perSymbol.A.trades, 1); // إحصاء السهم على مستوى الاستراتيجية حتى لو لم يأخذه الحساب
  // B يخرج قبل دخول A → تتحرر خانته
  w.barsBySym.B.table.w1.outT = 25;
  const r2 = runBacktest({ ...w, params: {}, account: { ...noSlip, maxPositions: 2 } });
  assert.deepEqual(r2.trades.map(t => t.sym), ['B', 'C', 'A']);
  // خروج في نفس شمعة الدخول لا يحرر الخانة (محافظ)
  w.barsBySym.B.table.w1.outT = 30;
  assert.deepEqual(runBacktest({ ...w, params: {}, account: { ...noSlip, maxPositions: 2 } }).trades.map(t => t.sym), ['B', 'C']);
});

test('slippage is applied on entry and exit', () => {
  const w = fakeWorld({ A: { w1: { entry: 100, stop: 90, exit: 110 } } });
  const res = runBacktest({ ...w, params: {}, account: { slippage: 0.001, maxPositions: 1 } });
  const t = res.trades[0];
  assert.equal(t.shares, 10);
  assert.equal(t.pnl, Math.round(10 * (110 * 0.999 - 100 * 1.001) * 100) / 100); // 97.9
  assert.equal(t.entry, 100); // الأسعار المسجلة من الاستراتيجية، والانزلاق في pnl
  assert.equal(t.r, 1);
  const def = runBacktest({ ...w, params: {} }); // الافتراضي 0.02% لكل جهة
  assert.equal(def.trades[0].pnl, Math.round(10 * (110 * 0.9998 - 100 * 1.0002) * 100) / 100);
});

test('equity, drawdown and summary on a hand-computed example', () => {
  // maxPositions = 1 (السقف = الرصيد كله)، بدون انزلاق
  // w1: 10000 × 1% = 100 ÷ 2 = 50 سهم × +4 = +200 → 10200
  // w2: 102 ÷ 1 = 102 سهم × −2 = −204 → 9996
  // w3: 99.96 ÷ 1 = 99 سهم × −1 = −99 → 9897   (أقصى تراجع: 303 ÷ 10200 = 2.97059%)
  // w4: 98.97 ÷ 1 = 98 سهم × +2 = +196 → 10093
  const w = fakeWorld({
    A: { w1: { entry: 100, stop: 98, exit: 104 }, w3: { entry: 20, stop: 19, exit: 19, how: 'stop' } },
    B: { w2: { entry: 50, stop: 49, exit: 48, how: 'stop' }, w4: { entry: 10, stop: 9, exit: 12, how: 'target' } },
    Z: {},
  });
  const res = runBacktest({ ...w, params: { k: 1 }, account: { ...noSlip, maxPositions: 1 }, meta: { source: 'yahoo', from: 'a', to: 'b' }, universe: ['A', 'B', 'Z', 'Q'] });
  assert.deepEqual(res.weeks.map(x => x.equityEnd), [10200, 9996, 9897, 10093]);
  assert.deepEqual(res.trades.map(x => x.shares), [50, 102, 99, 98]);
  assert.deepEqual(res.weeks.map(x => x.pnl), [200, -204, -99, 196]);
  assert.equal(res.weeks[1].returnPct, -2);
  const a = res.account;
  assert.equal(a.start, 10000);
  assert.equal(a.end, 10093);
  assert.equal(a.returnPct, 0.93);
  assert.equal(a.maxDrawdownPct, 2.971);
  assert.equal(a.trades, 4);
  assert.equal(a.winRate, 0.5);
  assert.equal(a.avgR, 0.25); // (2 − 2 − 1 + 2) ÷ 4
  assert.equal(a.profitFactor, Math.round(396 / 303 * 1000) / 1000);
  // الصيغة حسب العقد
  assert.deepEqual(Object.keys(res), ['generatedAt', 'source', 'dataFrom', 'dataTo', 'params', 'universe', 'weeks', 'account', 'trades', 'perSymbol']);
  assert.deepEqual(Object.keys(res.trades[0]), ['sym', 'weekKey', 'entryT', 'entry', 'stop', 'target', 'exitT', 'exit', 'how', 'r', 'pct', 'shares', 'pnl']);
  assert.deepEqual(Object.keys(res.weeks[0]), ['weekKey', 'trades', 'wins', 'pnl', 'equityEnd', 'returnPct']);
  assert.equal(res.source, 'yahoo');
  assert.deepEqual(res.perSymbol.A, { weeks: 2, signals: 2, trades: 2, wins: 1, winRate: 0.5, avgR: 0.5, totalR: 1, avgPct: Math.round(((104 / 100 - 1) + (19 / 20 - 1)) / 2 * 1e5) / 1e5, bestR: 2, worstR: -1 });
  assert.deepEqual(res.perSymbol.Z, { weeks: 0, signals: 0, trades: 0, wins: 0, winRate: null, avgR: null, totalR: 0, avgPct: null, bestR: null, worstR: null });
  assert.equal(res.perSymbol.Q.trades, 0); // سهم في الكون بدون بيانات
});

test('weeks without signals keep equity flat and a throwing strategy is treated as no signal', () => {
  const w = fakeWorld({ A: { w1: null, w2: { entry: 10, stop: 9, exit: 11 } } });
  w.barsBySym.A.weeks = ['w1', 'w2', 'w3'];
  const strategy = (bars, week, p) => { if (week.weekKey === 'w3') throw new Error('boom'); return w.strategy(bars, week, p); };
  const sim = simulateSignals({ barsBySym: w.barsBySym, strategy, splitWeeks: w.splitWeeks, params: {} });
  assert.equal(sim.errors, 1);
  const acc = runAccount({ sim, account: noSlip });
  assert.deepEqual(acc.weeks.map(x => x.trades), [0, 1, 0]);
  assert.equal(acc.weeks[0].equityEnd, 10000);
  assert.equal(acc.account.profitFactor, null); // لا خسائر
});

/* ---------- الشبكة والاختبار الأمامي ---------- */

test('walk-forward split, grid combos and best pick', () => {
  assert.deepEqual(walkForwardSplit(['w4', 'w1', 'w3', 'w2', 'w5']), { inSample: ['w1', 'w2'], outSample: ['w3', 'w4', 'w5'] });
  assert.deepEqual(walkForwardSplit([]), { inSample: [], outSample: [] });
  assert.deepEqual(gridCombos({ a: [1, 2], b: ['x', 'y'] }), [{ a: 1, b: 'x' }, { a: 1, b: 'y' }, { a: 2, b: 'x' }, { a: 2, b: 'y' }]);
  assert.deepEqual(gridCombos({}), [{}]);
  assert.equal(pickBest([{ trades: 3, returnPct: 50, avgR: 1 }, { trades: 12, returnPct: 5, avgR: 0.2 }, { trades: 20, returnPct: 5, avgR: 0.4 }], 10), 2);
  assert.equal(pickBest([{ trades: 1, returnPct: 1, avgR: 1 }, { trades: 2, returnPct: 3, avgR: 0 }], 10), 1);
});

test('sweep chooses on the older half and reports the newer half honestly', () => {
  // x=1 يربح في w1,w2 ويخسر في w3,w4؛ x=2 العكس → الاختيار x=1 ونتيجته خارج العينة سالبة
  const barsBySym = { A: { t: [1], o: [1], h: [1], l: [1], c: [1], v: [1], weeks: ['w1', 'w2', 'w3', 'w4'] } };
  const strategy = (bars, week, p) => {
    const older = week.weekKey <= 'w2';
    const win = (p.x === 1) === older;
    return { weekKey: week.weekKey, signal: { entryT: 1, entry: 10, stop: 9, target: 12 }, exit: { t: 5, price: win ? 12 : 9, how: win ? 'target' : 'stop' }, r: win ? 2 : -1, pct: win ? 0.2 : -0.1 };
  };
  const res = runSweep({ barsBySym, strategy, splitWeeks: fakeSplitWeeks, defaults: { x: 2, y: 7 }, grid: { x: [1, 2] }, account: noSlip, minTrades: 1 });
  assert.equal(res.combos, 2);
  assert.deepEqual(res.rows.map(r => r.params), [{ x: 1 }, { x: 2 }]);
  assert.deepEqual(Object.keys(res.rows[0]), ['params', 'trades', 'winRate', 'avgR', 'returnPct', 'maxDD']);
  const wf = res.walkForward;
  assert.deepEqual(wf.inSample, { from: 'w1', to: 'w2', weeks: 2 });
  assert.deepEqual(wf.outSample, { from: 'w3', to: 'w4', weeks: 2 });
  assert.deepEqual(wf.chosen.params, { x: 1 });
  assert.ok(wf.chosen.inSample.returnPct > 0);
  assert.ok(wf.chosen.outSample.returnPct < 0);
  assert.equal(wf.chosen.outSample.winRate, 0);
  assert.ok(wf.defaults.outSample.returnPct > 0);
});
