import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';

// يضمن الوضع التجريبي بدون استهلاك حصة
for (const k of ['ALPHA_VANTAGE_KEY', 'MASSIVE_API_KEY', 'POLYGON_API_KEY']) delete process.env[k];
process.env.RASED_NO_ENV_FILE = '1';
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
    assert.ok(['ok', 'capped', 'error'].includes(p.sources.news.status));
    assert.ok(p.sources.earnings === null || 'reportDate' in p.sources.earnings);
    assert.ok(p.score > 0);
    assert.equal(p.bars.c.length, 60);
    assert.ok(Number.isFinite(p.trade.entry) && Number.isFinite(p.trade.stop) && Number.isFinite(p.trade.target));
  }
});

test('news gate never lets a strongly opposed pick through, and newsMax=0 skips news', async () => {
  const tickers = ['AAPL', 'MSFT', 'NVDA', 'TSLA', 'AMZN', 'GOOGL', 'META', 'AMD', 'NFLX', 'JPM', 'XOM', 'BA'];
  const d = await (await scan({ tickers, volMult: 0.5 })).json();
  for (const r of d.all.filter(r => r.ok && r.news.status === 'ok')) {
    assert.equal(r.newsGated, r.news.aligned <= -d.params.newsGate);
    if (r.newsGated) assert.equal(r.score, 0);
  }
  assert.ok(!d.picks.some(p => p.sources.news.gated));
  const none = await (await scan({ tickers, volMult: 0.5, newsMax: 0 })).json();
  assert.ok(none.all.filter(r => r.ok && r.passesGate).every(r => r.news.status === 'capped' && r.score === r.baseScore));
});

test('market mode scans the whole (demo) universe with no 25-ticker cap and truncates the list', async () => {
  const d = await (await scan({ mode: 'market', volMult: 0.5, minPrice: 1 })).json();
  assert.equal(d.mode, 'market');
  assert.ok(d.counts.requested > 25);
  assert.ok(d.all.length <= 60);
  assert.ok(d.marketLastDay);
  assert.ok(d.picks.length > 0 && d.picks.length <= 2);
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

test('health reports a red demo status when the server has no keys', async () => {
  const h = await (await fetch(base + '/api/health')).json();
  assert.equal(h.status.level, 'red');
  assert.equal(h.status.badge, 'تجريبي');
});
