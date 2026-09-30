import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { parseGroupedDaily, parseTickersPage, weekdaysBack, buildBars, createMassiveStore } from '../server/massive.js';
import { runScan } from '../server/scan.js';

// شكل الرد حسب توثيق Massive/Polygon (لم يُلاحظ رد حي بعد)
const grouped = rows => ({ status: 'OK', queryCount: rows.length, resultsCount: rows.length, adjusted: true, results: rows });

test('parseGroupedDaily keeps valid rows and drops broken ones', () => {
  const rows = parseGroupedDaily(grouped([
    { T: 'AAPL', v: 5e7, vw: 1, o: 100, c: 101, h: 102, l: 99, t: 1, n: 1 },
    { T: 'BAD', o: 1, c: null, h: 1, l: 1, v: 1 },
    { v: 1, o: 1, c: 1, h: 1, l: 1 },
    { T: 'ZERO', v: 1, o: 1, c: 0, h: 1, l: 1 },
  ]));
  assert.deepEqual(rows, [['AAPL', 100, 102, 99, 101, 5e7]]);
  assert.deepEqual(parseGroupedDaily({ status: 'OK', resultsCount: 0 }), []); // عطلة
});

test('parseGroupedDaily maps error payloads to clear codes', () => {
  assert.throws(() => parseGroupedDaily({ status: 'ERROR', error: "You've exceeded the maximum requests per minute" }), e => e.code === 'rate_limited');
  assert.throws(() => parseGroupedDaily({ status: 'NOT_AUTHORIZED', message: 'Attempted to request today before end of day' }), e => e.code === 'not_authorized');
  assert.throws(() => parseGroupedDaily({ foo: 1 }), e => e.code === 'bad_shape');
});

test('parseTickersPage returns tickers and next page', () => {
  assert.deepEqual(parseTickersPage({ results: [{ ticker: 'AAPL', name: 'Apple Inc.', primary_exchange: 'XNAS' }, { name: 'x' }, { ticker: 'ZZ' }], next_url: 'https://n' }),
    { tickers: ['AAPL', 'ZZ'], info: { AAPL: { name: 'Apple Inc.', exchange: 'NASDAQ' }, ZZ: { name: null, exchange: null } }, next: 'https://n' });
  assert.throws(() => parseTickersPage({ status: 'ERROR' }));
});

test('weekdaysBack skips weekends and starts today', () => {
  const sat = Date.UTC(2026, 8, 26, 15); // Saturday
  assert.deepEqual(weekdaysBack(sat, 3), ['2026-09-25', '2026-09-24', '2026-09-23']);
  assert.deepEqual(weekdaysBack(Date.UTC(2026, 8, 29, 3), 2), ['2026-09-29', '2026-09-28']);
});

test('buildBars assembles ascending per-ticker series and marks last trading day', () => {
  const b = buildBars([{ date: '2026-09-24', rows: [['A', 1, 2, 0.5, 1.5, 10]] }, { date: '2026-09-25', rows: [['A', 1.5, 3, 1, 2, 20], ['B', 5, 6, 4, 5, 7]] }]);
  assert.deepEqual(b.get('A').c, [1.5, 2]);
  assert.equal(b.get('A').lastDay, 1);
  assert.equal(b.get('B').c.length, 1);
});

// سوق مصطنع مخزّن على القرص: الكون يستبعد الرخيص والخامل وغير «الأسهم العادية» ومن لم يتداول آخر يوم
test('store universe filters by price, dollar volume, type and freshness; runScan uses it', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'rased-'));
  try {
    await mkdir(path.join(dir, 'days'), { recursive: true });
    const dates = weekdaysBack(Date.UTC(2026, 8, 25), 45).reverse();
    for (const [i, date] of dates.entries()) {
      const last = i === dates.length - 1;
      const rows = [
        ['GOOD', 100 + i, 102 + i, 99 + i, 101 + i, last ? 3e6 : 1e6],   // $100M/يوم + قفزة حجم
        ['CHEAP', 2, 2.1, 1.9, 2, 5e7],                                   // سعر < 5
        ['THIN', 50, 51, 49, 50, 1e4],                                    // $0.5M/يوم
        ['SPY', 500, 501, 499, 500, 1e8],                                 // صندوق (ليس سهمًا عاديًا)
        ...(last ? [] : [['STALE', 50, 51, 49, 50, 1e7]]),               // لم يتداول آخر يوم
      ];
      await writeFile(path.join(dir, 'days', `${date}.json`), JSON.stringify(rows));
    }
    await writeFile(path.join(dir, 'tickers.json'), JSON.stringify({ at: Date.now(), tickers: ['GOOD', 'CHEAP', 'THIN', 'STALE'], info: { GOOD: { name: 'Good Corp.', exchange: 'NYSE' } } }));
    const store = createMassiveStore({ apiKey: 'x', dataDir: dir, log: () => {} });
    await store.loadFromDisk();
    assert.equal(store.state.ready, true);
    assert.deepEqual(store.universe({ minPrice: 5, minDollarVol: 20e6, avgDays: 20 }), ['GOOD']);

    const providers = { demo: false, bars: async s => ({ bars: store.bars(s), cached: true }), universe: async o => ({ tickers: store.universe(o), lastDay: store.state.lastDay }), profile: store.profile };
    const { status, body } = await runScan({ mode: 'market', volMult: 1.5 }, providers);
    assert.equal(status, 200);
    assert.deepEqual(body.picks.map(p => p.sym), ['GOOD']);
    assert.equal(body.picks[0].name, 'Good Corp.');                   // الاسم الكامل والبورصة يميّزون السهم
    assert.equal(body.picks[0].exchange, 'NYSE');
    assert.equal(body.all[0].name, 'Good Corp.');
    assert.equal(body.picks[0].sources.news.status, 'off');           // لا يوجد مزوّد أخبار
    assert.match(body.picks[0].sources.earnings.error, /غير مفعّل/);
    assert.equal(body.marketLastDay, dates[dates.length - 1]);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('market mode without a universe provider explains what is missing', async () => {
  const { status, body } = await runScan({ mode: 'market' }, { bars: async () => { throw new Error('x'); } });
  assert.equal(status, 400);
  assert.match(body.error, /Massive/);
});
