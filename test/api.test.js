import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';

delete process.env.ALPHA_VANTAGE_KEY; // يضمن الوضع التجريبي بدون استهلاك حصة
const { server } = await import('../server/index.js');
let base;
before(() => new Promise(r => server.listen(0, () => { base = `http://127.0.0.1:${server.address().port}`; r(); })));
after(() => new Promise(r => server.close(r)));

const scan = body => fetch(base + '/api/scan', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

test('demo scan returns at most 2 picks with explicit sources and yaqeen exclusions', async () => {
  const res = await scan({ tickers: ['AAPL', 'MSFT', 'NVDA', 'LCID', 'aapl'], yaqeen: { LCID: 'غير شرعي' }, volMult: 0.5 });
  assert.equal(res.status, 200);
  const d = await res.json();
  assert.equal(d.demo, true);
  assert.equal(d.counts.requested, 4);
  assert.deepEqual(d.yaqeenExcluded, { LCID: 'غير شرعي' });
  assert.ok(d.picks.length <= 2 && d.picks.length > 0);
  for (const p of d.picks) {
    assert.equal(p.sources.news.active, false);
    assert.equal(p.bars.c.length, 60);
    assert.ok(Number.isFinite(p.trade.entry) && Number.isFinite(p.trade.stop) && Number.isFinite(p.trade.target));
  }
});

test('rejects empty and oversized lists', async () => {
  assert.equal((await scan({ tickers: [] })).status, 400);
  assert.equal((await scan({ tickers: Array.from({ length: 30 }, (_, i) => 'T' + i) })).status, 400);
});

test('static files served; path traversal blocked', async () => {
  assert.equal((await fetch(base + '/')).status, 200);
  assert.equal((await fetch(base + '/manifest.webmanifest')).status, 200);
  const r = await fetch(base + '/..%2Fserver%2Fengine.js');
  assert.notEqual(r.status, 200);
});
