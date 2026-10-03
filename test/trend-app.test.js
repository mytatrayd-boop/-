import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// وضع تجريبي بدون شبكة، فاصل طلبات قصير للاختبار، ومجلد مختبر فاضي
for (const k of ['ALPHA_VANTAGE_KEY', 'MASSIVE_API_KEY', 'POLYGON_API_KEY']) delete process.env[k];
process.env.RASED_NO_ENV_FILE = '1';
process.env.MASSIVE_GAP_MS = '60';
const LAB = await mkdtemp(path.join(tmpdir(), 'rased-lab-'));
process.env.RASED_LAB_DIR = LAB;

const { parseAggs5m, createMassiveStore } = await import('../server/massive.js');
const { demoBars5m, demoProviders } = await import('../server/demo.js');
const { buildProviders, trendFor, NO_MASSIVE_MSG } = await import('../server/providers.js');
const { createClientApp } = await import('../server/client.js');
const { etParts, splitWeeks, liveSignal } = await import('../server/trend.js');
const { server } = await import('../server/index.js');

let base;
before(() => new Promise(r => server.listen(0, () => { base = `http://127.0.0.1:${server.address().port}`; r(); })));
after(async () => { await new Promise(r => server.close(r)); await rm(LAB, { recursive: true, force: true }); });

const STATES = ['no-data', 'waiting', 'entered', 'closed', 'no-signal', 'week-over'];
const row = (t, c = 100) => ({ t, o: c, h: c + 1, l: c - 1, c, v: 1000 });

test('parseAggs5m keeps the regular session only, across the DST change', () => {
  const t = [
    Date.UTC(2026, 2, 6, 14, 25), // الجمعة 09:25 EST — قبل الافتتاح
    Date.UTC(2026, 2, 6, 14, 30), // 09:30 EST ✓
    Date.UTC(2026, 2, 6, 20, 55), // 15:55 EST ✓
    Date.UTC(2026, 2, 6, 21, 0),  // 16:00 EST — بعد الإغلاق
    Date.UTC(2026, 2, 7, 15, 0),  // سبت
    Date.UTC(2026, 2, 9, 13, 25), // الاثنين 09:25 EDT — قبل الافتتاح
    Date.UTC(2026, 2, 9, 13, 30), // 09:30 EDT ✓
    Date.UTC(2026, 2, 9, 19, 55), // 15:55 EDT ✓
    Date.UTC(2026, 2, 9, 20, 0),  // 16:00 EDT — بعد الإغلاق
    Date.UTC(2026, 2, 9, 20, 55), // 16:55 EDT (كانت 15:55 بالشتوي) — بعد الإغلاق
  ];
  const results = t.map((x, i) => row(x, 100 + i));
  results.reverse();                                    // غير مرتب
  results.push(row(Date.UTC(2026, 2, 6, 14, 30), 1));   // تكرار
  results.push({ t: Date.UTC(2026, 2, 6, 15, 0), o: 'x', h: 1, l: 1, c: 1, v: 1 }); // صف تالف
  const b = parseAggs5m({ status: 'OK', resultsCount: results.length, results });
  assert.deepEqual(b.t, [t[1], t[2], t[6], t[7]]);
  assert.deepEqual(Object.keys(b), ['t', 'o', 'h', 'l', 'c', 'v']);
  assert.ok(b.t.every(x => { const e = etParts(x); return e.minutes >= 570 && e.minutes < 960 && e.weekday <= 5; }));
  assert.equal(b.c[0], 101);
  assert.deepEqual(parseAggs5m({ status: 'OK', resultsCount: 0 }), { t: [], o: [], h: [], l: [], c: [], v: [] });
  assert.throws(() => parseAggs5m({ status: 'ERROR', error: 'Unknown API Key' }), e => e.code === 'not_authorized');
  assert.throws(() => parseAggs5m({ hello: 1 }), e => e.code === 'bad_shape');
});

test('store.aggs5m calls the 5-minute endpoint through the shared, serialized queue', async () => {
  const realFetch = globalThis.fetch, seen = [];
  globalThis.fetch = async url => {
    seen.push({ url: String(url), at: Date.now() });
    return new Response(JSON.stringify({ status: 'OK', resultsCount: 1, results: [row(Date.UTC(2026, 2, 9, 14, 0))] }), { status: 200 });
  };
  try {
    const store = createMassiveStore({ apiKey: 'k', storage: {}, log: () => {} });
    const from = Date.UTC(2026, 2, 2, 15), to = Date.UTC(2026, 2, 12, 15);
    const [a, b] = await Promise.all([store.aggs5m('AAPL', from, to), store.aggs5m('MSFT', from, to)]);
    assert.equal(a.t.length, 1); assert.equal(b.t.length, 1);
    const u = new URL(seen[0].url);
    assert.equal(u.pathname, '/v2/aggs/ticker/AAPL/range/5/minute/2026-03-02/2026-03-12');
    assert.equal(u.searchParams.get('adjusted'), 'true');
    assert.equal(u.searchParams.get('sort'), 'asc');
    assert.equal(u.searchParams.get('limit'), '50000');
    assert.equal(u.searchParams.get('apiKey'), 'k');
    assert.ok(seen[1].at - seen[0].at >= 55, 'concurrent calls must wait for the gap');
    await assert.rejects(store.aggs5m('bad sym', from, to), e => e.code === 'bad_symbol');
  } finally { globalThis.fetch = realFetch; }
});

test('demo 5-minute generator is deterministic, session-only and produces a signal some of the time', () => {
  const now = Date.UTC(2026, 9, 3, 15); // سبت: الأسبوع كامل
  const a = demoBars5m('AAPL', now), b = demoBars5m('AAPL', now);
  assert.deepEqual(a, b);
  const weeks = splitWeeks(a);
  assert.equal(weeks.length, 2);
  assert.equal(a.t.length, 2 * 5 * 78);
  assert.ok(a.t.every((t, i) => !i || t > a.t[i - 1]));
  assert.ok(a.t.every(t => { const e = etParts(t); return e.minutes >= 570 && e.minutes < 960; }));
  for (let i = 0; i < a.t.length; i++) assert.ok(a.h[i] >= Math.max(a.o[i], a.c[i]) && a.l[i] <= Math.min(a.o[i], a.c[i]) && a.l[i] > 0);

  const syms = ['AAPL', 'MSFT', 'NVDA', 'AMD', 'META', 'TSLA', 'AMZN', 'GOOGL', 'NFLX', 'JPM'];
  const sig = syms.map(s => !!liveSignal(demoBars5m(s, now), undefined, now).signal);
  assert.ok(sig.some(Boolean), 'at least one demo symbol breaks the line');
  assert.ok(sig.some(x => !x), 'and at least one does not');
  // منتصف الاثنين: الشموع تتوقف عند آخر شمعة مكتملة، وأولها نفس شموع الأسبوع الكامل
  const mid = Date.UTC(2026, 8, 28, 16, 2); // 12:02 EDT
  const part = demoBars5m('AAPL', mid);
  assert.ok(part.t[part.t.length - 1] + 5 * 60000 <= mid);
  assert.ok(part.t.length > 390 && part.t.length < a.t.length);
  assert.deepEqual(part.c, a.c.slice(0, part.c.length));
});

test('GET /api/trend in demo mode returns bars + liveSignal, labelled demo', async () => {
  const res = await fetch(base + '/api/trend?sym=aapl');
  assert.equal(res.status, 200);
  const d = await res.json();
  assert.equal(d.demo, true);
  assert.equal(d.sym, 'AAPL');
  assert.ok(d.bars.t.length > 0 && d.bars.t.length === d.bars.c.length);
  assert.equal(d.dataAsOf, d.bars.t[d.bars.t.length - 1]);
  assert.ok(STATES.includes(d.live.state));
  assert.equal(d.profile.name, 'Apple Inc.');
  const bad = await fetch(base + '/api/trend?sym=' + encodeURIComponent('<x>'));
  assert.equal(bad.status, 400);
  assert.equal((await bad.json()).code, 'bad_symbol');
});

test('GET /api/lab/* → 404 with an Arabic message when missing, the file (backtest slimmed) once written', async () => {
  for (const which of ['top5', 'backtest']) {
    const res = await fetch(`${base}/api/lab/${which}`);
    assert.equal(res.status, 404);
    const d = await res.json();
    assert.match(d.error, /ما فيه نتائج اختبار بعد/);
  }
  const top5 = { generatedAt: '2026-10-03T06:30:00Z', method: 'x', minTrades: 8, top: [{ sym: 'AAPL', score: 70, trades: 12, winRate: 0.5, avgR: 0.4, totalR: 4.8, oos: { trades: 5, avgR: 0.2 }, why: 'سبب' }], all: [] };
  await writeFile(path.join(LAB, 'top5.json'), JSON.stringify(top5));
  await writeFile(path.join(LAB, 'backtest.json'), JSON.stringify({ generatedAt: 'g', weeks: [{ weekKey: '2026-09-28', trades: 2, wins: 1, pnl: 50, equityEnd: 10050, returnPct: 0.5 }], account: { start: 10000, end: 10050 }, trades: [{ sym: 'AAPL' }], perSymbol: {} }));
  assert.deepEqual(await (await fetch(base + '/api/lab/top5')).json(), top5);
  const bt = await (await fetch(base + '/api/lab/backtest')).json();
  assert.equal(bt.weeks.length, 1); assert.equal(bt.account.end, 10050);
  assert.equal(bt.trades, undefined);
});

// تخزين في الذاكرة بنفس واجهة IndexedDB
function memStorage() {
  const days = new Map(), meta = new Map();
  return {
    listDays: async () => [...days.keys()], readDay: async d => days.get(d), writeDay: async (d, r) => { days.set(d, r); },
    removeDay: async d => { days.delete(d); }, readMeta: async k => meta.get(k) ?? null, writeMeta: async (k, v) => { meta.set(k, v); },
  };
}
const memKeys = (init = {}) => { let v = init; return { load: () => v, save: k => { v = k; } }; };

test('createClientApp().trend(sym) in demo mode; Alpha-only key → polite "needs Massive" error', async () => {
  const app = createClientApp({ storage: memStorage(), keysStore: memKeys() });
  const d = await app.trend('MSFT');
  assert.equal(d.demo, true);
  assert.ok(d.bars.t.length > 0);
  assert.ok(STATES.includes(d.live.state));
  assert.deepEqual(Object.keys(d).sort(), ['bars', 'dataAsOf', 'demo', 'live', 'profile', 'sym']);
  app.dispose();

  const alpha = createClientApp({ storage: memStorage(), keysStore: memKeys({ alpha: 'a' }) });
  await assert.rejects(alpha.trend('MSFT'), e => e.code === 'no_massive' && e.message === NO_MASSIVE_MSG);
  alpha.dispose();
});

test('store-backed trend5m caches per symbol for 10 minutes and does not cache errors', async () => {
  let calls = 0, fail = true;
  const bars = demoBars5m('AAPL', Date.UTC(2026, 9, 3, 15));
  const store = {
    state: {}, profile: () => ({ name: 'Apple Inc.', exchange: 'NASDAQ' }), bars: () => bars,
    aggs5m: async (sym, from, to) => { calls++; assert.ok(to - from >= 9 * 86400000); if (fail) { fail = false; throw Object.assign(new Error('Massive: تجاوزت حد الطلبات'), { code: 'rate_limited' }); } return bars; },
  };
  const pv = buildProviders({ massiveKey: 'k', alphaKey: '', store });
  await assert.rejects(trendFor(pv, 'AAPL'), e => e.code === 'rate_limited');
  const a = await trendFor(pv, 'AAPL', Date.UTC(2026, 9, 3, 15));
  const b = await trendFor(pv, 'aapl', Date.UTC(2026, 9, 3, 15));
  assert.equal(calls, 2);
  assert.equal(a.demo, false); assert.equal(a.profile.name, 'Apple Inc.');
  assert.deepEqual(a.live, b.live);
  assert.ok(STATES.includes(a.live.state));
  assert.ok(demoProviders.trend5m, 'demo providers expose trend5m');
});
