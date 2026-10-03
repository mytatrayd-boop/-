import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// بدون شبكة: وضع تجريبي، بدون Yahoo، ومجلد نتائج مختبر مؤقت
for (const k of ['ALPHA_VANTAGE_KEY', 'MASSIVE_API_KEY', 'POLYGON_API_KEY']) delete process.env[k];
process.env.RASED_NO_ENV_FILE = '1';
process.env.RASED_YAHOO = '0';
const LAB = await mkdtemp(path.join(tmpdir(), 'rased-spike-'));
process.env.RASED_LAB_DIR = LAB;

const S = await import('../server/spike.js');
const { SPIKE_DEFAULTS, SPIKE_GRID, spikeSignal, spikeChecks, spikeTrade, scanSpikes, nextTradingDays, spikeCard, latestMarketDayIdx, marketDays } = S;
const { parseYahooDaily, parseYahoo5m } = await import('../server/yahoo.js');
const { demoSpikeMarket, demoProviders } = await import('../server/demo.js');
const { spikesFor, buildProviders, trendFor } = await import('../server/providers.js');
const { createClientApp } = await import('../server/client.js');
const { createMassiveStore } = await import('../server/massive.js');
const BT = await import('../lab/spike-backtest.mjs');
const F = await import('../lab/spike-fetch.mjs');
const { buildSpikesToday } = await import('../lab/spike-scan.mjs');
const { server } = await import('../server/index.js');

let base;
before(() => new Promise(r => server.listen(0, () => { base = `http://127.0.0.1:${server.address().port}`; r(); })));
after(async () => { await new Promise(r => server.close(r)); await rm(LAB, { recursive: true, force: true }); });

/* ---------- أدوات ---------- */
const DAY = 86400000;
const T0 = Date.UTC(2026, 0, 5); // الاثنين
// n شمعة هادئة: سعر ~p، حجم ~v. t = أيام متتالية (التقويم لا يهم المحرك — يهم الترتيب)
function quiet(n, { p = 2, v = 200000, t0 = T0 } = {}) {
  const b = { t: [], o: [], h: [], l: [], c: [], v: [] };
  for (let i = 0; i < n; i++) {
    const c = p * (1 + 0.02 * Math.sin(i));
    b.t.push(t0 + i * DAY); b.o.push(c); b.h.push(c * 1.01); b.l.push(c * 0.99); b.c.push(c); b.v.push(v);
  }
  return b;
}
const set = (b, i, o, h, l, c, v) => { b.o[i] = o; b.h[i] = h; b.l[i] = l; b.c[i] = c; b.v[i] = v; };
// يوم إشارة صالح في i: +40%، حجم ×50، إغلاق قرب القمة
function withSpike(n = 50, i = 45, opt = {}) {
  const b = quiet(n, opt);
  const prev = b.c[i - 1], c = prev * 1.4;
  set(b, i, prev * 1.05, c * 1.02, prev * 1.02, c, 200000 * 50);
  return b;
}
const SIG_I = 45;
const push = (b, o, h, l, c, v = 1e6) => { b.t.push(b.t[b.t.length - 1] + DAY); b.o.push(o); b.h.push(h); b.l.push(l); b.c.push(c); b.v.push(v); };

/* ---------- الإشارة ---------- */

test('a valid spike passes every check and the signal carries all the numbers', () => {
  const b = withSpike();
  const r = spikeChecks(b, SIG_I);
  assert.ok(Object.values(r.checks).every(Boolean), JSON.stringify(r.checks));
  const s = spikeSignal(b, SIG_I);
  assert.ok(s);
  for (const k of ['i', 't', 'date', 'open', 'high', 'low', 'close', 'prevClose', 'volume', 'avgVol', 'volRatio', 'change', 'baseHigh', 'closePos', 'dollarVol']) assert.ok(k in s, k);
  assert.equal(s.i, SIG_I);
  assert.ok(Math.abs(s.change - 0.4) < 1e-9);
  assert.ok(Math.abs(s.volRatio - 50) < 1e-9);
  assert.ok(s.close > s.baseHigh);
  // تاريخ غير كافٍ (أقل من 40 شمعة قبل D)
  assert.equal(spikeSignal(withSpike(45, 39), 39), null);
  assert.equal(spikeSignal(withSpike(45, 40), 40) !== null, true);
});

test('each signal condition fails on its own', () => {
  const cases = {
    priceLow: b => { const k = 0.3 / b.c[SIG_I]; for (const f of ['o', 'h', 'l', 'c']) b[f] = b[f].map(x => x * k); b.v = b.v.map(x => x * 40); },
    priceHigh: b => { const k = 25 / b.c[SIG_I]; for (const f of ['o', 'h', 'l', 'c']) b[f] = b[f].map(x => x * k); },
    volMult: b => { for (let i = 0; i < SIG_I; i++) b.v[i] = 600000; },            // ×16.7 < ×20 (والحجم ≥ 3M)
    volume: b => { b.v = b.v.map(x => x / 100); b.v[SIG_I] = 2.9e6; for (let i = 0; i < SIG_I; i++) b.v[i] = 2000; }, // ×1450 لكن < 3M
    dollarVol: b => { const k = 0.6 / b.c[SIG_I]; for (const f of ['o', 'h', 'l', 'c']) b[f] = b[f].map(x => x * k); b.v[SIG_I] = 4e6; }, // 0.6 × 4M = 2.4M
    change: b => { const prev = b.c[SIG_I - 1], c = prev * 1.19; set(b, SIG_I, prev, c * 1.01, prev * 0.99, c, b.v[SIG_I]); b.c[10] = prev * 1.05; },
    breakout: b => { b.c[10] = b.c[SIG_I] * 1.01; b.h[10] = b.c[10] * 1.01; },     // إغلاق أعلى قبل 35 يوم
    closeInRange: b => { b.h[SIG_I] = b.c[SIG_I] * 1.3; },                          // الإغلاق بعيد عن القمة
  };
  for (const [name, mutate] of Object.entries(cases)) {
    const b = withSpike();
    mutate(b);
    const r = spikeChecks(b, SIG_I);
    const failed = Object.entries(r.checks).filter(([, ok]) => !ok).map(([k]) => k);
    const expect = name.startsWith('price') ? 'price' : name;
    assert.deepEqual(failed, [expect], `${name}: ${failed}`);
    assert.equal(spikeSignal(b, SIG_I), null, name);
  }
  // الحدود: +20% بالضبط و 0.75 بالضبط ينجحان
  const b = withSpike(); const prev = b.c[SIG_I - 1], c = prev * 1.2;
  set(b, SIG_I, prev, c + (c - prev) / 3, prev, c, b.v[SIG_I]);
  assert.ok(spikeSignal(b, SIG_I), 'edge +20% and close at 75% of range');
});

test('no look-ahead: future bars never change the signal on day D', () => {
  const b = withSpike(46);
  const before = spikeSignal(b, SIG_I);
  const more = withSpike(46);
  push(more, 1, 50, 0.5, 40, 9e9); push(more, 40, 41, 0.1, 0.2, 1);
  for (let k = 0; k < 30; k++) push(more, 3, 3.1, 2.9, 3);
  assert.deepEqual(spikeSignal(more, SIG_I), before);
  assert.deepEqual(spikeChecks(more, SIG_I), spikeChecks(b, SIG_I));
  // ولا الإشارة تعتمد على شمعة D+1: تغييرها لا يغيّر شيئًا
  const alt = withSpike(); alt.c[SIG_I + 1] = 99; alt.v[SIG_I + 1] = 1;
  assert.deepEqual(spikeSignal(alt, SIG_I), spikeSignal(withSpike(), SIG_I));
});

/* ---------- الصفقة ---------- */

function tradeBars(days) { // days: [[o,h,l,c]...] بعد يوم الإشارة
  const b = withSpike(46);
  for (const [o, h, l, c] of days) push(b, o, h, l, c);
  return b;
}

test('entry variants: open, breakout through high_D, gap above high_D, never reaching high_D', () => {
  const hD = withSpike(46).h[SIG_I], lD = withSpike(46).l[SIG_I];
  const after = [[hD * 1.1, hD * 1.2, hD * 1.05, hD * 1.15], [hD * 1.15, hD * 1.3, hD * 1.1, hD * 1.25], [hD, hD, hD * 0.9, hD * 0.95]];
  // افتتاح
  let tr = spikeTrade(tradeBars(after), SIG_I, { entry: 'open', hold: 2, stop: true });
  assert.equal(tr.entryIdx, SIG_I + 1); assert.equal(tr.entry, hD * 1.1);
  // اختراق: فتح تحت أعلى D ثم تجاوزه → التعبئة عند أعلى D
  const through = [[hD * 0.95, hD * 1.1, hD * 0.94, hD * 1.05], [hD, hD * 1.1, hD * 0.99, hD * 1.08]];
  tr = spikeTrade(tradeBars(through), SIG_I, { entry: 'breakout', hold: 2, stop: false });
  assert.equal(tr.entry, hD); assert.equal(tr.exit, hD * 1.08); assert.equal(tr.how, 'time');
  assert.ok(Math.abs(tr.ret - 0.08) < 1e-12);
  // فجوة فوق أعلى D → التعبئة بالافتتاح
  tr = spikeTrade(tradeBars(after), SIG_I, { entry: 'breakout', hold: 2, stop: false });
  assert.equal(tr.entry, hD * 1.1);
  // ما وصل أعلى D → لا صفقة
  const never = [[hD * 0.9, hD * 0.99, lD * 1.01, hD * 0.95], [hD, hD * 1.2, hD, hD * 1.1]];
  assert.equal(spikeTrade(tradeBars(never), SIG_I, { entry: 'breakout', hold: 2, stop: false }), null);
  // شموع مستقبلية غير كافية → null
  assert.equal(spikeTrade(tradeBars(after.slice(0, 1)), SIG_I, { entry: 'open', hold: 2 }), null);
  assert.equal(spikeTrade(withSpike(46), SIG_I, { entry: 'open', hold: 2 }), null);
});

test('hold 2 exits at the close of D+2, hold 3 at the close of D+3 (trading-day bars)', () => {
  const hD = withSpike(46).h[SIG_I];
  const b = tradeBars([[hD, hD * 1.1, hD * 0.99, hD * 1.01], [hD, hD * 1.1, hD * 0.99, hD * 1.02], [hD, hD * 1.1, hD * 0.99, hD * 1.03]]);
  const t2 = spikeTrade(b, SIG_I, { entry: 'open', hold: 2, stop: true }), t3 = spikeTrade(b, SIG_I, { entry: 'open', hold: 3, stop: true });
  assert.equal(t2.exitIdx, SIG_I + 2); assert.equal(t2.exit, hD * 1.02);
  assert.equal(t3.exitIdx, SIG_I + 3); assert.equal(t3.exit, hD * 1.03);
  assert.equal(SPIKE_DEFAULTS.hold, 3);
});

test('catastrophe stop at low_D: touch, gap below, and the entry-day rule', () => {
  const hD = withSpike(46).h[SIG_I], lD = withSpike(46).l[SIG_I];
  // لمس الوقف يوم D+2 → خروج عند الوقف
  let b = tradeBars([[hD, hD * 1.05, lD * 1.1, hD], [hD, hD, lD * 0.95, lD * 1.05], [hD, hD, hD, hD]]);
  let tr = spikeTrade(b, SIG_I, { entry: 'open', hold: 3, stop: true });
  assert.deepEqual([tr.how, tr.exitIdx, tr.exit], ['stop', SIG_I + 2, lD]);
  assert.equal(spikeTrade(b, SIG_I, { entry: 'open', hold: 3, stop: false }).how, 'time');
  // فجوة تحت الوقف → خروج بالافتتاح
  b = tradeBars([[hD, hD * 1.05, lD * 1.1, hD], [lD * 0.8, lD * 0.9, lD * 0.7, lD * 0.85], [hD, hD, hD, hD]]);
  tr = spikeTrade(b, SIG_I, { entry: 'open', hold: 3, stop: true });
  assert.deepEqual([tr.how, tr.exit], ['stop', lD * 0.8]);
  // يوم الدخول: دخول بالافتتاح → الوقف يُطبّق نفس اليوم
  b = tradeBars([[hD, hD * 1.05, lD * 0.9, hD], [hD, hD, hD, hD], [hD, hD, hD, hD]]);
  tr = spikeTrade(b, SIG_I, { entry: 'open', hold: 3, stop: true });
  assert.deepEqual([tr.how, tr.exitIdx], ['stop', SIG_I + 1]);
  // دخول بالاختراق داخل اليوم → قاع يوم الدخول لا يُحسب (ما نعرف هل قبل الدخول)
  b = tradeBars([[hD * 0.9, hD * 1.05, lD * 0.9, hD], [hD, hD, hD, hD * 1.01], [hD, hD, hD, hD * 1.02]]);
  tr = spikeTrade(b, SIG_I, { entry: 'breakout', hold: 3, stop: true });
  assert.deepEqual([tr.how, tr.entry, tr.exit], ['time', hD, hD * 1.02]);
});

/* ---------- السوق كامل ---------- */

test('scanSpikes aligns symbols with different start dates by t and filters common stocks', () => {
  const A = withSpike(50, 45);                      // يبدأ T0
  const B = withSpike(60, 55, { t0: T0 - 10 * DAY }); // يبدأ قبل 10 أيام → نفس يوم الإشارة
  const C = quiet(30, { t0: T0 + 20 * DAY });         // تاريخ قصير
  const D = withSpike(45, 44, { t0: T0 + DAY });      // إشارته يوم مختلف (T0+45)
  const m = new Map([['AAA', A], ['BBB', B], ['CCC', C], ['DDD', D]]);
  const days = marketDays(m);
  const di = days.indexOf(T0 + 45 * DAY);
  const sigs = scanSpikes(m, di);
  assert.deepEqual(sigs.map(s => s.sym).sort(), ['AAA', 'BBB', 'DDD'].filter(s => s !== 'DDD' || D.t[44] === T0 + 45 * DAY).sort());
  assert.equal(sigs.find(s => s.sym === 'AAA').i, 45);
  assert.equal(sigs.find(s => s.sym === 'BBB').i, 55);
  assert.ok(sigs.every((s, k) => !k || sigs[k - 1].volRatio >= s.volRatio), 'sorted by volume multiple');
  assert.deepEqual(scanSpikes(m, di, SPIKE_DEFAULTS, { commonStocks: new Set(['BBB']) }).map(s => s.sym), ['BBB']);
  assert.deepEqual(scanSpikes({ AAA: A }, 45).map(s => s.sym), ['AAA']); // كائن عادي + فهرس موجب
  assert.deepEqual(scanSpikes(m, di - 1), []);
  assert.equal(latestMarketDayIdx(m), days.length - 1);
});

test('plan dates skip weekends and NYSE holidays; spikeCard keeps the last 40 days', () => {
  assert.deepEqual(nextTradingDays('2026-10-02', 3), ['2026-10-05', '2026-10-06', '2026-10-07']);
  assert.deepEqual(nextTradingDays('2026-11-25', 2), ['2026-11-27', '2026-11-30']); // عيد الشكر
  const b = withSpike(), s = spikeSignal(b, SIG_I);
  const c = spikeCard('AAA', b, s, { name: 'A Inc.' });
  assert.equal(c.bars40.c.length, 40);
  assert.equal(c.bars40.t[39], b.t[SIG_I]);
  assert.equal(c.lowD, b.l[SIG_I]); assert.equal(c.highD, b.h[SIG_I]);
  assert.equal(c.chgPct, 40); assert.equal(c.volMult, 50);
  assert.equal(c.entryDate, nextTradingDays(c.day, 1)[0]);
  assert.equal(c.exitDate, nextTradingDays(c.day, 3)[2]);
});

/* ---------- المختبر ---------- */

test('backtest summary math on a tiny hand-built example', () => {
  const s = BT.summarize([0.1, -0.05, 0.2, -0.3]);
  assert.equal(s.trades, 4); assert.equal(s.winRate, 0.5);
  assert.equal(s.avgRet, -0.0125); assert.equal(s.medianRet, 0.025);
  assert.equal(s.worst, -0.3); assert.equal(s.best, 0.2); assert.equal(s.below20, 0.25);
  assert.deepEqual(BT.summarize([]).trades, 0);
  assert.equal(BT.median([3, 1, 2]), 2);
  assert.equal(BT.comboKey({ entry: 'open', hold: 3, stop: true, volMult: 20 }), 'open-h3-stop-v20');
  assert.equal(Object.values(SPIKE_GRID).reduce((n, v) => n * v.length, 1), 24);

  // الحساب الوهمي: $10,000، 10% لكل مركز، انزلاق 0.3%
  const tr = (sym, d0, d1, entry, exit, volRatio) => ({ sym, date: '2026-01-0' + d0, month: '2026-01', entryT: T0 + d0 * DAY, exitT: T0 + d1 * DAY, entry, exit, volRatio, ret: exit / entry - 1 });
  const a = BT.runSpikeAccount([tr('A', 1, 3, 10, 11, 30), tr('B', 1, 3, 5, 4, 50)]);
  // B أولاً (مضاعف أعلى): 1000/5.015 = 199 سهم؛ A: الرصيد ما زال 10,000 → 99 سهم
  const [b1, a1] = a.trades;
  assert.equal(b1.sym, 'B'); assert.equal(b1.shares, 199);
  assert.equal(a1.sym, 'A'); assert.equal(a1.shares, 99);
  const pnl = 199 * (4 * 0.997 - 5 * 1.003) + 99 * (11 * 0.997 - 10 * 1.003);
  assert.ok(Math.abs(a.summary.end - (10000 + pnl)) < 0.01);
  assert.equal(a.summary.trades, 2); assert.equal(a.summary.winRate, 0.5);
  // حد 5 مراكز + نفس السهم لا يتكرر
  const many = Array.from({ length: 7 }, (_, k) => tr('S' + k, 1, 4, 10, 10, 10 + k));
  assert.equal(BT.runSpikeAccount(many).summary.trades, 5);
  assert.equal(BT.runSpikeAccount([tr('A', 1, 3, 10, 11, 9), tr('A', 2, 4, 10, 11, 9)]).summary.trades, 1);
  // الخانة تتحرر بعد إغلاق يوم الخروج (خروج يوم 2 → دخول يوم 3 مسموح)
  const seq = [...Array.from({ length: 5 }, (_, k) => tr('S' + k, 1, 2, 10, 10, 9)), tr('Z', 3, 4, 10, 10, 9)];
  assert.equal(BT.runSpikeAccount(seq).summary.trades, 6);
});

test('walk-forward chooses on the older months and reports the newer months only', () => {
  const months = ['2025-01', '2025-02', '2025-03', '2025-04', '2025-05'];
  const t = (month, ret) => ({ month, ret });
  const byKey = {
    good_old: [t('2025-01', 0.3), t('2025-02', 0.2), t('2025-04', -0.1), t('2025-05', -0.2)],
    good_new: [t('2025-01', -0.1), t('2025-02', 0.0), t('2025-03', 0.5), t('2025-05', 0.4)],
  };
  const wf = BT.walkForward(byKey, months, { minTrades: 2, defaultKey: 'good_new' });
  assert.deepEqual([wf.inSample.from, wf.inSample.to, wf.outSample.from, wf.outSample.to], ['2025-01', '2025-02', '2025-03', '2025-05']);
  assert.equal(wf.chosen.key, 'good_old');
  assert.equal(wf.chosen.inSample.avgRet, 0.25);
  assert.equal(wf.chosen.outSample.trades, 2);
  assert.equal(wf.chosen.outSample.avgRet, -0.15);
  assert.equal(wf.defaults.outSample.avgRet, 0.45);
  // أقل من الحد → يعلن ذلك
  assert.equal(BT.walkForward(byKey, months, { minTrades: 5 }).enoughTrades, false);
});

test('full backtest on a small synthetic market writes the documented shape and an Arabic report', () => {
  const m = new Map();
  for (let k = 0; k < 6; k++) {
    const b = quiet(130, { p: 2 + k, t0: T0 });
    for (const i of [50, 100]) { const prev = b.c[i - 1], c = prev * 1.5; set(b, i, prev * 1.1, c * 1.01, prev * 1.05, c, 200000 * (15 + 10 * k)); }
    m.set('S' + k, b);
  }
  const r = BT.runSpikeBacktest({ barsBySym: m, meta: { source: 'yahoo' } });
  assert.equal(r.grid.length, 24);
  assert.ok(r.signals >= 6);
  assert.equal(r.defaultKey, 'open-h3-stop-v20');
  assert.ok(r.default.trades > 0);
  assert.ok(r.walkForward.inSample.months > 0 && r.walkForward.outSample.months > 0);
  assert.ok(r.recent.length > 0 && r.recent.length <= 10);
  const v10 = r.grid.find(g => g.key === 'open-h3-stop-v10'), v40 = r.grid.find(g => g.key === 'open-h3-stop-v40');
  assert.ok(v10.trades >= v40.trades, 'a higher volume multiple never adds trades');
  const md = BT.buildReport(r);
  for (const w of ['انحياز البقاء', 'الانزلاق', 'الإيقاف', 'الطرح', 'مو نصيحة مالية', 'خارج العينة', 'آخر 10 إشارات']) assert.ok(md.includes(w), w);
});

/* ---------- جلب البيانات (عينات ثابتة، بدون شبكة) ---------- */

const NASDAQ_TXT = `Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares
AAPL|Apple Inc. - Common Stock|Q|N|N|100|N|N
QQQ|Invesco QQQ Trust, Series 1|G|N|N|100|Y|N
ABCDW|ABC Acquisition Corp - Warrant|S|N|N|100|N|N
ABCDU|ABC Acquisition Corp - Units|S|N|N|100|N|N
ZXZZT|NASDAQ TEST STOCK|Q|Y|N|100|N|N
UNIT|Uniti Group Inc. - Common Stock|Q|N|N|100|N|N
File Creation Time: 1002202621:31|||||||`;
const OTHER_TXT = `ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol
F|Ford Motor Company Common Stock|N|F|N|100|N|F
BRK.B|Berkshire Hathaway Inc. Class B|N|BRK.B|N|100|N|BRK.B
SPY|SPDR S&P 500 ETF Trust|P|SPY|Y|100|N|SPY
ABR$D|Arbor Realty Trust 6.375% Series D Preferred|N|ABRpD|N|100|N|ABR$D
XYZR|XYZ Corp Rights|A|XYZR|N|100|N|XYZR
GME|GameStop Corporation Common Stock|N|GME|N|100|N|GME
File Creation Time: 1002202621:31||||||`;

test('NASDAQ Trader symbol files → common stocks only', () => {
  const u = F.buildUniverse(NASDAQ_TXT, OTHER_TXT);
  assert.deepEqual(u.symbols, ['AAPL', 'F', 'GME', 'UNIT']);
  assert.deepEqual(u.info.AAPL, { name: 'Apple Inc.', exchange: 'NASDAQ' });
  assert.equal(u.info.F.exchange, 'NYSE');
  assert.equal(F.isCommonStock('ABCW', 'ABC Corp - Warrant'), false);
  assert.equal(F.isCommonStock('SNOW', 'Snowflake Inc. Common Stock'), true); // ينتهي بـ W لكن الاسم سهم عادي
  assert.equal(F.isCommonStock('A^B', 'x'), false);
});

const ET_OPEN = d => Date.parse(d + 'T13:30:00Z') / 1000; // 09:30 EDT
test('Yahoo daily parser: date-aligned bars, skips nulls, drops the unfinished session', () => {
  const days = ['2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01'];
  const payload = { chart: { error: null, result: [{
    meta: { longName: 'Apple Inc.', currentTradingPeriod: { regular: { start: ET_OPEN('2026-10-01'), end: ET_OPEN('2026-10-01') + 6.5 * 3600 } } },
    timestamp: days.map(ET_OPEN),
    indicators: { quote: [{ open: [1, 2, null, 4], high: [1.1, 2.2, 3.3, 4.4], low: [0.9, 1.8, 2.7, 3.6], close: [1, 2, 3, 4], volume: [100, 200, 300, 400] }] },
  }] } };
  const mid = (ET_OPEN('2026-10-01') + 3600) * 1000, afterClose = (ET_OPEN('2026-10-01') + 8 * 3600) * 1000;
  const live = parseYahooDaily(payload, mid);
  assert.deepEqual(live.t, [Date.UTC(2026, 8, 28), Date.UTC(2026, 8, 29)]);
  const closed = parseYahooDaily(payload, afterClose);
  assert.deepEqual(closed.c, [1, 2, 4]);
  assert.deepEqual(Object.keys(closed), ['t', 'o', 'h', 'l', 'c', 'v']);
  assert.throws(() => parseYahooDaily({ chart: { error: { code: 'Not Found', description: 'No data found, symbol may be delisted' } } }), e => e.code === 'no_data');
  assert.throws(() => parseYahooDaily({ nope: 1 }), e => e.code === 'bad_shape');
});

test('Yahoo 5-minute parser keeps the regular session only', () => {
  const t = [Date.UTC(2026, 8, 30, 13, 25), Date.UTC(2026, 8, 30, 13, 30), Date.UTC(2026, 8, 30, 19, 55), Date.UTC(2026, 8, 30, 20, 0), Date.UTC(2026, 8, 30, 14, 2, 17)].map(x => x / 1000);
  const q = { open: [1, 2, 3, 4, 5], high: [1, 2, 3, 4, 5], low: [1, 2, 3, 4, 5], close: [1, 2, 3, 4, 5], volume: [1, 2, 3, 4, 5] };
  const b = parseYahoo5m({ chart: { result: [{ timestamp: t, indicators: { quote: [q] } }] } });
  assert.deepEqual(b.c, [2, 3]);
});

const fakeRes = (status, body) => ({ status, ok: status >= 200 && status < 300, json: async () => body });
test('Yahoo fetch retries 429 on query2, then incremental refresh merges 5 days', async () => {
  const seen = [];
  const day = d => ({ chart: { result: [{ meta: {}, timestamp: d.map(ET_OPEN), indicators: { quote: [{ open: d.map(() => 2), high: d.map(() => 2.1), low: d.map(() => 1.9), close: d.map(() => 2), volume: d.map(() => 1000) }] } }] } });
  const fetchImpl = async url => { seen.push(url); return seen.length === 1 ? fakeRes(429, null) : fakeRes(200, day(['2026-09-30', '2026-10-01'])); };
  const net = { fetchImpl, wait: async () => {}, pace: async () => {} };
  const cached = { t: [Date.UTC(2026, 8, 29), Date.UTC(2026, 8, 30)], o: [2, 2], h: [2.1, 2.1], l: [1.9, 1.9], c: [2, 2], v: [1000, 1000] };
  const r = await F.updateSymbol('BRK.B', cached, 'incremental', net, Date.UTC(2026, 9, 2));
  assert.match(seen[0], /query1\.finance\.yahoo\.com\/v8\/finance\/chart\/BRK-B\?interval=1d&range=5d/);
  assert.match(seen[1], /query2\.finance\.yahoo\.com/);
  assert.equal(r.mode, 'incremental');
  assert.deepEqual(r.bars.t, [Date.UTC(2026, 8, 29), Date.UTC(2026, 8, 30), Date.UTC(2026, 9, 1)]);
  // تغيّر التعديل (تقسيم) → تنزيل كامل سنتين
  const urls = [];
  const split = async url => { urls.push(url); return fakeRes(200, url.includes('range=5d') ? { chart: { result: [{ meta: {}, timestamp: [ET_OPEN('2026-09-30')], indicators: { quote: [{ open: [1], high: [1.05], low: [0.95], close: [1], volume: [5] }] } }] } } : day(['2026-09-29', '2026-09-30'])); };
  const r2 = await F.updateSymbol('X', cached, 'incremental', { fetchImpl: split, wait: async () => {} }, Date.UTC(2026, 9, 2));
  assert.equal(r2.mode, 'full'); assert.match(urls[1], /range=2y/);
  // 404 برمز غير موجود: بدون إعادة
  let calls = 0;
  await assert.rejects(F.updateSymbol('ZZZZ', null, 'full', { fetchImpl: async () => { calls++; return fakeRes(404, { chart: { error: { description: 'No data found, symbol may be delisted' } } }); }, wait: async () => {} }), e => e.code === 'no_data');
  assert.equal(calls, 1);
});

test('fetch plan: full without cache, incremental under 7 days, skip on a same-night rerun; Massive days → per-symbol bars', async () => {
  const now = Date.UTC(2026, 9, 2), c = { t: [1] };
  assert.equal(F.planFetch(null, null, now), 'full');
  assert.equal(F.planFetch({ at: now - 3 * DAY }, c, now), 'incremental');
  assert.equal(F.planFetch({ at: now - 8 * DAY }, c, now), 'full');
  assert.equal(F.planFetch({ at: now - 3600e3 }, c, now), 'skip');
  const days = [{ date: '2026-09-29', rows: [['AAA', 1, 2, 0.5, 1.5, 100], ['WWW', 1, 1, 1, 1, 1]] }, { date: '2026-09-30', rows: [['AAA', 2, 3, 1, 2.5, 200]] }];
  const bySym = F.groupedToSymbols(days, new Set(['AAA']));
  assert.deepEqual(Object.keys(bySym), ['AAA']);
  assert.deepEqual(bySym.AAA.c, [1.5, 2.5]);
  let order = []; await F.runPool([1, 2, 3, 4, 5], async x => { order.push(x); }, 2);
  assert.deepEqual(order.sort(), [1, 2, 3, 4, 5]);
  const waits = []; let clock = 0;
  const pace = F.makePacer(100, () => clock, async ms => { waits.push(ms); });
  await Promise.all([pace(), pace(), pace()]);
  assert.deepEqual(waits, [100, 200]);
});

test('nightly scan output has the documented shape', () => {
  const m = new Map([['AAA', withSpike(50, 49)], ['BBB', quiet(50)]]);
  const out = buildSpikesToday({ barsBySym: m, names: { AAA: 'A Inc.' }, source: 'yahoo', now: new Date('2026-02-24T22:00:00Z') });
  assert.equal(out.day, new Date(T0 + 49 * DAY).toISOString().slice(0, 10));
  assert.equal(out.signals.length, 1);
  const s = out.signals[0];
  for (const k of ['sym', 'name', 'close', 'chgPct', 'volMult', 'highD', 'lowD', 'entryDate', 'exitDate', 'bars40']) assert.ok(k in s, k);
  assert.equal(s.name, 'A Inc.');
  assert.deepEqual(['t', 'o', 'h', 'l', 'c'].every(k => s.bars40[k].length === 40), true);
  assert.equal(out.generatedAt, '2026-02-24T22:00:00.000Z');
});

/* ---------- التطبيق والخادم ---------- */

test('demo market is deterministic and produces signals (and a near miss that fails)', () => {
  const now = Date.UTC(2026, 9, 3, 12);
  const a = demoSpikeMarket(now), b = demoSpikeMarket(now);
  assert.deepEqual([...a.bars.get('DSPA').c], [...b.bars.get('DSPA').c]);
  const sigs = scanSpikes(a.bars, -1);
  assert.ok(sigs.length >= 1);
  assert.ok(!sigs.some(s => s.sym === 'DSPX'), 'the fade closes far from its high');
  assert.equal(a.dates[a.dates.length - 1], '2026-10-02'); // السبت → الجمعة
});

const NIGHTLY = { generatedAt: '2026-10-02T21:40:00Z', day: '2026-10-02', source: 'yahoo', signals: [
  { sym: 'REAL', name: 'Real Co', close: 3, chgPct: 30, volMult: 25, highD: 3.1, lowD: 2.4, entryDate: '2026-10-05', exitDate: '2026-10-07', bars40: { t: [1], o: [1], h: [1], l: [1], c: [1] } },
  { sym: 'HARAM', name: 'H Co', close: 2, chgPct: 25, volMult: 22, highD: 2.1, lowD: 1.6, entryDate: '2026-10-05', exitDate: '2026-10-07', bars40: { t: [1], o: [1], h: [1], l: [1], c: [1] } },
] };

test('spikesFor: real local store > nightly file > demo > none, with the Yaqeen filter', () => {
  const yq = { yaqeen: { HARAM: 'غير شرعي', REAL: 'شرعي' } };
  // تجريبي بدون ملف ليلي
  const demo = spikesFor(demoProviders, {});
  assert.equal(demo.source, 'demo'); assert.equal(demo.demo, true); assert.ok(demo.signals.length >= 1);
  // الملف الليلي يغلب التجريبي، وفلتر يقين يستبعد غير الشرعي
  const n = spikesFor(demoProviders, yq, [null, NIGHTLY]);
  assert.equal(n.source, 'nightly'); assert.equal(n.day, '2026-10-02');
  assert.deepEqual(n.signals.map(s => [s.sym, s.yaqeen]), [['REAL', 'شرعي']]);
  assert.deepEqual(n.yaqeenExcluded, { HARAM: 'غير شرعي' });
  assert.equal(spikesFor(demoProviders, { ...yq, excludeHaram: false }, [NIGHTLY]).signals.length, 2);
  // الأحدث بين نسختين
  const older = { ...NIGHTLY, day: '2026-10-01', signals: [] };
  assert.equal(spikesFor(demoProviders, {}, [older, NIGHTLY]).day, '2026-10-02');
  // مخزن Massive حقيقي بأيام كافية → حساب محلي (بدون أي طلب)
  const m = demoSpikeMarket(Date.UTC(2026, 9, 3));
  const store = { state: { days: 60 }, allBars: () => ({ bars: m.bars, dates: m.dates, commonStocks: new Set(['DSPA', 'DSPB']) }), profile: m.profile };
  const local = spikesFor({ demo: false, spikeMarket: () => ({ ...store.allBars(), profile: store.profile }) }, {}, [NIGHTLY]);
  assert.equal(local.source, 'local');
  assert.deepEqual(local.signals.map(s => s.sym).sort(), ['DSPA', 'DSPB']);
  // مخزن بأيام قليلة → يرجع للملف الليلي؛ ولا شيء → none
  const pv = buildProviders({ massiveKey: 'k', alphaKey: '', store: { ...store, state: { days: 20 } } });
  assert.equal(spikesFor(pv, {}, [NIGHTLY]).source, 'nightly');
  assert.equal(spikesFor(pv, {}, []).source, 'none');
});

test('store.allBars exposes the stored market without new requests', async () => {
  const realFetch = globalThis.fetch; let calls = 0;
  globalThis.fetch = async () => { calls++; throw new Error('no network'); };
  try {
    const rows = d => [['AAA', 1, 2, 0.5, 1.5, 100 + d]];
    const storage = { listDays: async () => ['2026-09-29', '2026-09-30'], readDay: async d => rows(d.length), writeDay: async () => {}, removeDay: async () => {}, readMeta: async () => null, writeMeta: async () => {} };
    const store = createMassiveStore({ apiKey: 'k', storage, log: () => {} });
    await store.loadFromDisk();
    const all = store.allBars();
    assert.deepEqual(all.dates, ['2026-09-29', '2026-09-30']);
    assert.deepEqual(all.bars.get('AAA').c, [1.5, 1.5]);
    assert.equal(calls, 0);
  } finally { globalThis.fetch = realFetch; }
});

test('GET/POST /api/spikes in demo mode, and the nightly file on disk wins', async () => {
  let d = await (await fetch(base + '/api/spikes')).json();
  assert.equal(d.source, 'demo'); assert.equal(d.demo, true);
  assert.ok(d.signals.length >= 1);
  const s = d.signals[0];
  for (const k of ['sym', 'name', 'close', 'chgPct', 'volMult', 'highD', 'lowD', 'entryDate', 'exitDate', 'bars40', 'yaqeen']) assert.ok(k in s, k);
  const yq = encodeURIComponent(JSON.stringify({ [s.sym]: 'غير شرعي' }));
  d = await (await fetch(base + '/api/spikes?yaqeen=' + yq)).json();
  assert.ok(!d.signals.some(x => x.sym === s.sym)); assert.equal(d.yaqeenExcluded[s.sym], 'غير شرعي');
  d = await (await fetch(base + '/api/spikes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ nightly: NIGHTLY }) })).json();
  assert.equal(d.source, 'nightly');
  await writeFile(path.join(LAB, 'spikes-today.json'), JSON.stringify({ ...NIGHTLY, day: '2026-10-05' }));
  d = await (await fetch(base + '/api/spikes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ nightly: NIGHTLY }) })).json();
  assert.equal(d.day, '2026-10-05');
  assert.equal((await fetch(base + '/api/lab/spike')).status, 404);
  await writeFile(path.join(LAB, 'spike.json'), JSON.stringify({ generatedAt: 'x', default: { trades: 3, winRate: 0.5, avgRet: 0.01 }, trades: [{}] }));
  const lab = await (await fetch(base + '/api/lab/spike')).json();
  assert.equal(lab.default.trades, 3); assert.ok(!('trades' in lab), 'trades are not sent to the app');
});

test('RASED_LOCAL.spikes() (createClientApp) in demo mode, and with a bundled nightly file', async () => {
  const mem = () => { const m = new Map(); return { listDays: async () => [], readDay: async d => m.get(d), writeDay: async (d, r) => m.set(d, r), removeDay: async d => m.delete(d), readMeta: async () => null, writeMeta: async () => {} }; };
  const app = createClientApp({ storage: mem(), keysStore: { load: () => ({}), save() {} } });
  const d = await app.spikes({});
  assert.equal(d.source, 'demo'); assert.ok(d.signals.length >= 1);
  const n = await app.spikes({ nightly: NIGHTLY, yaqeen: { HARAM: 'غير شرعي' } });
  assert.equal(n.source, 'nightly'); assert.deepEqual(n.signals.map(s => s.sym), ['REAL']);
  const server = await (await fetch(base + '/api/spikes')).json();
  assert.deepEqual(Object.keys(d).sort(), Object.keys(server).sort(), 'same shape as /api/spikes');
  app.dispose();
});

test('trend 5-minute bars from Yahoo without a key, and a labelled demo fallback when Yahoo fails', async () => {
  const t = [Date.UTC(2026, 8, 30, 13, 30), Date.UTC(2026, 8, 30, 13, 35)].map(x => x / 1000);
  const ok = async () => fakeRes(200, { chart: { result: [{ timestamp: t, indicators: { quote: [{ open: [1, 2], high: [1, 2], low: [1, 2], close: [1, 2], volume: [1, 2] }] } }] } });
  const pv = buildProviders({ massiveKey: '', alphaKey: '', yahoo: true, fetchImpl: ok });
  assert.equal(pv.demo, true, 'scan stays demo without keys');
  const d = await trendFor(pv, 'AAPL');
  assert.equal(d.demo, false); assert.equal(d.source, 'yahoo'); assert.deepEqual(d.bars.c, [1, 2]);
  const bad = buildProviders({ massiveKey: '', alphaKey: 'a', yahoo: true, fetchImpl: async () => { throw new Error('offline'); } });
  const f = await trendFor(bad, 'MSFT');
  assert.equal(f.demo, true); assert.match(f.fallback, /Yahoo/);
  // بدون yahoo (الاختبارات/النسخة المستقلة): نفس السلوك القديم
  assert.equal(buildProviders({ massiveKey: '', alphaKey: '' }), demoProviders);
});
