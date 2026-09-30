// تطبيق الأندرويد: نفس منطق الخادم لكن يشتغل داخل الجوال — يجلب من Massive و Alpha Vantage مباشرة
// بالمفاتيح اللي يدخلها المستخدم، ويخزّن أيام السوق في IndexedDB. بدون أي اعتماد على Node.
import { createMassiveStore } from './massive.js';
import { buildProviders } from './providers.js';
import { statusLights } from './status.js';
import { runScan } from './scan.js';

const SYNC_EVERY_MS = 60 * 60 * 1000;
export const cleanKey = v => String(v || '').trim().replace(/^["']+|["']+$/g, '').trim();

// محوّل تخزين مخزن Massive على IndexedDB (يوم = سجل)
export function idbStorage(name = 'rased') {
  let dbp = null;
  const db = () => dbp || (dbp = new Promise((res, rej) => {
    const r = indexedDB.open(name, 1);
    r.onupgradeneeded = () => { r.result.createObjectStore('days'); r.result.createObjectStore('meta'); };
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  }));
  const tx = async (store, mode, fn) => {
    const d = await db();
    return new Promise((res, rej) => {
      const t = d.transaction(store, mode), req = fn(t.objectStore(store));
      t.oncomplete = () => res(req.result);
      t.onerror = t.onabort = () => rej(t.error);
    });
  };
  return {
    listDays: () => tx('days', 'readonly', s => s.getAllKeys()),
    readDay: d => tx('days', 'readonly', s => s.get(d)),
    writeDay: (d, rows) => tx('days', 'readwrite', s => s.put(rows, d)),
    removeDay: d => tx('days', 'readwrite', s => s.delete(d)),
    readMeta: k => tx('meta', 'readonly', s => s.get(k)).then(v => v ?? null),
    writeMeta: (k, v) => tx('meta', 'readwrite', s => s.put(v, k)),
  };
}

// keysStore: { load() → {massive, alpha}, save(keys) }
export function createClientApp({ storage, keysStore, log = () => {} }) {
  let keys = { massive: '', alpha: '', ...(keysStore.load() || {}) };
  let store = null, providers = null, timer = null;

  function setup() {
    if (timer) clearInterval(timer);
    store = keys.massive ? createMassiveStore({ apiKey: keys.massive, storage, log }) : null;
    providers = buildProviders({ massiveKey: keys.massive, alphaKey: keys.alpha, store });
    if (store) {
      const s = store;
      s.loaded = s.loadFromDisk().then(() => { if (s === store) return s.sync(); });
      timer = setInterval(() => { if (s === store) s.sync(); }, SYNC_EVERY_MS);
    }
  }
  setup();

  return {
    runScan: req => runScan(req, providers),
    status: () => statusLights({ massiveKey: !!keys.massive, alphaKey: !!keys.alpha, persistentData: true, market: store ? { ...store.state } : null, app: true }),
    keys: () => ({ massive: !!keys.massive, alpha: !!keys.alpha }),
    rawKeys: () => ({ ...keys }),
    setKeys(k) {
      keys = { massive: cleanKey(k.massive), alpha: cleanKey(k.alpha) };
      keysStore.save(keys); setup();
    },
    syncing: () => !!(store && store.state.syncing),
    syncNow: () => store ? store.sync() : Promise.resolve(),
    ready: () => (store ? store.loaded : Promise.resolve()),
    dispose() { if (timer) clearInterval(timer); timer = null; store = null; },
  };
}
