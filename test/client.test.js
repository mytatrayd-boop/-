import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createClientApp, cleanKey } from '../server/client.js';
import { weekdaysBack } from '../server/massive.js';

// تخزين في الذاكرة بنفس واجهة IndexedDB
function memStorage() {
  const days = new Map(), meta = new Map();
  return {
    days, meta,
    listDays: async () => [...days.keys()], readDay: async d => days.get(d), writeDay: async (d, r) => { days.set(d, r); },
    removeDay: async d => { days.delete(d); }, readMeta: async k => meta.get(k) ?? null, writeMeta: async (k, v) => { meta.set(k, v); },
  };
}
const memKeys = (init = {}) => { let v = init; return { load: () => v, save: k => { v = k; } }; };

test('no keys → demo scan and a red status that points to the keys screen', async () => {
  const app = createClientApp({ storage: memStorage(), keysStore: memKeys() });
  const st = app.status();
  assert.equal(st.level, 'red');
  assert.match(st.lights[0].fix, /الإعدادات/);
  const { status, body } = await app.runScan({ tickers: ['AAPL', 'MSFT'], volMult: 0.5 });
  assert.equal(status, 200);
  assert.equal(body.demo, true);
});

test('pasted keys are cleaned; a stored market scans for real with names, and a rejected key turns the sync light red', async () => {
  assert.equal(cleanKey('  "abc123" '), 'abc123');
  const storage = memStorage();
  const dates = weekdaysBack(Date.now(), 45).reverse();
  dates.forEach((d, i) => storage.days.set(d, [['GOOD', 100 + i, 102 + i, 99 + i, 101 + i, i === dates.length - 1 ? 3e6 : 1e6]]));
  storage.meta.set('tickers', { at: Date.now(), tickers: ['GOOD'], info: { GOOD: { name: 'Good Corp.', exchange: 'NASDAQ' } } });

  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({ status: 'ERROR', message: 'Unknown API Key' }), { status: 401 });
  try {
    const keys = memKeys();
    const app = createClientApp({ storage, keysStore: keys });
    app.setKeys({ massive: ' "k" ', alpha: '' });
    assert.deepEqual(keys.load(), { massive: 'k', alpha: '' });
    await app.ready();
    const { body } = await app.runScan({ mode: 'market', volMult: 1.5 });
    assert.equal(body.demo, false);
    assert.deepEqual(body.picks.map(p => [p.sym, p.name]), [['GOOD', 'Good Corp.']]);
    // التعبئة ناقصة (45 يوم) → المزامنة تحاول وتنرفض بالمفتاح
    const sync = app.status().lights.find(l => l.key === 'sync');
    assert.equal(sync.level, 'yellow');
    assert.match(sync.fix, /غير صالح/);
    app.dispose();
  } finally { globalThis.fetch = realFetch; }
});
