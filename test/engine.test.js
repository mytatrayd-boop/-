import { test } from 'node:test';
import assert from 'node:assert/strict';
import { barsFromAlphaVantage, scoreTicker, buildTrade, parseYaqeenList, applyYaqeen, rankResults, rsiArr } from '../server/engine.js';

const P = { volAvgDays: 20, volMult: 1.5 };

function makeBars(closes, lastVolMult = 1) {
  const n = closes.length, t = [], o = [], h = [], l = [], v = [];
  for (let i = 0; i < n; i++) {
    t.push(Date.UTC(2026, 0, 1) + i * 86400000);
    o.push(i ? closes[i - 1] : closes[0]);
    h.push(Math.max(o[i], closes[i]) + 1); l.push(Math.min(o[i], closes[i]) - 1);
    v.push(i === n - 1 ? 1e6 * lastVolMult : 1e6);
  }
  return { t, o, h, l, c: closes.slice(), v };
}
const trend = (n, step) => Array.from({ length: n }, (_, i) => 100 + i * step + (i % 2 ? 0.3 : -0.3));

test('bullish + volume spike → passes gate, direction up, trade levels above/below entry', () => {
  const s = scoreTicker(makeBars(trend(60, 1), 3), P);
  assert.equal(s.passesGate, true);
  assert.equal(s.direction, 1);
  assert.ok(s.rsiVal > 50 && s.score > 0);
  assert.ok(Math.abs(s.liqRatio - 3) < 1e-9);
  const tr = buildTrade(s, { slAtr: 1.5, rr: 1.5 });
  assert.ok(tr.stop < tr.entry && tr.target > tr.entry);
  assert.ok(Math.abs((tr.target - tr.entry) - 1.5 * (tr.entry - tr.stop)) < 1e-9);
});

test('bearish + volume spike → direction down, stop above entry', () => {
  const s = scoreTicker(makeBars(trend(60, -1), 2), P);
  assert.equal(s.direction, -1);
  const tr = buildTrade(s, { slAtr: 1.5, rr: 1.5 });
  assert.ok(tr.stop > tr.entry && tr.target < tr.entry);
});

test('no liquidity → score is zero regardless of momentum', () => {
  const s = scoreTicker(makeBars(trend(60, 2), 1.2), P);
  assert.equal(s.passesGate, false);
  assert.equal(s.score, 0);
});

test('flat market → near-zero momentum', () => {
  const s = scoreTicker(makeBars(Array.from({ length: 60 }, (_, i) => 100 + (i % 2 ? 0.5 : -0.5)), 3), P);
  assert.ok(s.momentumStrength < 0.1);
});

test('RSI stays within 0..100', () => {
  for (const v of rsiArr(trend(60, 1), 14).filter(x => !isNaN(x))) assert.ok(v >= 0 && v <= 100);
});

test('Alpha Vantage JSON and CSV shapes parse identically (ascending order)', () => {
  const days = Array.from({ length: 30 }, (_, i) => new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10));
  const series = {};
  days.forEach((d, i) => { series[d] = { '1. open': `${100 + i}`, '2. high': `${101 + i}`, '3. low': `${99 + i}`, '4. close': `${100.5 + i}`, '5. volume': `${1000 + i}` }; });
  const csv = 'timestamp,open,high,low,close,volume\n' + days.slice().reverse().map(d => {
    const r = series[d]; return [d, r['1. open'], r['2. high'], r['3. low'], r['4. close'], r['5. volume']].join(',');
  }).join('\n');
  const a = barsFromAlphaVantage({ 'Time Series (Daily)': series });
  const b = barsFromAlphaVantage(csv);
  const c = barsFromAlphaVantage({ content: [{ type: 'text', text: csv }] });
  assert.deepEqual(a, b); assert.deepEqual(a, c);
  assert.ok(a.t[0] < a.t[a.t.length - 1]);
});

test('unexpected / too-short payloads throw', () => {
  assert.throws(() => barsFromAlphaVantage({ foo: 1 }));
  assert.throws(() => barsFromAlphaVantage('timestamp,open,high,low,close,volume\n2026-01-01,1,1,1,1,1'));
});

test('yaqeen: haram excluded by default, mashbooh optional, unknown kept', () => {
  const y = parseYaqeenList('nvda,شرعي\nAAPL, محل نظر\nLCID,غير شرعي\n\nbadline');
  assert.deepEqual(y, { NVDA: 'شرعي', AAPL: 'محل نظر', LCID: 'غير شرعي' });
  const t = ['NVDA', 'AAPL', 'LCID', 'MSFT'];
  assert.deepEqual(applyYaqeen(t, y).kept, ['NVDA', 'AAPL', 'MSFT']);
  assert.deepEqual(applyYaqeen(t, y, { excludeHaram: true, excludeMashbooh: true }).kept, ['NVDA', 'MSFT']);
  assert.deepEqual(applyYaqeen(t, y, { excludeHaram: false }).kept, t);
});

test('rankResults returns top 2 by score and separates rejected/failed', () => {
  const r = rankResults({
    A: { ok: true, passesGate: true, score: 1 }, B: { ok: true, passesGate: true, score: 3 },
    C: { ok: true, passesGate: true, score: 2 }, D: { ok: true, passesGate: false, score: 0 }, E: { ok: false },
  });
  assert.deepEqual(r.top.map(([s]) => s), ['B', 'C']);
  assert.equal(r.gateRejected.length, 1); assert.equal(r.failed.length, 1);
});
