// اختبارات البحث (بدون شبكة، بيانات اصطناعية): المحاسبة، عدم النظر للمستقبل، الاختبار الأمامي، الشروط، وكل عائلة.
import { test } from 'node:test';
import assert from 'node:assert/strict';

const E = await import('../lab/research/engine.mjs');
const I = await import('../lab/research/indicators.mjs');
const { synthUniverse, weekdays } = await import('../lab/research/synth.mjs');
const { FAMILIES, gridCombos } = await import('../lab/research/strategies/index.mjs');
const C = await import('../lab/research/strategies/common.mjs');
const { checkCriteria, runResearch, buildReport } = await import('../lab/research/run.mjs');
const DATA = await import('../lab/research/data.mjs');

const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) <= eps * Math.max(1, Math.abs(b)), `${a} ≠ ${b}`);
const fam = id => FAMILIES.find(f => f.family === id);

// سلسلة من إغلاقات → شموع (افتتاح = إغلاق الأمس) على أيام عمل
function barsFrom(closes, { t = null, vol = 1e6, over = {} } = {}) {
  const ts = t || weekdays(closes.length);
  const o = closes.map((c, i) => (i ? closes[i - 1] : c));
  const b = { t: ts.slice(0, closes.length), o, h: closes.map((c, i) => Math.max(c, o[i]) * 1.005), l: closes.map((c, i) => Math.min(c, o[i]) * 0.995),
    c: closes.slice(), v: closes.map(() => vol) };
  for (const [k, m] of Object.entries(over)) for (const [i, x] of Object.entries(m)) b[k][Number(i)] = x;
  b.rc = b.c.slice();
  return b;
}
const panelOf = (obj, groups = {}) => E.buildPanel(new Map(Object.entries(obj)), groups);
const ramp = (n, a, step) => Array.from({ length: n }, (_, i) => a + i * step);

/* ---------- المؤشرات ---------- */
test('research indicators: sma / rsi / rollingMax / ret on tiny series', () => {
  const x = Float64Array.from([1, 2, 3, 4, 5]);
  assert.deepEqual(Array.from(I.sma(x, 3)).map(v => (Number.isNaN(v) ? null : v)), [null, null, 2, 3, 4]);
  assert.deepEqual(Array.from(I.rollingMax(Float64Array.from([3, 1, 2, 5, 4]), 2)).slice(1), [3, 2, 5, 5]);
  near(I.ret(x, 2)[4], 5 / 3 - 1);
  const up = I.rsi(Float64Array.from([1, 2, 3, 4]), 2); assert.equal(up[3], 100);
  const dn = I.rsi(Float64Array.from([4, 3, 2, 1]), 2); assert.equal(dn[3], 0);
  near(I.ibs(Float64Array.from([10]), Float64Array.from([8]), Float64Array.from([9]))[0], 0.5);
});

/* ---------- المحاسبة ---------- */
test('engine accounting: cash, shares and costs match a hand-computed trade', () => {
  const P = panelOf({ AAA: barsFrom([10, 10.5, 11.5, 12, 12.5, 13], { over: { o: { 2: 11, 4: 12 } } }) });
  const cfg = { universe: ['AAA'], maxPositions: 1, entryAt: 'open', exitAt: 'open', hold: 2, score: d => (d === 1 ? 1 : null) };
  const r = E.runStrategy(P, cfg, { warmup: 1, start: 1000, flatCost: 0.001 });
  const shares = 1000 / (11 * 1.001), proceeds = shares * 12 * 0.999;
  assert.equal(r.trades.length, 1);
  const t = r.trades[0];
  assert.equal(t.entryIdx, 2); assert.equal(t.exitIdx, 4); assert.equal(t.how, 'time');
  near(t.shares, shares); near(t.pnl, proceeds - 1000); near(t.ret, proceeds / 1000 - 1); near(t.contrib, (proceeds - 1000) / 1000);
  near(r.equity[1], 1000);
  near(r.equity[2], shares * 11.5);   // كل النقد في السهم، التقييم بإغلاق يوم الدخول
  near(r.equity[3], shares * 12);
  near(r.equity[4], proceeds);         // بيع بافتتاح يوم 4 → نقد فقط
  near(r.equity[5], proceeds);
  near(r.gross[2], 1); assert.equal(r.gross[4], 0);
  near(r.turn[2], shares * 11 / 1000);
});

test('engine: stop gap fills at the open, stop beats target on the same bar, no leverage', () => {
  // يوم 3 يفتح تحت الوقف (فجوة) → التنفيذ بالافتتاح
  const P = panelOf({ AAA: barsFrom([10, 10, 10, 9, 9], { over: { o: { 2: 10, 3: 8.5 }, l: { 3: 8.4 } } }) });
  const cfg = { universe: ['AAA'], maxPositions: 1, entryAt: 'open', exitAt: 'open', hold: 50, stopPct: 0.05, score: d => (d === 1 ? 1 : null) };
  const r = E.runStrategy(P, cfg, { warmup: 1, flatCost: 0 });
  assert.equal(r.trades[0].how, 'stop'); assert.equal(r.trades[0].exit, 8.5);
  // يوم يلمس الوقف والهدف معًا → الوقف
  const Q = panelOf({ AAA: barsFrom([10, 10, 10, 10, 10], { over: { h: { 3: 12 }, l: { 3: 9 } } }) });
  const r2 = E.runStrategy(Q, { ...cfg, targetPct: 0.05 }, { warmup: 1, flatCost: 0 });
  assert.equal(r2.trades[0].how, 'stop'); near(r2.trades[0].exit, 9.5);
  // خمسة أسهم بإشارة، حد 2 مراكز → التعرض لا يتجاوز 100%
  const many = {}; for (const s of ['A', 'B', 'C', 'D', 'E']) many[s] = barsFrom(ramp(30, 10, 0.1));
  const R = panelOf(many);
  const r3 = E.runStrategy(R, { universe: ['A', 'B', 'C', 'D', 'E'], maxPositions: 2, entryAt: 'open', exitAt: 'open', hold: 3, score: () => 1 }, { warmup: 1 });
  assert.ok(Math.max(...r3.gross) <= 1 + 1e-12);
  assert.ok(r3.equity.every((e, i) => i < 1 || e > 0));
});

test('engine: close entry with overnight hold sells at the next open; intraday hold 0 sells at the same close', () => {
  const P = panelOf({ SPY: barsFrom([100, 101, 102, 103], { over: { o: { 2: 101.5, 3: 102.5 } } }) });
  const night = E.runStrategy(P, { universe: ['SPY'], maxPositions: 1, entryAt: 'close', exitAt: 'open', hold: 1, score: () => 1 }, { warmup: 1, flatCost: 0 });
  const t = night.trades[0];
  assert.equal(t.entryIdx, 2); assert.equal(t.entry, 102); assert.equal(t.exitIdx, 3); assert.equal(t.exit, 102.5);
  const day = E.runStrategy(P, { universe: ['SPY'], maxPositions: 1, entryAt: 'open', exitAt: 'close', hold: 0, score: () => 1 }, { warmup: 1, flatCost: 0 });
  assert.equal(day.trades[0].entryIdx, 2); assert.equal(day.trades[0].exitIdx, 2);
  assert.equal(day.trades[0].entry, 101.5); assert.equal(day.trades[0].exit, 102);
});

test('cost model: at least 0.05% per side, higher for illiquid and cheap stocks', () => {
  assert.equal(E.costRate(150, 5e8), 0.0005);
  assert.ok(E.costRate(150, 3e7) > 0.0005);
  assert.ok(E.costRate(4, 2e6) > E.costRate(40, 2e6));
  assert.ok(E.costRate(20, NaN) >= 0.006);
});

/* ---------- عدم النظر للمستقبل ---------- */
test('no look-ahead: truncating future data does not change past equity or trades (every family)', () => {
  const { barsBySym, groups } = synthUniverse({ nLarge: 40, nSmall: 8, days: 700, seed: 3 });
  const K = 620;
  const cut = new Map([...barsBySym].map(([s, b]) => {
    const tK = barsBySym.get('SPY').t[K];
    const n = b.t.findIndex(t => t >= tK); const k = n < 0 ? b.t.length : n;
    return [s, Object.fromEntries(Object.entries(b).map(([f, a]) => [f, a.slice(0, k)]))];
  }));
  const opt = { largeN: 25, warmup: 260 };
  const Pf = E.buildPanel(barsBySym, groups, opt), Pc = E.buildPanel(cut, groups, opt);
  assert.equal(Pc.D, K);
  for (const f of FAMILIES) {
    const p = gridCombos(f.grid)[0];
    const a = E.runStrategy(Pf, f.make(p)), b = E.runStrategy(Pc, f.make(p));
    const lim = K - 10;
    for (let d = 0; d < lim; d++) if (Number.isFinite(a.equity[d])) near(b.equity[d], a.equity[d], 1e-9);
    const key = t => `${t.sym}@${t.entryIdx}-${t.exitIdx}:${t.exit.toFixed(8)}`;
    assert.deepEqual(b.trades.filter(t => t.exitIdx < lim).map(key), a.trades.filter(t => t.exitIdx < lim).map(key), f.family);
  }
});

/* ---------- الاختبار الأمامي ---------- */
test('walk-forward: selection for year Y never uses data from Y or later', () => {
  const dates = weekdays(252 * 7, Date.UTC(2015, 0, 1));
  const D = dates.length;
  const mk = (rIS, rOOS, switchYear) => {
    const eq = new Float64Array(D); eq[0] = 1;
    for (let d = 1; d < D; d++) eq[d] = eq[d - 1] * (1 + (new Date(dates[d]).getUTCFullYear() < switchYear ? rIS : rOOS) + (d % 2 ? 0.001 : -0.001));
    const trades = Array.from({ length: 60 }, (_, k) => ({ entryIdx: k * 25, exitIdx: k * 25 + 2, contrib: 0, ret: 0, pnl: 0 }));
    return { equity: eq, gross: new Float64Array(D), turn: new Float64Array(D), trades };
  };
  const runs = [mk(0.001, -0.001, 2019), mk(0.0002, 0.003, 2019)];
  const wf = E.walkForward(runs, dates, { start: 0, minTradesIS: 5 });
  assert.ok(wf.folds.length >= 4);
  for (const f of wf.folds) { assert.ok(f.trainTo < f.from); assert.equal(new Date(dates[f.from]).getUTCFullYear(), f.year); }
  // تغيير جذري لكل البيانات من سنة Y فصاعدًا لا يغيّر اختيار سنة Y
  for (const f of wf.folds) {
    const poisoned = runs.map((r, k) => { const eq = r.equity.slice(); for (let d = f.from; d < D; d++) eq[d] = eq[d - 1] * (k === 0 ? 0.5 : 2); return { ...r, equity: eq }; });
    const wf2 = E.walkForward(poisoned, dates, { start: 0, minTradesIS: 5 });
    assert.equal(wf2.folds.find(x => x.year === f.year).chosen, f.chosen, `fold ${f.year}`);
  }
  // الأول جيد قبل 2019 فيُختار لـ 2019 رغم أنه يخسر فيها؛ بعدها الثاني يتفوق
  assert.equal(wf.folds.find(f => f.year === 2019).chosen, 0);
  assert.equal(wf.rets.length, wf.days.length);
});

/* ---------- الشروط ---------- */
test('criteria checker: all seven must pass; each failure is reported', () => {
  const good = { dataYears: 10, folds: 6, shariah: { ok: true, why: 'x' },
    oos: { trades: 150, ret: 0.8, cagr: 0.1, maxDD: 0.08, best2Removed: 0.6, yearsProfitable: 5, yearsTotal: 6, maxGross: 1, bench: { ret: 0.5, cagr: 0.07 } } };
  const ok = checkCriteria(good);
  assert.equal(ok.passed, true); assert.equal(ok.score, 7);
  const fails = {
    1: { dataYears: 5 }, 2: { oos: { trades: 99 } }, 3: { folds: 2 }, 4: { oos: { bench: { ret: 0.9, cagr: 0.12 } } },
    5: { oos: { maxDD: 0.1 } }, 6: { oos: { best2Removed: -0.01 } }, 7: { shariah: { ok: false, why: 'etf' } },
  };
  for (const [id, patch] of Object.entries(fails)) {
    const c = { ...good, ...patch, oos: { ...good.oos, ...(patch.oos || {}) } };
    const r = checkCriteria(c);
    assert.equal(r.passed, false, 'criterion ' + id);
    assert.deepEqual(r.checks.filter(k => !k.ok).map(k => k.id), [Number(id)]);
  }
  const fewYears = checkCriteria({ ...good, oos: { ...good.oos, yearsProfitable: 3, yearsTotal: 6 } });
  assert.deepEqual(fewYears.checks.filter(k => !k.ok).map(k => k.id), [6]);
  const lev = checkCriteria({ ...good, oos: { ...good.oos, maxGross: 1.2 } });
  assert.deepEqual(lev.checks.filter(k => !k.ok).map(k => k.id), [7]);
});

/* ---------- إشارات كل عائلة ---------- */
const up260 = ramp(260, 50, 0.2);           // اتجاه صاعد هادئ
const init = (id, p, P) => { const cfg = fam(id).make({ ...gridCombos(fam(id).grid)[0], ...p }); if (cfg.init) cfg.init(P); return cfg; };

test('families: every grid has ≤ 12 combos and there are ≥ 10 families', () => {
  assert.ok(FAMILIES.length >= 10);
  for (const f of FAMILIES) { const n = gridCombos(f.grid).length; assert.ok(n >= 1 && n <= 12, f.family + ' ' + n); }
  assert.equal(new Set(FAMILIES.map(f => f.family)).size, FAMILIES.length);
});

test('signal mr-rsi2 / regime-mr: sharp dip in an uptrend triggers, calm uptrend does not', () => {
  const closes = [...up260, 100, 96, 92];
  const P = panelOf({ SPY: barsFrom(ramp(263, 100, 0.1)), AAA: barsFrom(closes) });
  const s = P.sym('AAA'), d = P.D - 1;
  const cfg = init('mr-rsi2', { th: 10, exit: 'sma5' }, P);
  assert.ok(cfg.score(d, s) !== null);
  assert.equal(cfg.score(250, s), null);
  assert.equal(cfg.exitSignal(d, s), false);
  const rg = init('regime-mr', { regime: 'sma200' }, P);
  assert.ok(rg.score(d, s) !== null); assert.equal(rg.regime(d), true);
  const Q = panelOf({ SPY: barsFrom(ramp(263, 200, -0.3)), AAA: barsFrom(closes) });
  assert.equal(init('regime-mr', { regime: 'sma200' }, Q).regime(Q.D - 1), false);
});

test('signal mr-ibs: close at the low after N down days', () => {
  const closes = [...up260, 100, 99, 98];
  const n = closes.length;
  const P = panelOf({ AAA: barsFrom(closes, { over: { l: { [n - 1]: 98 }, h: { [n - 1]: 99.5 } } }) });
  const s = P.sym('AAA');
  assert.ok(init('mr-ibs', { ibs: 0.1, down: 3 }, P).score(n - 1, s) !== null);
  assert.equal(init('mr-ibs', { ibs: 0.1, down: 4 }, P).score(n - 1, s), null);
  assert.equal(init('mr-ibs', {}, P).exitSignal(n - 1, s), false);
});

test('signal xs-reversal: weekly losers are candidates, winners are not; rebalance on the last weekday', () => {
  const t = weekdays(20);
  const P = panelOf({ LOS: barsFrom(ramp(20, 100, -1), { t }), WIN: barsFrom(ramp(20, 100, 1), { t }) });
  const cfg = init('xs-reversal', { look: 5, trend: 'none' }, P);
  assert.ok(cfg.score(19, P.sym('LOS')) > 0); assert.equal(cfg.score(19, P.sym('WIN')), null);
  const fri = [...Array(20).keys()].find(d => new Date(t[d]).getUTCDay() === 5), thu = fri - 1;
  assert.equal(cfg.rebalance(fri), true); assert.equal(cfg.rebalance(thu), false);
});

test('signal hi52-momentum and mom-12-1: near-high/rising stocks score, falling ones do not', () => {
  const P = panelOf({ SPY: barsFrom(ramp(300, 100, 0.1)), UP: barsFrom(ramp(300, 50, 0.3)), DN: barsFrom(ramp(300, 150, -0.3)) });
  const d = P.D - 1;
  const h = init('hi52-momentum', { regime: 'none' }, P);
  assert.ok(h.score(d, P.sym('UP')) >= 0.9); assert.equal(h.score(d, P.sym('DN')), null);
  const m = init('mom-12-1', {}, P);
  assert.ok(m.score(d, P.sym('UP')) > 0); assert.equal(m.score(d, P.sym('DN')), null);
  assert.equal(m.regime(d), true);
});

test('signal vcp-breakout: inside day in an uptrend gives a buy-stop above its high and a stop at its low', () => {
  const closes = [...up260, 102.2, 102.3]; const n = closes.length;
  const P = panelOf({ AAA: barsFrom(closes, { over: { h: { [n - 2]: 104, [n - 1]: 103 }, l: { [n - 2]: 101, [n - 1]: 102 } } }) });
  const sig = init('vcp-breakout', { pattern: 'inside', trend: 'up' }, P).score(n - 1, P.sym('AAA'));
  assert.ok(sig && sig.trigger > 103 && sig.trigger < 103.1 && sig.stop === 102);
  assert.equal(init('vcp-breakout', { pattern: 'inside' }, P).score(n - 2, P.sym('AAA')), null);
});

test('signal vol-spike: big volume breakout closing near the high', () => {
  const closes = [...ramp(40, 20, 0), 21]; const n = closes.length;
  const P = panelOf({ AAA: barsFrom(closes, { over: { v: { [n - 1]: 6e6 }, h: { [n - 1]: 21.05 }, l: { [n - 1]: 19.9 } } }) });
  const sig = init('vol-spike', { volMult: 5 }, P).score(n - 1, P.sym('AAA'));
  assert.ok(sig && sig.score >= 5 && sig.stop === 19.9);
  assert.equal(init('vol-spike', { volMult: 5 }, P).score(n - 2, P.sym('AAA')), null);
});

test('signal calendar-tom: entry only on the configured day before month end', () => {
  const t = weekdays(60, Date.UTC(2024, 0, 1));
  const P = panelOf({ SPY: barsFrom(ramp(60, 100, 0.1), { t }) });
  const s = P.sym('SPY');
  const last = [...Array(59).keys()].filter(d => C.lastOfMonth(P, d));
  assert.equal(new Date(t[last[0]]).toISOString().slice(0, 10), '2024-01-31');
  const cfg0 = init('calendar-tom', { before: 0 }, P), cfg2 = init('calendar-tom', { before: 2 }, P);
  assert.equal(cfg0.score(last[0] - 1, s, last[0]), 1); assert.equal(cfg0.score(last[0] - 2, s, last[0] - 1), null);
  assert.equal(cfg2.score(last[0] - 3, s, last[0] - 2), 1);
  assert.equal(C.dayOfMonth(P, last[0] + 1), 1);
});

test('signal overnight and etf-trend: modes and trend filter', () => {
  const P = panelOf({ SPY: barsFrom(ramp(260, 100, 0.1)) });
  const n = init('overnight', { mode: 'overnight', regime: 'none' }, P), i = init('overnight', { mode: 'intraday', regime: 'sma200' }, P);
  assert.equal(n.entryAt, 'close'); assert.equal(n.exitAt, 'open'); assert.equal(n.regime, null); assert.equal(n.score(), 1);
  assert.equal(i.entryAt, 'open'); assert.equal(i.exitAt, 'close'); assert.equal(i.regime(259), true);
  const e = init('etf-trend', { sma: 100 }, P);
  assert.equal(e.score(259, P.sym('SPY')), 1);
  const Q = panelOf({ SPY: barsFrom(ramp(260, 200, -0.2)) });
  assert.equal(init('etf-trend', { sma: 100 }, Q).score(259, Q.sym('SPY')), null);
});

test('signal gap-up: held gap with volume above the 20-day average', () => {
  const closes = [...ramp(60, 50, 0.1), 59]; const n = closes.length;
  const P = panelOf({ AAA: barsFrom(closes, { over: { o: { [n - 1]: 58.5 }, v: { [n - 1]: 4e6 }, l: { [n - 1]: 58.4 } } }) });
  const sig = init('gap-up', { gap: 0.04, volMult: 3 }, P).score(n - 1, P.sym('AAA'));
  assert.ok(sig && sig.score > 0.04 && sig.stop === 58.4);
  assert.equal(init('gap-up', { gap: 0.04, volMult: 3 }, P).score(n - 2, P.sym('AAA')), null);
});

test('signal pullback-ma: strong stock touching its 10-day average', () => {
  const closes = ramp(261, 30, 0.3); const n = closes.length;
  const P = panelOf({ AAA: barsFrom(closes, { over: { l: { [n - 1]: closes[n - 1] - 3 } } }) });
  const cfg = init('pullback-ma', { ma: 10 }, P), s = P.sym('AAA');
  assert.ok(cfg.score(n - 1, s) > 0.2);
  assert.equal(cfg.score(n - 2, s), null);
  assert.equal(typeof cfg.exitSignal(n - 1, s), 'boolean');
});

test('signal lowvol-trend: calm uptrend scores, downtrend does not', () => {
  const P = panelOf({ UP: barsFrom(ramp(260, 50, 0.1)), DN: barsFrom(ramp(260, 100, -0.1)) });
  const cfg = init('lowvol-trend', { regime: 'none' }, P);
  assert.ok(cfg.score(259, P.sym('UP')) < 0); assert.equal(cfg.score(259, P.sym('DN')), null);
});

/* ---------- البيانات (دوال صافية) ---------- */
test('data: adjusted parse applies adjclose/close to OHLC and keeps split-only close', () => {
  const day = Date.UTC(2024, 0, 2) / 1000 + 15 * 3600;
  const payload = { chart: { result: [{ meta: {}, timestamp: [day, day + 86400], indicators: {
    quote: [{ open: [10, 11], high: [11, 12], low: [9, 10], close: [10, 12], volume: [100, 200] }], adjclose: [{ adjclose: [9, 12] }] } }] } };
  const b = DATA.parseYahooAdjusted(payload, Date.UTC(2025, 0, 1));
  assert.equal(b.t.length, 2);
  near(b.c[0], 9); near(b.o[0], 9); near(b.h[0], 9.9); near(b.l[0], 8.1); assert.equal(b.rc[0], 10);
  near(b.c[1], 12); assert.equal(b.v[1], 200);
});

test('data: incremental merge rescales cache after a dividend; inconsistent window forces a full refetch', () => {
  const t = weekdays(10);
  const old = { t: t.slice(0, 8), o: Array(8).fill(10), h: Array(8).fill(11), l: Array(8).fill(9), c: Array(8).fill(10), v: Array(8).fill(1), rc: Array(8).fill(10) };
  const fresh = { t: t.slice(5), o: Array(5).fill(9.9), h: Array(5).fill(10.89), l: Array(5).fill(8.91), c: Array(5).fill(9.9), v: Array(5).fill(1), rc: Array(5).fill(10) };
  const m = DATA.mergeAdjusted(old, fresh);
  assert.equal(m.t.length, 10); near(m.c[0], 9.9); near(m.c[9], 9.9); assert.equal(m.rc[0], 10);
  const bad = { ...fresh, c: [9.9, 9.9, 10, 9.9, 9.9] };
  assert.equal(DATA.mergeAdjusted(old, bad), null);
  assert.equal(DATA.mergeAdjusted(null, fresh), null);
});

test('data: universe selection by median dollar volume, small sleeve, shariah name/industry screen', () => {
  const rows = { A: { mdv: 5e8, px: 100 }, B: { mdv: 4e8, px: 3 }, C: { mdv: 3e8, px: 50 }, D: { mdv: 2e6, px: 4 }, E: { mdv: 5e5, px: 10 }, SPY: { mdv: 1e10, px: 500 } };
  const sel = DATA.selectUniverse(rows, { ...DATA.DATA_DEFAULTS, largeN: 2, smallN: 5 });
  assert.deepEqual(sel.large, ['A', 'C']); assert.deepEqual(sel.small, ['B', 'D']);
  near(DATA.medianDollarVolume({ t: [1, 2, 3], c: [1, 1, 1], rc: [10, 20, 30], v: [1, 1, 1] }), 20);
  assert.ok(DATA.shariahExcluded({ name: 'First Horizon Bancorp' }));
  assert.ok(DATA.shariahExcluded({ name: 'X Corp', industry: 'Banks - Regional' }));
  assert.ok(DATA.shariahExcluded({ name: 'Y Inc', industry: 'Insurance—Life' }));
  assert.ok(DATA.shariahExcluded({ name: 'Z', industry: 'REIT - Mortgage' }));
  assert.ok(DATA.shariahExcluded({ name: 'Las Vegas Sands', industry: 'Resorts & Casinos' }));
  assert.equal(DATA.shariahExcluded({ name: 'Apple Inc.', sector: 'Technology', industry: 'Consumer Electronics' }), null);
  assert.deepEqual(DATA.parseAssetProfile({ quoteSummary: { result: [{ assetProfile: { sector: 'Technology', industry: 'Software' } }] } }), { sector: 'Technology', industry: 'Software' });
});

/* ---------- تشغيل كامل صغير ---------- */
test('research run: end-to-end on a small synthetic market writes candidates, criteria and an Arabic verdict', async () => {
  const u = synthUniverse({ nLarge: 30, nSmall: 6, days: 1100, seed: 11 });
  const out = await runResearch({ ...u, info: { source: 'synthetic', screen: 'synthetic' }, log: () => {}, panelOpt: { largeN: 20 } });
  assert.equal(out.candidates.length, FAMILIES.length + 1);
  for (const c of out.candidates) { assert.equal(c.criteria.checks.length, 7); assert.ok(c.oos.trades >= 0); assert.ok(Array.isArray(c.equity)); }
  for (const c of out.candidates.filter(x => x.universe === 'etf')) assert.equal(c.criteria.checks[6].ok, false);
  const mars = out.candidates.map(c => (c.oos.mar === 'Infinity' ? 1e9 : c.oos.mar ?? -1e9));
  for (let i = 1; i < mars.length; i++) assert.ok(mars[i - 1] >= mars[i]);
  const md = buildReport(out);
  assert.match(md, /وصلنا لنتيجة ممتازة|لا توجد استراتيجية تحقق كل الشروط بعد/);
  assert.match(md, /انحياز البقاء/);
});
