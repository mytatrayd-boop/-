// يبني android/app/src/main/assets/index.html: التطبيق كاملاً داخل الجوال بأسعار حقيقية.
// الطلبات لمواقع الأسعار تمر من جسر Java (RasedNative) لأن WebView يمنعها من الصفحة المحلية (CORS).
// بدون مفاتيح يشتغل تجريبي، والإشارة فوق تقول هذا بالأحمر.
import { writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { buildPage, ROOT } from './bundle.mjs';

const init = `
// fetch → جسر Java لطلبات https (مواقع الأسعار فقط؛ الجسر يرفض غيرها)
(() => {
  const N = window.RasedNative;
  if (!N) return;
  const pending = new Map();
  let seq = 0;
  window.__rasedHttp = (id, status, body) => {
    const p = pending.get(id);
    if (!p) return;
    pending.delete(id);
    if (!status) return p.rej(new TypeError('تعذّر الاتصال: ' + body));
    p.res(new Response(status === 204 ? null : body, { status, headers: { 'Content-Type': 'application/json' } }));
  };
  const orig = window.fetch.bind(window);
  window.fetch = (input, opts) => {
    const url = String(input && input.url ? input.url : input);
    if (!/^https:\\/\\//.test(url)) return orig(input, opts);
    return new Promise((res, rej) => { const id = String(++seq); pending.set(id, { res, rej }); N.get(id, url); });
  };
})();

const KEYS = 'rased.keys';
const app = __mods.client.createClientApp({
  storage: __mods.client.idbStorage(),
  keysStore: {
    load() { try { return JSON.parse(localStorage.getItem(KEYS)) || {}; } catch { return {}; } },
    save(k) { try { localStorage.setItem(KEYS, JSON.stringify(k)); } catch { /* تجاهل */ } },
  },
  log: m => console.log(m),
});
window.RASED_LOCAL = app;
// الشاشة تبقى شغالة أثناء المزامنة
if (window.RasedNative) { let on = false; setInterval(() => { const s = app.syncing(); if (s !== on) { on = s; window.RasedNative.keepAwake(s); } }, 3000); }
`;

const out = await buildPage({
  modules: ['engine', 'massive', 'alphavantage', 'demo', 'providers', 'status', 'scan', 'client'],
  init, document: true,
  head: '<meta name="theme-color" content="#0a0d12">',
});

const dir = path.join(ROOT, 'android', 'app', 'src', 'main', 'assets');
await mkdir(dir, { recursive: true });
await writeFile(path.join(dir, 'index.html'), out);
console.log(`كُتب android/app/src/main/assets/index.html (${(out.length / 1024).toFixed(1)} KB)`);
