// خادم راصد: يخدم تطبيق الجوال (PWA) من public/ ويوفّر /api/scan.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runScan } from './scan.js';
import { fetchDailyBars, fetchNews, fetchEarningsCalendar } from './alphavantage.js';
import { demoProviders } from './demo.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(ROOT, '..', 'public');
const envFile = path.join(ROOT, '..', '.env');
if (existsSync(envFile) && typeof process.loadEnvFile === 'function') process.loadEnvFile(envFile);

const API_KEY = process.env.ALPHA_VANTAGE_KEY || '';
const PORT = Number(process.env.PORT) || 3000;
// بدون مفتاح: وضع تجريبي ببيانات مصطنعة موسومة بوضوح في الواجهة.
const providers = API_KEY ? {
  demo: false,
  bars: sym => fetchDailyBars(sym, API_KEY),
  news: (sym, newsP) => fetchNews(sym, API_KEY, newsP),
  earnings: () => fetchEarningsCalendar(API_KEY),
} : demoProviders;

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
      if (req.url === '/api/health' && req.method === 'GET') return sendJson(res, 200, { ok: true, demo: !API_KEY });
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
  server.listen(PORT, () => console.log(`راصد يعمل على http://localhost:${PORT} ${API_KEY ? '(Alpha Vantage)' : '(وضع تجريبي — لا يوجد ALPHA_VANTAGE_KEY)'}`));
}
