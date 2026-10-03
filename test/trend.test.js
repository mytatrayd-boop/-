import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TREND_DEFAULTS, TREND_GRID, etParts, splitWeeks, findTrendlines, weeklyTrade, liveSignal } from '../server/trend.js';

// شموع 5 دقائق اصطناعية لأيام يناير 2026 (توقيت شتوي: نيويورك = UTC−5)
const etMs = (date, min) => { const [y, m, d] = date.split('-').map(Number); return Date.UTC(y, m - 1, d, 14, 30) + (min - 570) * 60000; };
const DAYS = ['2026-01-08', '2026-01-09', '2026-01-12', '2026-01-13', '2026-01-14', '2026-01-15', '2026-01-16']; // خميس، جمعة، ثم أسبوع كامل
const MON = 156;          // أول شمعة يوم الاثنين 12 يناير
const BREAK = MON + 12;   // شمعة الكسر 10:30
const WEEK_END = DAYS.length * 78 - 1;

// موجة جيبية بقمم هابطة: القمم عند g = 6 + 24n تقع كلها على خط واحد ميله −0.02 لكل شمعة
const wave = g => 100 - 0.02 * g + 2 * Math.sin(2 * Math.PI * g / 24);

// closeFn(g, prevClose) → إغلاق الشمعة g. overrides[g] = { o, h, l, c, v } لتعديل شمعة بعينها
function makeBars(closeFn, overrides = {}, days = DAYS) {
  const b = { t: [], o: [], h: [], l: [], c: [], v: [] };
  let g = 0;
  for (const d of days) for (let k = 0; k < 78; k++, g++) {
    const prev = g ? b.c[g - 1] : closeFn(0, null);
    const c = closeFn(g, prev), o = prev;
    let bar = { o, h: Math.max(o, c) + 0.05, l: Math.min(o, c) - 0.05, c, v: 1000 };
    if (overrides[g]) bar = { ...bar, ...overrides[g] };
    b.t.push(etMs(d, 570 + 5 * k)); b.o.push(bar.o); b.h.push(bar.h); b.l.push(bar.l); b.c.push(bar.c); b.v.push(bar.v);
  }
  return b;
}
const truncate = (b, n) => Object.fromEntries(Object.entries(b).map(([k, a]) => [k, a.slice(0, n)]));

// سيناريو كسر: موجة حتى الكسر، شمعة الكسر تقفز إلى 99.5 بحجم 5×، ثم after(g, prev)
const breakout = (after, overrides = {}) => makeBars((g, prev) => g < BREAK ? wave(g) : g === BREAK ? 99.5 : after(g, prev), { [BREAK]: { v: 5000 }, ...overrides });
const weekOf = bars => splitWeeks(bars).find(w => w.weekKey === '2026-01-12');

test('etParts: DST change (EST → EDT, March 8 2026)', () => {
  assert.deepEqual(etParts(Date.UTC(2026, 2, 6, 14, 30)), { date: '2026-03-06', weekday: 5, minutes: 570 }); // 09:30 EST
  assert.deepEqual(etParts(Date.UTC(2026, 2, 9, 13, 30)), { date: '2026-03-09', weekday: 1, minutes: 570 }); // 09:30 EDT
  assert.deepEqual(etParts(Date.UTC(2026, 2, 9, 19, 55)), { date: '2026-03-09', weekday: 1, minutes: 955 });
  assert.deepEqual(etParts(Date.UTC(2026, 10, 2, 14, 30)), { date: '2026-11-02', weekday: 1, minutes: 570 }); // بعد العودة للشتوي
  assert.equal(etParts(Date.UTC(2026, 2, 8, 6, 59)).minutes, 1 * 60 + 59);  // 01:59 EST
  assert.equal(etParts(Date.UTC(2026, 2, 8, 7, 0)).minutes, 3 * 60);        // 03:00 EDT
});

test('splitWeeks: normal weeks and a Monday-holiday week (MLK 2026-01-19)', () => {
  const bars = makeBars(wave, {}, ['2026-01-15', '2026-01-16', '2026-01-20', '2026-01-21', '2026-01-23']);
  const w = splitWeeks(bars);
  assert.equal(w.length, 2);
  assert.deepEqual(w[0], { weekKey: '2026-01-12', start: 0, end: 155, firstDay: '2026-01-15', lastDay: '2026-01-16' });
  assert.deepEqual(w[1], { weekKey: '2026-01-19', start: 156, end: 389, firstDay: '2026-01-20', lastDay: '2026-01-23' });
  assert.deepEqual(splitWeeks({ t: [], o: [], h: [], l: [], c: [], v: [] }), []);
});

test('findTrendlines: finds the descending resistance through the wave peaks', () => {
  const bars = makeBars(wave);
  const { resistance: L, support: S } = findTrendlines(bars, BREAK - 1);
  assert.ok(L && L.slope < 0 && L.p2 < L.p1 && L.i2 > L.i1);
  assert.ok(Math.abs(L.slope + 0.02) < 1e-9);
  assert.ok(L.touches >= 4);
  assert.ok(L.i2 <= BREAK - 1 - TREND_DEFAULTS.pivotK);
  assert.equal(S, null); // القيعان هابطة أيضًا: لا دعم صاعد
});

test('clean breakout on Monday → hits target', () => {
  const bars = breakout((g, prev) => prev + 0.1);
  const r = weeklyTrade(bars, weekOf(bars));
  const s = r.signal;
  assert.equal(s.idx, BREAK); assert.equal(s.entryIdx, BREAK + 1);
  assert.equal(s.entry, bars.o[BREAK + 1]);
  assert.ok(s.stop < s.entry && s.target > s.entry);
  assert.ok(Math.abs((s.target - s.entry) - TREND_DEFAULTS.rr * (s.entry - s.stop)) < 1e-9);
  assert.equal(r.exit.how, 'target');
  assert.equal(r.exit.price, s.target);
  assert.ok(Math.abs(r.r - TREND_DEFAULTS.rr) < 1e-9);
  assert.ok(r.pct > 0);
  assert.ok(typeof s.reason === 'string' && s.reason.length > 0);
});

test('breakout then drop → hits stop at exactly −1R', () => {
  const bars = breakout((g, prev) => prev - 0.1);
  const r = weeklyTrade(bars, weekOf(bars));
  assert.equal(r.exit.how, 'stop');
  assert.equal(r.exit.price, r.signal.stop);
  assert.ok(Math.abs(r.r + 1) < 1e-9);
});

test('a bar touching both stop and target → stop wins', () => {
  const bars = breakout((g, prev) => prev, { [BREAK + 3]: { h: 200, l: 50 } });
  const r = weeklyTrade(bars, weekOf(bars));
  assert.equal(r.exit.idx, BREAK + 3);
  assert.equal(r.exit.how, 'stop');
  assert.ok(Math.abs(r.r + 1) < 1e-9);
});

test('gap through the stop fills at the bar open (worse than −1R)', () => {
  const pre = breakout((g, prev) => prev);
  const s0 = weeklyTrade(pre, weekOf(pre)).signal;
  const gapOpen = s0.stop - 1;
  const bars = breakout((g, prev) => (g >= BREAK + 5 ? gapOpen : prev), { [BREAK + 5]: { o: gapOpen, h: gapOpen + 0.05, l: gapOpen - 0.05 } });
  const r = weeklyTrade(bars, weekOf(bars));
  assert.equal(r.signal.stop, s0.stop);
  assert.equal(r.exit.how, 'stop');
  assert.equal(r.exit.idx, BREAK + 5);
  assert.equal(r.exit.price, gapOpen);
  assert.ok(r.r < -1);
});

test('gap through the target fills at the bar open', () => {
  const pre = breakout((g, prev) => prev);
  const s0 = weeklyTrade(pre, weekOf(pre)).signal;
  const gapOpen = s0.target + 1;
  const bars = breakout((g, prev) => (g >= BREAK + 4 ? gapOpen : prev), { [BREAK + 4]: { o: gapOpen, h: gapOpen + 0.05, l: gapOpen - 0.05 } });
  const r = weeklyTrade(bars, weekOf(bars));
  assert.equal(r.exit.how, 'target');
  assert.equal(r.exit.price, gapOpen);
  assert.ok(r.r > TREND_DEFAULTS.rr);
});

test('no entry on Tuesday even when the line breaks', () => {
  const TUE = MON + 78 + 12;
  const bars = makeBars((g, prev) => g < TUE ? wave(g) : g === TUE ? 99 : prev + 0.1, { [TUE]: { v: 5000 } });
  // تأكيد أن الكسر يحدث فعلًا يوم الثلاثاء
  const L = findTrendlines(bars, TUE).resistance;
  assert.ok(L && bars.c[TUE] > L.p1 + L.slope * (TUE - L.i1));
  const r = weeklyTrade(bars, weekOf(bars));
  assert.equal(r.signal, null); assert.equal(r.exit, null); assert.equal(r.r, null); assert.equal(r.pct, null);
});

test('no entry in the opening minutes nor in the last 30 minutes of Monday', () => {
  const early = MON + 1, late = MON + 72; // 09:35 و 15:30 (الدخول 15:35)
  for (const g0 of [early, late]) {
    const bars = makeBars((g, prev) => g < g0 ? wave(g) : g === g0 ? 99.5 : prev, { [g0]: { v: 5000 } });
    assert.equal(weeklyTrade(bars, weekOf(bars)).signal, null, `bar ${g0}`);
  }
});

test('volume confirmation: a weak-volume break is ignored unless volMult = 0', () => {
  const bars = breakout((g, prev) => prev + 0.1, { [BREAK]: { v: 1000 } });
  const w = weekOf(bars);
  assert.equal(weeklyTrade(bars, w).signal?.idx === BREAK, false);
  assert.equal(weeklyTrade(bars, w, { ...TREND_DEFAULTS, volMult: 0 }).signal.idx, BREAK);
});

test('no stop/target in the week → exit at the Friday close', () => {
  const bars = breakout((g, prev) => 99.5 + (g % 2 ? 0.05 : -0.05));
  const r = weeklyTrade(bars, weekOf(bars));
  assert.equal(r.exit.how, 'friday');
  assert.equal(r.exit.idx, WEEK_END);
  assert.equal(r.exit.price, bars.c[WEEK_END]);
  assert.equal(etParts(r.exit.t).weekday, 5);
  assert.ok(Math.abs(r.pct - (bars.c[WEEK_END] / r.signal.entry - 1)) < 1e-12);
});

test('stop never sits above the entry, even with a big gap-up entry', () => {
  const bars = breakout((g, prev) => prev, { [BREAK + 1]: { o: 110, h: 110.05, l: 99.4 } });
  const s = weeklyTrade(bars, weekOf(bars)).signal;
  assert.ok(s.stop < s.entry);
  assert.ok(s.entry - s.stop <= TREND_DEFAULTS.maxStopAtr * 10);
});

test('no look-ahead: truncated arrays give the same trendlines and the same signal', () => {
  const bars = breakout((g, prev) => prev + 0.1);
  for (let i = 0; i < bars.t.length; i += 7) {
    assert.deepEqual(findTrendlines(truncate(bars, i + 1), i), findTrendlines(bars, i), `bar ${i}`);
  }
  const full = weeklyTrade(bars, weekOf(bars));
  // البيانات تنتهي عند شمعة الدخول: نفس الإشارة، بلا خروج بعد
  const cut = truncate(bars, full.signal.entryIdx + 1);
  const part = weeklyTrade(cut, weekOf(cut));
  assert.deepEqual(part.signal, full.signal);
  assert.equal(part.exit, null);
  // إضافة أسبوع لاحق لا تغيّر شيئًا في هذا الأسبوع
  const more = makeBars((g, prev) => g < BREAK ? wave(g) : g === BREAK ? 99.5 : prev + 0.1, { [BREAK]: { v: 5000 } }, [...DAYS, '2026-01-20', '2026-01-21']);
  assert.deepEqual(weeklyTrade(more, weekOf(more)), full);
});

test('liveSignal states', () => {
  const T = (b, extra = 5) => b.t[b.t.length - 1] + extra * 60000;
  assert.equal(liveSignal({ t: [], o: [], h: [], l: [], c: [], v: [] }, TREND_DEFAULTS, Date.UTC(2026, 0, 12, 15)).state, 'no-data');

  const flat = makeBars(wave);
  const w1 = truncate(flat, MON + 6);
  const waiting = liveSignal(w1, TREND_DEFAULTS, T(w1));
  assert.equal(waiting.state, 'waiting'); assert.equal(waiting.weekKey, '2026-01-12');
  assert.ok(waiting.line && waiting.line.slope < 0);
  assert.equal(waiting.last.price, w1.c[w1.c.length - 1]);

  const ns = truncate(flat, MON + 78 + 20);
  assert.equal(liveSignal(ns, TREND_DEFAULTS, T(ns)).state, 'no-signal');
  assert.equal(liveSignal(flat, TREND_DEFAULTS, Date.UTC(2026, 0, 17, 15)).state, 'week-over');

  const up = breakout((g, prev) => prev + 0.1);
  const en = truncate(up, BREAK + 3);
  const entered = liveSignal(en, TREND_DEFAULTS, T(en));
  assert.equal(entered.state, 'entered');
  assert.ok(entered.signal.stop < entered.signal.entry && entered.exit === null);

  const cl = truncate(up, MON + 78 + 10);
  const closed = liveSignal(cl, TREND_DEFAULTS, T(cl));
  assert.equal(closed.state, 'closed'); assert.equal(closed.exit.how, 'target');

  // كسر على آخر شمعة متاحة: ما زلنا ننتظر الدخول بافتتاح التالية
  const pend = truncate(up, BREAK + 1);
  const pw = liveSignal(pend, TREND_DEFAULTS, T(pend));
  assert.equal(pw.state, 'waiting'); assert.equal(pw.pendingBreak.idx, BREAK);

  const fri = breakout((g, prev) => 99.5 + (g % 2 ? 0.05 : -0.05));
  const over = liveSignal(fri, TREND_DEFAULTS, T(fri, 60));
  assert.equal(over.state, 'week-over'); assert.equal(over.exit.how, 'friday');
});

test('TREND_GRID: small sweep over existing parameters', () => {
  const keys = Object.keys(TREND_GRID);
  assert.ok(keys.length >= 3 && keys.length <= 4);
  for (const k of keys) {
    assert.ok(k in TREND_DEFAULTS, k);
    assert.ok(TREND_GRID[k].length >= 2 && TREND_GRID[k].length <= 4);
    assert.ok(TREND_GRID[k].includes(TREND_DEFAULTS[k]));
  }
});
