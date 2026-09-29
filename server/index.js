// خادم راصد: يخدم تطبيق الجوال (PWA) من public/ ويوفّر /api/scan.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scoreTicker, buildTrade, rankResults, applyYaqeen } from './engine.js';
import { fetchDailyBars, ProviderError } from './alphavantage.js';
import { demoBars } from './demo.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(ROOT, '..', 'public');
const envFile = path.join(ROOT, '..', '.env');
if (existsSync(envFile) && typeof process.loadEnvFile === 'function') process.loadEnvFile(envFile);

const API_KEY = process.env.ALPHA_VANTAGE_KEY || '';
const PORT = Number(process.env.PORT) || 3000;
const MAX_TICKERS = 25;
const CHART_BARS = 60;
const FATAL = new Set(['rate_limited']);

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml', '.png': 'image/png',
};

const num = (v, def, min, max) => { const x = Number(v); return Number.isFinite(x) ? Math.min(max, Math.max(min, x)) : def; };
const sleep = ms => new Promise(r => setTimeout(r, ms));

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

  const tickers = [...new Set((Array.isArray(body.tickers) ? body.tickers : [])
    .map(s => String(s).trim().toUpperCase()).filter(s => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(s)))];
  if (tickers.length === 0) return sendJson(res, 400, { error: 'القائمة فاضية.' });
  if (tickers.length > MAX_TICKERS) return sendJson(res, 400, { error: `الحد الأقصى ${MAX_TICKERS} سهم لكل مسح.` });

  const p = { volAvgDays: num(body.volAvgDays, 20, 5, 60), volMult: num(body.volMult, 1.5, 0.5, 10) };
  const tradeP = { slAtr: num(body.slAtr, 1.5, 0.2, 10), rr: num(body.rr, 1.5, 0.2, 10) };
  const yaqeen = body.yaqeen && typeof body.yaqeen === 'object' ? body.yaqeen : {};
  const { kept, excluded } = applyYaqeen(tickers, yaqeen, { excludeHaram: body.excludeHaram !== false, excludeMashbooh: !!body.excludeMashbooh });
  const demo = !API_KEY;

  const perTicker = {};
  let fatal = null;
  for (let idx = 0; idx < kept.length; idx++) {
    const sym = kept[idx];
    try {
      const { bars, cached } = demo ? { bars: demoBars(sym), cached: false } : await fetchDailyBars(sym, API_KEY);
      perTicker[sym] = { ok: true, bars, cached, yaqeen: yaqeen[sym] || 'غير معروف', ...scoreTicker(bars, p) };
      if (!demo && !cached && idx < kept.length - 1) await sleep(300);
    } catch (err) {
      perTicker[sym] = { ok: false, error: err.message || 'خطأ غير معروف' };
      if (err instanceof ProviderError && FATAL.has(err.code)) { fatal = err.message; break; }
    }
  }

  const { top, passed, gateRejected, failed } = rankResults(perTicker);
  const slim = ([sym, d]) => d.ok
    ? { sym, ok: true, passesGate: d.passesGate, liqRatio: d.liqRatio, rsi: d.rsiVal, direction: d.direction, score: d.score, lastClose: d.lastClose, yaqeen: d.yaqeen, cached: d.cached }
    : { sym, ok: false, error: d.error };

  sendJson(res, 200, {
    demo, fatal, scannedAt: new Date().toISOString(), params: { ...p, ...tradeP },
    counts: { requested: tickers.length, yaqeenExcluded: Object.keys(excluded).length, passed: passed.length, gateRejected: gateRejected.length, failed: failed.length },
    yaqeenExcluded: excluded,
    picks: top.map(([sym, d], rank) => {
      const n = d.bars.c.length, from = Math.max(0, n - CHART_BARS);
      const cut = k => d.bars[k].slice(from);
      return {
        rank: rank + 1, sym, yaqeen: d.yaqeen, lastDate: d.lastDate, direction: d.direction,
        liqRatio: d.liqRatio, rsi: d.rsiVal, momentum: d.momentumStrength, atr: d.atr,
        trade: buildTrade(d, tradeP),
        // مصدر الترشيح — شرط أساسي: كل مصدر ظاهر بوضوح، والمعطّل يُعلن أنه معطّل.
        sources: {
          liquidity: { active: true, value: d.liqRatio },
          news: { active: false, note: 'غير مفعّل بعد' },
          technical: { active: true, value: d.rsiVal },
        },
        bars: { t: cut('t'), o: cut('o'), h: cut('h'), l: cut('l'), c: cut('c') },
      };
    }),
    all: Object.entries(perTicker).map(slim).sort((a, b) => (b.score || 0) - (a.score || 0)),
  });
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
