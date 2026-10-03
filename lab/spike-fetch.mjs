// انفجار السيولة — تنزيل شموع يومية للسوق الأمريكي كامل (أسهم عادية) إلى lab/data/daily/SYM.json
// المصدر الافتراضي بدون مفتاح: قائمة الرموز من NASDAQ Trader + شموع Yahoo اليومية (سنتان، ثم تحديث تدريجي 5 أيام).
// مسار اختياري: لو وُجد MASSIVE_API_KEY → Massive «grouped daily» (طلب لكل يوم، 12.5 ث بينها) ثم تُقسّم لملفات الأسهم.
// الاستخدام: node lab/spike-fetch.mjs [SYM …] [--force] [--limit=N]
// سهم يفشل يُسجَّل ويُتخطّى. يخرج دائمًا بـ 0 (الخطوة التالية تتأكد من وجود البيانات). التحليل في دوال صافية مُختبرة.
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseYahooDaily, yahooName, yahooChartUrl, YAHOO_HOSTS, YAHOO_UA } from '../server/yahoo.js';
import { parseGroupedDaily, parseTickersPage, weekdaysBack, buildBars } from '../server/massive.js';
import { mergeBars, adjustmentChanged } from './fetch.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const DAILY_DIR = path.join(HERE, 'data', 'daily');
const GROUPED_DIR = path.join(HERE, 'data', 'grouped');
const ENV = process.env;
const DAY = 86400000;
export const FETCH_DEFAULTS = {
  concurrency: Number(ENV.YAHOO_CONCURRENCY) || 4,  // طلبات متزامنة
  gapMs: Number(ENV.YAHOO_GAP_MS) || 160,          // بين بدايات الطلبات ≈ 6 طلبات/ث إجمالًا
  retries: 4, backoffMs: 2000,
  incrementalMaxAgeDays: 7,                         // كاش أحدث من 7 أيام → range=5d، وإلا range=2y
  skipIfFresherH: 6,                                // أُعيد التشغيل بنفس الليلة → بدون تنزيل
  keepDays: 800,                                    // نحتفظ بآخر ~سنتين و شهرين تقويميًا
};
const MASSIVE_BASE = (ENV.MASSIVE_API_BASE || 'https://api.polygon.io').replace(/\/+$/, '');
const MASSIVE_GAP_MS = Number(ENV.MASSIVE_GAP_MS) || 12500;
export const NASDAQ_URLS = {
  nasdaq: 'https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt',
  other: 'https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt',
};
const OTHER_EXCH = { A: 'NYSE American', N: 'NYSE', P: 'NYSE Arca', Z: 'Cboe BZX', V: 'IEX' };
const NASDAQ_TIER = { Q: 'NASDAQ', G: 'NASDAQ', S: 'NASDAQ' };

const sleep = ms => new Promise(r => setTimeout(r, ms));
const err = (code, message) => Object.assign(new Error(message), { code });

/* ---------- قائمة الرموز (NASDAQ Trader) ---------- */

// اسم يدل على غير سهم عادي (وارنت، وحدة، حق، ممتاز، سندات، صندوق، إيصالات إيداع…)
const NOT_COMMON = /\b(warrants?|units?|rights?|preferred|preference|depositary|notes? due|debentures?|subordinated|fund|etn|exchange[- ]traded|beneficial interest|perpetual)\b|%/i;

// سهم عادي؟ (الرمز + اسم الورقة). يستبعد الرموز بـ $ . ^ = واللاحقة W/WS/U/R لما الاسم يقول وارنت/وحدة/حق.
export function isCommonStock(sym, name) {
  if (!/^[A-Z][A-Z0-9]{0,6}$/.test(sym)) return false;           // يشمل استبعاد $ . ^ = - والمسافات
  const n = String(name || '');
  if (/(W|WS|U|R)$/.test(sym) && /warrant|unit|right/i.test(n)) return false;
  if (NOT_COMMON.test(n)) return false;
  return true;
}

// ملف مفصول بـ | مع سطر عناوين وسطر «File Creation Time» بالآخر → [{col: value}]
export function parsePipeFile(text) {
  const lines = String(text || '').split(/\r?\n/).filter(l => l.trim());
  if (!lines.length) return [];
  const head = lines[0].split('|').map(s => s.trim());
  return lines.slice(1).filter(l => !/^File Creation Time/i.test(l)).map(l => {
    const cells = l.split('|'); const row = {};
    head.forEach((h, i) => { row[h] = (cells[i] || '').trim(); });
    return row;
  });
}

// nasdaqlisted.txt: Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares
export function parseNasdaqListed(text) {
  const out = [];
  for (const r of parsePipeFile(text)) {
    const sym = r['Symbol'], name = r['Security Name'];
    if (!sym || r['ETF'] === 'Y' || r['Test Issue'] === 'Y' || r['NextShares'] === 'Y') continue;
    if (!isCommonStock(sym, name)) continue;
    out.push({ sym, name, exchange: NASDAQ_TIER[r['Market Category']] || 'NASDAQ' });
  }
  return out;
}

// otherlisted.txt: ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol
export function parseOtherListed(text) {
  const out = [];
  for (const r of parsePipeFile(text)) {
    const sym = r['ACT Symbol'] || r['NASDAQ Symbol'], name = r['Security Name'];
    if (!sym || r['ETF'] === 'Y' || r['Test Issue'] === 'Y') continue;
    if (!isCommonStock(sym, name)) continue;
    out.push({ sym, name, exchange: OTHER_EXCH[r['Exchange']] || r['Exchange'] || null });
  }
  return out;
}

// الملفين → { symbols: [...], info: {sym: {name, exchange}} } بدون تكرار، مرتبة
export function buildUniverse(nasdaqText, otherText) {
  const info = {};
  for (const x of [...parseNasdaqListed(nasdaqText), ...parseOtherListed(otherText)]) if (!info[x.sym]) info[x.sym] = { name: cleanName(x.name), exchange: x.exchange };
  return { symbols: Object.keys(info).sort(), info };
}
// «Apple Inc. - Common Stock» → «Apple Inc.»
export const cleanName = n => String(n || '').replace(/\s+-\s+(Class [A-Z] )?(Common Stock|Ordinary Shares|Common Shares).*$/i, '').trim() || null;

/* ---------- خطة التنزيل لكل سهم ---------- */

// 'skip' (نُزّل قبل ساعات) | 'incremental' (range=5d) | 'full' (range=2y)
export function planFetch(entry, cached, nowMs, opt = FETCH_DEFAULTS) {
  if (!cached || !cached.t || !cached.t.length || !entry || !Number.isFinite(entry.at)) return 'full';
  const age = nowMs - entry.at;
  if (age < opt.skipIfFresherH * 3600e3) return 'skip';
  return age < opt.incrementalMaxAgeDays * DAY ? 'incremental' : 'full';
}

export function trimBars(bars, fromMs) {
  const i = bars.t.findIndex(t => t >= fromMs);
  if (i <= 0) return i === 0 ? bars : { t: [], o: [], h: [], l: [], c: [], v: [] };
  const out = {};
  for (const k of ['t', 'o', 'h', 'l', 'c', 'v']) out[k] = bars[k].slice(i);
  return out;
}

/* ---------- الشبكة (fetch قابل للحقن للاختبار) ---------- */

// منظّم: كل طلب يحجز موعده فورًا، فالطلبات المتزامنة تتباعد gap ms
export function makePacer(gapMs, now = () => Date.now(), wait = sleep) {
  let next = 0;
  return async () => { const t = now(), at = Math.max(t, next); next = at + gapMs; if (at > t) await wait(at - t); };
}

// رد Yahoo مع إعادة المحاولة: 429/5xx/انقطاع → انتظار متزايد، ومحاولة query2 بالتناوب
export async function getYahooChart(sym, query, { fetchImpl = fetch, pace = async () => {}, retries = FETCH_DEFAULTS.retries, backoffMs = FETCH_DEFAULTS.backoffMs, wait = sleep } = {}) {
  let last = null;
  for (let a = 0; a <= retries; a++) {
    await pace();
    const host = YAHOO_HOSTS[a % YAHOO_HOSTS.length];
    let res = null, body = null;
    try { res = await fetchImpl(yahooChartUrl(sym, query, host), { headers: { 'User-Agent': YAHOO_UA, Accept: 'application/json' }, signal: AbortSignal.timeout(30000) }); }
    catch (e) { last = err('unavailable', `${sym}: ${e.message}`); }
    if (res) {
      try { body = await res.json(); } catch { /* تحت */ }
      if (res.ok && body) return body;
      if (body && body.chart && body.chart.error && res.status < 500 && res.status !== 429) return body; // رمز غير موجود: المحلل يرمي no_data
      last = err(res.status === 429 ? 'rate_limited' : 'http', `${sym}: HTTP ${res.status}`);
      if (res.status < 500 && res.status !== 429) throw last;
    }
    if (a < retries) await wait(backoffMs * 2 ** a);
  }
  throw last;
}

// سهم واحد: تنزيل كامل أو تدريجي + دمج + تحقق من تغيّر التعديل (تقسيم) → { bars, name, mode }
export async function updateSymbol(sym, cached, mode, net, nowMs = Date.now(), opt = FETCH_DEFAULTS) {
  const get = async range => {
    const body = await getYahooChart(sym, `interval=1d&range=${range}&includePrePost=false`, net);
    return { bars: parseYahooDaily(body, nowMs), name: yahooName(body) };
  };
  if (mode === 'incremental') {
    const inc = await get('5d');
    if (!adjustmentChanged(cached, inc.bars)) return { bars: trimBars(mergeBars(cached, inc.bars), nowMs - opt.keepDays * DAY), name: inc.name, mode };
    mode = 'full'; // تقسيم/تعديل → إعادة كاملة
  }
  const full = await get('2y');
  return { bars: trimBars(full.bars, nowMs - opt.keepDays * DAY), name: full.name, mode };
}

// عمّال متوازيين على قائمة
export async function runPool(items, worker, concurrency) {
  let i = 0;
  const run = async () => { while (i < items.length) { const k = i++; await worker(items[k], k); } };
  await Promise.all(Array.from({ length: Math.max(1, Math.min(concurrency, items.length)) }, run));
}

/* ---------- التشغيل ---------- */

async function readJson(file) { try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; } }
export async function getText(url) {
  for (let a = 0; a < 4; a++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': YAHOO_UA }, signal: AbortSignal.timeout(60000) });
      if (res.ok) return await res.text();
      console.log(`  ${url}: HTTP ${res.status}`);
    } catch (e) { console.log(`  ${url}: ${e.message}`); }
    await sleep(3000 * (a + 1));
  }
  throw err('unavailable', 'تعذّر تنزيل ' + url);
}

async function loadUniverse() {
  const file = path.join(DAILY_DIR, '_universe.json');
  try {
    const [a, b] = await Promise.all([getText(NASDAQ_URLS.nasdaq), getText(NASDAQ_URLS.other)]);
    const u = buildUniverse(a, b);
    if (u.symbols.length < 2000) throw err('bad_shape', `قائمة NASDAQ Trader ناقصة (${u.symbols.length})`);
    await writeFile(file, JSON.stringify({ at: new Date().toISOString(), source: 'nasdaqtrader', ...u }));
    console.log(`قائمة الرموز: ${u.symbols.length} سهم عادي (NASDAQ Trader)`);
    return u;
  } catch (e) {
    const old = await readJson(file);
    if (old && Array.isArray(old.symbols)) { console.log(`تعذّر تحديث قائمة الرموز (${e.message}) — نستخدم المحفوظة (${old.symbols.length})`); return old; }
    throw e;
  }
}

async function mainYahoo(args) {
  const force = args.includes('--force');
  const limit = Number((args.find(a => a.startsWith('--limit=')) || '').slice(8)) || 0;
  const only = args.filter(a => !a.startsWith('--')).map(s => s.toUpperCase());
  const universe = await loadUniverse();
  let symbols = only.length ? only : universe.symbols;
  if (limit) symbols = symbols.slice(0, limit);
  const metaFile = path.join(DAILY_DIR, '_meta.json');
  const prev = (await readJson(metaFile)) || {};
  const entries = prev.source === 'yahoo' && prev.symbols ? prev.symbols : {};
  const now = Date.now(), pace = makePacer(FETCH_DEFAULTS.gapMs);
  const stats = { full: 0, incremental: 0, skip: 0, failed: 0 };
  const failures = {};
  let done = 0;
  console.log(`Yahoo: ${symbols.length} سهم، ${FETCH_DEFAULTS.concurrency} متزامن`);
  await runPool(symbols, async sym => {
    const file = path.join(DAILY_DIR, `${sym}.json`);
    const cached = await readJson(file);
    const mode = force ? 'full' : planFetch(entries[sym], cached, now);
    try {
      if (mode === 'skip') { stats.skip++; return; }
      const r = await updateSymbol(sym, cached, mode, { pace }, now);
      if (!r.bars.t.length) throw err('empty', 'بدون شموع');
      await writeFile(file, JSON.stringify(r.bars));
      entries[sym] = { at: now, bars: r.bars.t.length, last: new Date(r.bars.t[r.bars.t.length - 1]).toISOString().slice(0, 10), name: r.name || (universe.info[sym] || {}).name || null };
      stats[r.mode]++;
    } catch (e) {
      stats.failed++; failures[sym] = e.message.slice(0, 120);
    } finally {
      if (++done % 250 === 0) console.log(`  ${done}/${symbols.length} — كامل ${stats.full}، تدريجي ${stats.incremental}، حديث ${stats.skip}، فشل ${stats.failed}`);
    }
  }, FETCH_DEFAULTS.concurrency);
  const lasts = Object.values(entries).map(e => e.last).filter(Boolean).sort();
  const meta = { source: 'yahoo', fetchedAt: new Date().toISOString(), universe: universe.symbols.length, symbols: entries,
    from: null, to: lasts[lasts.length - 1] || null, stats, failures };
  await writeFile(metaFile, JSON.stringify(meta));
  console.log(`تم: كامل ${stats.full}، تدريجي ${stats.incremental}، حديث ${stats.skip}، فشل ${stats.failed}. آخر يوم ${meta.to}`);
  const sample = Object.entries(failures).slice(0, 10);
  if (sample.length) console.log('أمثلة فشل: ' + sample.map(([s, m]) => `${s} (${m})`).join('، '));
}

// Massive (اختياري): أيام grouped daily مخزّنة في lab/data/grouped/DATE.json ثم تُقسَّم لملفات الأسهم
export function groupedToSymbols(days, commonStocks = null) {
  const out = {};
  for (const [sym, b] of buildBars(days)) {
    if (commonStocks && !commonStocks.has(sym)) continue;
    out[sym] = { t: b.t, o: b.o, h: b.h, l: b.l, c: b.c, v: b.v };
  }
  return out;
}

async function mainMassive(key) {
  await mkdir(GROUPED_DIR, { recursive: true });
  const pace = makePacer(MASSIVE_GAP_MS);
  const call = async url => {
    for (let a = 0; ; a++) {
      await pace();
      const u = new URL(url); u.searchParams.set('apiKey', key);
      const res = await fetch(u, { signal: AbortSignal.timeout(60000) });
      const body = await res.json().catch(() => null);
      if ((res.status === 429 || (body && /exceeded|maximum requests/i.test(body.error || ''))) && a < 3) { await sleep(60000); continue; }
      if (!body) throw err('bad_shape', `Massive HTTP ${res.status}`);
      return body;
    }
  };
  let tick = await readJson(path.join(GROUPED_DIR, '_tickers.json'));
  if (!tick || Date.now() - tick.at > 7 * DAY) {
    const list = [], info = {};
    let url = `${MASSIVE_BASE}/v3/reference/tickers?market=stocks&type=CS&active=true&limit=1000`;
    while (url) { const pg = parseTickersPage(await call(url)); list.push(...pg.tickers); Object.assign(info, pg.info); url = pg.next; }
    tick = { at: Date.now(), tickers: list, info };
    await writeFile(path.join(GROUPED_DIR, '_tickers.json'), JSON.stringify(tick));
  }
  const have = new Set((await readdir(GROUPED_DIR)).filter(f => /^\d{4}-\d{2}-\d{2}\.json$/.test(f)).map(f => f.slice(0, 10)));
  const today = new Date().toISOString().slice(0, 10);
  const todo = weekdaysBack(Date.now(), 522).filter(d => !have.has(d));
  console.log(`Massive: ${todo.length} يوم ناقص (~${Math.round(todo.length * MASSIVE_GAP_MS / 60000)} دقيقة)`);
  for (const [n, date] of todo.entries()) {
    try {
      const rows = parseGroupedDaily(await call(`${MASSIVE_BASE}/v2/aggs/grouped/locale/us/market/stocks/${date}?adjusted=true&include_otc=false`));
      // عطلة = صفوف قليلة: نحفظها فاضية (لا نعيد طلبها) إلا آخر 3 أيام (قد لا تكون نُشرت بعد)
      if (rows.length < 1000 && Date.now() - Date.parse(date) < 3 * DAY) continue;
      await writeFile(path.join(GROUPED_DIR, `${date}.json`), JSON.stringify(rows.length < 1000 ? [] : rows));
      if ((n + 1) % 20 === 0) console.log(`  ${n + 1}/${todo.length} (${date})`);
    } catch (e) {
      console.log(`  ${date}: ${e.message}`);
      if (e.message && /not authorized|NOT_AUTHORIZED|plan/i.test(e.message) && date !== today) continue; // أقدم من حد الخطة
    }
  }
  const files = (await readdir(GROUPED_DIR)).filter(f => /^\d{4}-\d{2}-\d{2}\.json$/.test(f)).sort();
  const days = [];
  for (const f of files) { const rows = await readJson(path.join(GROUPED_DIR, f)); if (Array.isArray(rows) && rows.length) days.push({ date: f.slice(0, 10), rows }); }
  const bySym = groupedToSymbols(days, new Set(tick.tickers));
  const entries = {};
  for (const [sym, b] of Object.entries(bySym)) {
    await writeFile(path.join(DAILY_DIR, `${sym}.json`), JSON.stringify(b));
    entries[sym] = { at: Date.now(), bars: b.t.length, last: new Date(b.t[b.t.length - 1]).toISOString().slice(0, 10), name: (tick.info[sym] || {}).name || null };
  }
  await writeFile(path.join(DAILY_DIR, '_meta.json'), JSON.stringify({ source: 'massive', fetchedAt: new Date().toISOString(),
    universe: tick.tickers.length, symbols: entries, from: days.length ? days[0].date : null, to: days.length ? days[days.length - 1].date : null, stats: { days: days.length }, failures: {} }));
  console.log(`Massive: ${days.length} يوم، ${Object.keys(entries).length} سهم`);
}

async function main() {
  await mkdir(DAILY_DIR, { recursive: true });
  const key = (ENV.MASSIVE_API_KEY || '').trim();
  if (key) {
    console.log('MASSIVE_API_KEY موجود → Massive grouped daily');
    try { return await mainMassive(key); }
    catch (e) { console.log(`Massive فشل (${e.message}) — نكمل بـ Yahoo بدون مفتاح.`); }
  } else console.log('ما فيه مفتاح Massive — نستخدم Yahoo (بدون مفتاح) وقائمة NASDAQ Trader.');
  await mainYahoo(process.argv.slice(2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(e => { console.error('تعذّر التنزيل: ' + e.message + ' — لا تغيير على البيانات المحفوظة.'); process.exit(0); });
}
