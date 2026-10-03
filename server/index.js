// خادم راصد: يخدم تطبيق الجوال (PWA) من public/ ويوفّر /api/scan.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runScan } from './scan.js';
import { createMassiveStore } from './massive.js';
import { diskStorage } from './disk-storage.js';
import { buildProviders, trendFor, spikesFor } from './providers.js';
import { statusLights } from './status.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(ROOT, '..', 'public');
const envFile = path.join(ROOT, '..', '.env');
if (!process.env.RASED_NO_ENV_FILE && existsSync(envFile) && typeof process.loadEnvFile === 'function') process.loadEnvFile(envFile);

// المفتاح الملصوق أحيانًا يجي معه مسافات أو علامات تنصيص — ننظفه
const cleanKey = v => String(v || '').trim().replace(/^["']+|["']+$/g, '').trim();
const API_KEY = cleanKey(process.env.ALPHA_VANTAGE_KEY);
const MASSIVE_KEY = cleanKey(process.env.MASSIVE_API_KEY) || cleanKey(process.env.POLYGON_API_KEY);
// متغيرات بأسماء قريبة من أسماء المفاتيح (خطأ إملائي، حروف صغيرة، مسافة) — نعرض الاسم فقط، أبدًا القيمة
const KNOWN_VARS = new Set(['MASSIVE_API_KEY', 'POLYGON_API_KEY', 'ALPHA_VANTAGE_KEY', 'MASSIVE_API_BASE', 'MASSIVE_GAP_MS']);
const LOOKALIKES = Object.keys(process.env).filter(k => /massive|polygon|alpha|vantage/i.test(k) && !KNOWN_VARS.has(k)).map(k => JSON.stringify(k));
const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(ROOT, '..', 'data'));
const PORT = Number(process.env.PORT) || 3000;
const SYNC_EVERY_MS = 60 * 60 * 1000;
// نتائج المختبر (lab/results) — تُقرأ من القرص عند كل طلب، فتظهر فور ما يكتبها المختبر
const LAB_DIR = path.resolve(process.env.RASED_LAB_DIR || path.join(ROOT, '..', 'lab', 'results'));

const store = MASSIVE_KEY ? createMassiveStore({ apiKey: MASSIVE_KEY, storage: diskStorage(DATA_DIR) }) : null;
const DEMO = !MASSIVE_KEY && !API_KEY;
// شموع الاتجاهات من Yahoo بدون مفتاح (RASED_YAHOO=0 يوقفها — الاختبارات بدون شبكة)
const YAHOO = process.env.RASED_YAHOO !== '0';
const providers = buildProviders({ massiveKey: MASSIVE_KEY, alphaKey: API_KEY, store, yahoo: YAHOO });

function health() {
  const market = DEMO ? { ready: true, demo: true } : store ? { ...store.state } : null;
  return {
    ok: true, demo: DEMO, news: !!API_KEY || DEMO, market, yahoo: YAHOO && !MASSIVE_KEY,
    status: statusLights({ massiveKey: !!MASSIVE_KEY, alphaKey: !!API_KEY, persistentData: !!process.env.DATA_DIR, lookalikes: LOOKALIKES, market: store ? market : null }),
  };
}

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml', '.png': 'image/png',
};

function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

async function readBody(req, max = 64 * 1024) {
  let size = 0; const chunks = [];
  for await (const c of req) { size += c.length; if (size > max) throw new Error('الطلب كبير جدًا.'); chunks.push(c); }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

async function handleScan(req, res) {
  let body;
  try { body = await readBody(req); } catch { return sendJson(res, 400, { error: 'طلب غير صالح.' }); }
  const { status, body: out } = await runScan(body, providers);
  sendJson(res, status, out);
}

async function handleTrend(req, res) {
  const sym = new URL(req.url, 'http://x').searchParams.get('sym');
  try {
    sendJson(res, 200, await trendFor(providers, sym));
  } catch (e) {
    const status = e.code === 'bad_symbol' || e.code === 'no_massive' ? 400 : e.code === 'rate_limited' ? 429 : 502;
    sendJson(res, status, { error: e.message, code: e.code || 'error' });
  }
}

// انفجار السيولة: GET بفلتر يقين في الرابط، أو POST { yaqeen, excludeHaram, excludeMashbooh, nightly }
// (nightly = نسخة الواجهة من spikes-today.json — نأخذ الأحدث بينها وبين ملف المسح الليلي على القرص)
async function handleSpikes(req, res) {
  let body = {};
  if (req.method === 'POST') {
    try { body = await readBody(req, 1024 * 1024); } catch { return sendJson(res, 400, { error: 'طلب غير صالح.' }); }
  } else {
    const q = new URL(req.url, 'http://x').searchParams;
    try { body.yaqeen = JSON.parse(q.get('yaqeen') || '{}'); } catch { body.yaqeen = {}; }
    body.excludeHaram = q.get('excludeHaram') !== '0';
    body.excludeMashbooh = q.get('excludeMashbooh') === '1';
  }
  let disk = null;
  try { disk = JSON.parse(await readFile(path.join(LAB_DIR, 'spikes-today.json'), 'utf8')); } catch { /* المسح الليلي لم يكتب بعد */ }
  sendJson(res, 200, spikesFor(providers, body, [disk, body.nightly]));
}

// top5 كما هو؛ backtest: نرسل الأسابيع والحساب فقط (الصفقات كثيرة والواجهة ما تحتاجها)
async function handleLab(res, which) {
  let data;
  try { data = JSON.parse(await readFile(path.join(LAB_DIR, which + '.json'), 'utf8')); }
  catch { return sendJson(res, 404, { error: 'ما فيه نتائج اختبار بعد — المختبر يشتغل كل سبت.', code: 'no_results' }); }
  if (which === 'spike') data = slimSpike(data);
  if (which === 'backtest') data = { generatedAt: data.generatedAt, source: data.source, dataFrom: data.dataFrom, dataTo: data.dataTo, weeks: data.weeks || [], account: data.account || null };
  sendJson(res, 200, data);
}

// spike.json كبير (كل الصفقات) — الواجهة تحتاج الملخص فقط
export const slimSpike = d => d && typeof d === 'object' ? { generatedAt: d.generatedAt, source: d.source, dataFrom: d.dataFrom, dataTo: d.dataTo, defaultKey: d.defaultKey, default: d.default || null, account: d.account || null, walkForward: d.walkForward || null } : null;

async function serveStatic(req, res) {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const file = path.normalize(path.join(PUBLIC, rel));
  if (!file.startsWith(PUBLIC + path.sep)) { res.writeHead(403); return res.end(); }
  try {
    const data = await readFile(file);
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': rel === 'sw.js' ? 'no-cache' : 'public, max-age=300' });
    res.end(data);
  } catch { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); res.end('غير موجود'); }
}

export const server = http.createServer(async (req, res) => {
  try {
    if (req.url.startsWith('/api/')) {
      if (req.url === '/api/health' && req.method === 'GET') return sendJson(res, 200, health());
      if (req.url === '/api/scan' && req.method === 'POST') return await handleScan(req, res);
      const route = new URL(req.url, 'http://x').pathname;
      if (route === '/api/trend' && req.method === 'GET') return await handleTrend(req, res);
      if (route === '/api/lab/top5' && req.method === 'GET') return await handleLab(res, 'top5');
      if (route === '/api/lab/backtest' && req.method === 'GET') return await handleLab(res, 'backtest');
      if (route === '/api/lab/spike' && req.method === 'GET') return await handleLab(res, 'spike');
      if (route === '/api/lab/spikes-today' && req.method === 'GET') return await handleLab(res, 'spikes-today');
      if (route === '/api/spikes' && (req.method === 'GET' || req.method === 'POST')) return await handleSpikes(req, res);
      return sendJson(res, 404, { error: 'مسار غير معروف.' });
    }
    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end(); }
    await serveStatic(req, res);
  } catch (e) {
    console.error(e);
    if (!res.headersSent) sendJson(res, 500, { error: 'خطأ في الخادم.' });
  }
});

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const src = DEMO ? 'وضع تجريبي — لا يوجد مفتاح' : [MASSIVE_KEY && 'Massive: السوق كامل', API_KEY && 'Alpha Vantage: أخبار وأرباح'].filter(Boolean).join(' + ');
  server.listen(PORT, () => console.log(`راصد يعمل على http://localhost:${PORT} (${src})`));
  if (store) {
    // تحميل المخزن ثم مزامنة الأيام الناقصة، وبعدها كل ساعة (يلتقط يوم التداول الجديد بعد نشره)
    store.loadFromDisk().then(() => store.sync());
    setInterval(() => store.sync(), SYNC_EVERY_MS).unref();
  }
}
