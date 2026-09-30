// خادم راصد: يخدم تطبيق الجوال (PWA) من public/ ويوفّر /api/scan.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runScan } from './scan.js';
import { fetchDailyBars, fetchNews, fetchEarningsCalendar } from './alphavantage.js';
import { demoProviders } from './demo.js';
import { createMassiveStore, HISTORY_DAYS } from './massive.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(ROOT, '..', 'public');
const envFile = path.join(ROOT, '..', '.env');
if (!process.env.RASED_NO_ENV_FILE && existsSync(envFile) && typeof process.loadEnvFile === 'function') process.loadEnvFile(envFile);

const API_KEY = process.env.ALPHA_VANTAGE_KEY || '';
const MASSIVE_KEY = process.env.MASSIVE_API_KEY || process.env.POLYGON_API_KEY || '';
const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(ROOT, '..', 'data'));
const PORT = Number(process.env.PORT) || 3000;
const SYNC_EVERY_MS = 60 * 60 * 1000;

// Massive: أسعار السوق كامل من مخزن محلي (بدون طلبات وقت المسح).
// Alpha Vantage: الأخبار وتقويم الأرباح (وأسعار «قائمتي» إذا ما فيه Massive).
// بدون أي مفتاح: وضع تجريبي ببيانات مصطنعة موسومة بوضوح في الواجهة.
const store = MASSIVE_KEY ? createMassiveStore({ apiKey: MASSIVE_KEY, dataDir: DATA_DIR }) : null;
const DEMO = !MASSIVE_KEY && !API_KEY;

function buildProviders() {
  if (DEMO) return demoProviders;
  const pv = { demo: false };
  if (store) {
    pv.bars = async sym => ({ bars: store.bars(sym), cached: true });
    pv.profile = store.profile;
    pv.universe = async opts => {
      if (!store.state.ready) {
        const pr = store.state.progress;
        throw new Error(`بيانات السوق تتجهز (${store.state.days} يوم من ${HISTORY_DAYS}${pr ? `، يجلب ${pr.date}` : ''}) — حاول بعد دقائق.`);
      }
      return { tickers: store.universe(opts), lastDay: store.state.lastDay };
    };
  } else {
    pv.bars = sym => fetchDailyBars(sym, API_KEY);
  }
  if (API_KEY) {
    pv.news = (sym, newsP) => fetchNews(sym, API_KEY, newsP);
    pv.earnings = () => fetchEarningsCalendar(API_KEY);
  }
  return pv;
}
const providers = buildProviders();

function health() {
  return {
    ok: true, demo: DEMO, news: !!API_KEY || DEMO,
    market: DEMO ? { ready: true, demo: true } : store ? { ...store.state } : null,
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

async function readBody(req) {
  let size = 0; const chunks = [];
  for await (const c of req) { size += c.length; if (size > 64 * 1024) throw new Error('الطلب كبير جدًا.'); chunks.push(c); }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

async function handleScan(req, res) {
  let body;
  try { body = await readBody(req); } catch { return sendJson(res, 400, { error: 'طلب غير صالح.' }); }
  const { status, body: out } = await runScan(body, providers);
  sendJson(res, status, out);
}

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
