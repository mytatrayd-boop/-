// خادم راصد: يخدم تطبيق الجوال (PWA) من public/ ويوفّر /api/scan.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scoreTicker, buildTrade, rankResults, applyYaqeen, newsEffect, sentimentLabel, upcomingEarnings, NEWS_DEFAULTS } from './engine.js';
import { fetchDailyBars, fetchNews, fetchEarningsCalendar, ProviderError } from './alphavantage.js';
import { demoBars, demoNews, demoEarnings } from './demo.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(ROOT, '..', 'public');
const envFile = path.join(ROOT, '..', '.env');
if (existsSync(envFile) && typeof process.loadEnvFile === 'function') process.loadEnvFile(envFile);

const API_KEY = process.env.ALPHA_VANTAGE_KEY || '';
const PORT = Number(process.env.PORT) || 3000;
const MAX_TICKERS = 25;
const CHART_BARS = 60;
const EARNINGS_HORIZON_DAYS = 7; // أفق الصفقة أسبوع
const FATAL = new Set(['rate_limited']);

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml', '.png': 'image/png',
};

const num = (v, def, min, max) => { const x = Number(v); return Number.isFinite(x) ? Math.min(max, Math.max(min, x)) : def; };

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
  const newsP = {
    newsDays: num(body.newsDays, NEWS_DEFAULTS.newsDays, 1, 7), minRelevance: NEWS_DEFAULTS.minRelevance,
    newsBoost: num(body.newsBoost, NEWS_DEFAULTS.newsBoost, 0, 1), newsGate: num(body.newsGate, NEWS_DEFAULTS.newsGate, 0.15, 1),
    newsMax: Math.round(num(body.newsMax, 5, 0, MAX_TICKERS)),
  };
  const demo = !API_KEY;

  // 1) الأسعار + بوابة السيولة + RSI
  const perTicker = {};
  let fatal = null;
  for (const sym of kept) {
    try {
      const { bars, cached } = demo ? { bars: demoBars(sym), cached: false } : await fetchDailyBars(sym, API_KEY);
      const s = scoreTicker(bars, p);
      perTicker[sym] = { ok: true, bars, cached, yaqeen: yaqeen[sym] || 'غير معروف', ...s, baseScore: s.score, news: { status: 'skipped' } };
    } catch (err) {
      perTicker[sym] = { ok: false, error: err.message || 'خطأ غير معروف' };
      if (err instanceof ProviderError && FATAL.has(err.code)) { fatal = err.message; break; }
    }
  }

  // 2) الأخبار — فقط لمن اجتاز بوابة السيولة (غيرهم نتيجته صفر أصلاً)، وبحد أقصى newsMax طلب لحماية الحصة.
  const gatePassed = Object.entries(perTicker).filter(([, d]) => d.ok && d.passesGate).sort((a, b) => b[1].baseScore - a[1].baseScore);
  let newsFatal = fatal;
  gatePassed.forEach(([sym, d], i) => {
    if (i >= newsP.newsMax) d.news = { status: 'capped' };
  });
  for (const [sym, d] of gatePassed.slice(0, newsP.newsMax)) {
    if (newsFatal) { d.news = { status: 'error', error: newsFatal }; continue; }
    try {
      const { news } = demo ? { news: demoNews(sym) } : await fetchNews(sym, API_KEY, newsP);
      const eff = newsEffect(news, d.direction, newsP);
      d.news = { status: 'ok', count: news.count, sentiment: news.sentiment, label: news.count ? sentimentLabel(news.sentiment) : 'لا يوجد خبر', articles: news.articles, ...eff };
      d.newsGated = eff.gated;
      d.score = eff.gated ? 0 : d.baseScore * eff.multiplier;
    } catch (err) {
      // فشل الأخبار لا يوقف المسح: السهم يبقى بنتيجته الأساسية ويُعلن أن الخبر لم يُفحص.
      d.news = { status: 'error', error: err.message || 'خطأ غير معروف' };
      if (err instanceof ProviderError && FATAL.has(err.code)) newsFatal = err.message;
    }
  }

  // 3) تقويم الأرباح — طلب واحد للسوق كله، تنبيه مخاطرة فقط لا يغيّر النتيجة.
  let earningsError = null, calendar = null;
  if (gatePassed.length) {
    if (newsFatal && !demo) earningsError = newsFatal;
    else {
      try { calendar = demo ? demoEarnings(kept) : (await fetchEarningsCalendar(API_KEY)).calendar; }
      catch (err) { earningsError = err.message || 'خطأ غير معروف'; }
    }
  }
  const earningsFor = d => calendar ? upcomingEarnings(calendar, d.sym, d.lastDate, EARNINGS_HORIZON_DAYS) : undefined;

  const { top, passed, gateRejected, newsRejected, failed } = rankResults(perTicker);
  const newsSummary = n => n.status === 'ok'
    ? { status: 'ok', count: n.count, sentiment: n.sentiment, label: n.label, aligned: n.aligned, multiplier: n.multiplier, gated: n.gated }
    : { status: n.status, error: n.error };
  const slim = ([sym, d]) => d.ok
    ? { sym, ok: true, passesGate: d.passesGate, newsGated: !!d.newsGated, liqRatio: d.liqRatio, rsi: d.rsiVal, direction: d.direction, baseScore: d.baseScore, score: d.score, lastClose: d.lastClose, yaqeen: d.yaqeen, cached: d.cached, news: newsSummary(d.news) }
    : { sym, ok: false, error: d.error };

  sendJson(res, 200, {
    demo, fatal: newsFatal, scannedAt: new Date().toISOString(), params: { ...p, ...tradeP, ...newsP, earningsHorizonDays: EARNINGS_HORIZON_DAYS },
    counts: { requested: tickers.length, yaqeenExcluded: Object.keys(excluded).length, passed: passed.length, gateRejected: gateRejected.length, newsRejected: newsRejected.length, failed: failed.length },
    yaqeenExcluded: excluded,
    earnings: { ok: !!calendar, error: earningsError },
    picks: top.map(([sym, d], rank) => {
      const n = d.bars.c.length, from = Math.max(0, n - CHART_BARS);
      const cut = k => d.bars[k].slice(from);
      return {
        rank: rank + 1, sym, yaqeen: d.yaqeen, lastDate: d.lastDate, direction: d.direction,
        liqRatio: d.liqRatio, rsi: d.rsiVal, momentum: d.momentumStrength, atr: d.atr, baseScore: d.baseScore, score: d.score,
        trade: buildTrade(d, tradeP),
        // مصدر الترشيح — شرط أساسي: كل مصدر ظاهر بوضوح، وما لم يُفحص يُعلن أنه لم يُفحص.
        sources: {
          liquidity: { active: true, value: d.liqRatio },
          technical: { active: true, value: d.rsiVal },
          news: { ...newsSummary(d.news), articles: d.news.articles || [] },
          earnings: calendar ? earningsFor({ sym, lastDate: d.lastDate }) : { error: earningsError || 'لم يُفحص' },
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
