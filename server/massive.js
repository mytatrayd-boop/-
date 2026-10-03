// Massive (Polygon سابقًا) — أسعار السوق الأمريكي كامل.
// طلب «Grouped Daily» واحد يرجع شمعة يوم واحد لكل الأسهم، فنبني تاريخًا محليًا (يوم = ملف)
// ونحسب منه نفس مؤشرات scoreTicker لكل السوق بدون أي طلب إضافي وقت المسح.
//
// ⚠️ شكل الرد مبني على توثيق Massive/Polygon — لم يُلاحظ رد حي بعد (الشبكة هنا تحجب النطاق).
// شغّل `npm run check:massive` مرة بمفتاحك قبل الاعتماد عليه. المحلل دفاعي: أي صف ناقص يُتجاهل.
// بدون أي اعتماد على Node: التخزين يُمرَّر كمحوّل (قرص في الخادم، IndexedDB في تطبيق الأندرويد).
import { etParts } from './trend.js';

const ENV = typeof process !== 'undefined' && process.env ? process.env : {}; // غير موجود داخل تطبيق الأندرويد
const BASE = (ENV.MASSIVE_API_BASE || 'https://api.polygon.io').replace(/\/+$/, '');
const FREE_GAP_MS = Number(ENV.MASSIVE_GAP_MS) || 12500; // الخطة المجانية: 5 طلبات/دقيقة
export const HISTORY_DAYS = 60;     // أيام تداول تكفي RSI(14) و ATR(14) ومتوسط حجم حتى 60 يوم
const KEEP_DAYS = HISTORY_DAYS + 10;
const TICKERS_TTL_MS = 7 * 86400000; // قائمة الأسهم العادية تتحدث أسبوعيًا

export class MassiveError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

/* ---------- تحليل الردود (دوال صافية — مُختبرة) ---------- */

// Grouped Daily → [[ticker, o, h, l, c, v], ...]
export function parseGroupedDaily(payload) {
  checkPayload(payload);
  if (!('results' in payload) && !('resultsCount' in payload)) throw new MassiveError('bad_shape', 'رد Massive بدون results. بداية الرد: ' + JSON.stringify(payload).slice(0, 200));
  const rows = [];
  for (const r of Array.isArray(payload.results) ? payload.results : []) {
    const t = typeof r.T === 'string' ? r.T : null;
    const vals = [r.o, r.h, r.l, r.c, r.v].map(Number);
    if (!t || vals.some(x => !Number.isFinite(x)) || vals[3] <= 0) continue;
    rows.push([t, ...vals]);
  }
  return rows; // فاضي = عطلة/نهاية أسبوع أو اليوم لم يُنشر بعد
}

// فحص رد الخطأ المشترك بين طلبات Massive
function checkPayload(payload) {
  if (!payload || typeof payload !== 'object') throw new MassiveError('bad_shape', 'رد Massive غير متوقع.');
  if (payload.status === 'ERROR' || payload.status === 'NOT_AUTHORIZED') {
    throw new MassiveError(/exceeded|maximum requests/i.test(payload.error || payload.message || '') ? 'rate_limited' : 'not_authorized',
      'Massive: ' + String(payload.error || payload.message || payload.status).slice(0, 200));
  }
}

// شموع 5 دقائق (/v2/aggs/ticker/SYM/range/5/minute/…) → bars بالجلسة النظامية فقط (09:30–16:00 نيويورك، يراعي التوقيت الصيفي)
export function parseAggs5m(payload) {
  checkPayload(payload);
  if (!('results' in payload) && !('resultsCount' in payload)) throw new MassiveError('bad_shape', 'رد شموع 5 دقائق بدون results. بداية الرد: ' + JSON.stringify(payload).slice(0, 200));
  const rows = [];
  for (const r of Array.isArray(payload.results) ? payload.results : []) {
    if (!r) continue;
    const t = Number(r.t), vals = [r.o, r.h, r.l, r.c].map(Number), v = Number(r.v) || 0;
    if (!Number.isFinite(t) || vals.some(x => !Number.isFinite(x) || x <= 0)) continue;
    const e = etParts(t);
    if (e.weekday > 5 || e.minutes < 570 || e.minutes >= 960) continue; // قبل/بعد الجلسة
    rows.push([t, ...vals, v]);
  }
  rows.sort((a, b) => a[0] - b[0]);
  const out = { t: [], o: [], h: [], l: [], c: [], v: [] };
  let prev = -1;
  for (const [t, o, h, l, c, v] of rows) {
    if (t === prev) continue; // تكرار
    prev = t;
    out.t.push(t); out.o.push(o); out.h.push(h); out.l.push(l); out.c.push(c); out.v.push(v);
  }
  return out;
}

// رمز البورصة (MIC) → اسم يعرفه المستخدم، عشان يفرّق بين الرموز المتشابهة
const EXCHANGES = { XNAS: 'NASDAQ', XNYS: 'NYSE', XASE: 'NYSE American', ARCX: 'NYSE Arca', BATS: 'Cboe BZX', IEXG: 'IEX' };
export const exchangeName = mic => (mic && (EXCHANGES[mic] || mic)) || null;

// /v3/reference/tickers → {tickers:[...], info:{sym:{name, exchange}}, next}
export function parseTickersPage(payload) {
  if (!payload || !Array.isArray(payload.results)) throw new MassiveError('bad_shape', 'رد قائمة الأسهم غير متوقع: ' + JSON.stringify(payload).slice(0, 200));
  const tickers = [], info = {};
  for (const r of payload.results) {
    if (!r || typeof r.ticker !== 'string') continue;
    tickers.push(r.ticker);
    info[r.ticker] = { name: typeof r.name === 'string' ? r.name : null, exchange: exchangeName(r.primary_exchange) };
  }
  return { tickers, info, next: payload.next_url || null };
}

// أيام العمل (الإثنين–الجمعة) من الأحدث للأقدم، ابتداءً من «اليوم» بتوقيت UTC
export function weekdaysBack(fromMs, count) {
  const out = [];
  let d = new Date(fromMs - (fromMs % 86400000));
  while (out.length < count) {
    const wd = d.getUTCDay();
    if (wd !== 0 && wd !== 6) out.push(d.toISOString().slice(0, 10));
    d = new Date(d.getTime() - 86400000);
  }
  return out;
}

// أيام مخزّنة [{date, rows}] (تصاعديًا) → bars لكل سهم بنفس صيغة المحرك
export function buildBars(days) {
  const map = new Map();
  days.forEach(({ date, rows }, di) => {
    const t = Date.parse(date + 'T00:00:00Z');
    for (const [sym, o, h, l, c, v] of rows) {
      let b = map.get(sym);
      if (!b) { b = { t: [], o: [], h: [], l: [], c: [], v: [], lastDay: -1 }; map.set(sym, b); }
      b.t.push(t); b.o.push(o); b.h.push(h); b.l.push(l); b.c.push(c); b.v.push(v); b.lastDay = di;
    }
  });
  return map;
}

/* ---------- العميل + المخزن المحلي ---------- */

// storage: { listDays() → ['YYYY-MM-DD'…], readDay(d) → rows, writeDay(d, rows), removeDay(d), readMeta(k), writeMeta(k, v) }
export function createMassiveStore({ apiKey, storage, log = console.log }) {
  let days = [];          // [{date, rows}] تصاعديًا
  let bars = new Map();
  let commonStocks = null; // Set
  let tickerInfo = {};     // sym → {name, exchange}
  let nextSlot = 0;        // موعد الطلب التالي: يُحجز فورًا فتصطف الطلبات المتزامنة (المزامنة + شموع 5 دقائق) بفاصل 12.5 ث
  const state = { ready: false, syncing: false, lastDay: null, days: 0, tickers: 0, commonStocks: 0, error: null, progress: null };

  async function call(url) {
    const now = Date.now(), at = Math.max(now, nextSlot);
    nextSlot = at + FREE_GAP_MS;
    if (at > now) await new Promise(r => setTimeout(r, at - now));
    const u = new URL(url); u.searchParams.set('apiKey', apiKey);
    let res;
    try { res = await fetch(u.toString(), { signal: AbortSignal.timeout(60000) }); }
    catch { throw new MassiveError('unavailable', 'تعذّر الوصول لـ Massive. تأكد من الإنترنت.'); }
    let payload = null;
    try { payload = await res.json(); } catch { /* يُعالج تحت */ }
    if (res.status === 429) throw new MassiveError('rate_limited', 'Massive: تجاوزت حد الطلبات بالدقيقة.');
    if (res.status === 401 || res.status === 403) throw new MassiveError('not_authorized', 'Massive: المفتاح غير صالح أو الخطة لا تشمل هذا الطلب' + (payload && payload.message ? ` (${payload.message})` : '') + '.');
    if (!payload) throw new MassiveError('bad_shape', `Massive رد بالحالة ${res.status} بدون JSON.`);
    return payload;
  }

  async function loadFromDisk() {
    const all = (await storage.listDays()).filter(d => /^\d{4}-\d{2}-\d{2}$/.test(d)).sort();
    days = [];
    for (const d of all.slice(-KEEP_DAYS)) {
      try { const rows = await storage.readDay(d); if (Array.isArray(rows)) days.push({ date: d, rows }); }
      catch { log(`تجاهل يوم تالف: ${d}`); }
    }
    for (const d of all.slice(0, -KEEP_DAYS)) await storage.removeDay(d);
    try {
      const saved = await storage.readMeta('tickers');
      // ملف قديم بدون أسماء الشركات → نعيد جلبه (طلبات قليلة) عشان يظهر الاسم الكامل
      if (saved && Date.now() - saved.at < TICKERS_TTL_MS && saved.info) { commonStocks = new Set(saved.tickers); tickerInfo = saved.info; }
    } catch { /* لا يوجد بعد */ }
    rebuild();
  }

  function rebuild() {
    bars = buildBars(days);
    state.days = days.length;
    state.lastDay = days.length ? days[days.length - 1].date : null;
    state.tickers = bars.size;
    state.commonStocks = commonStocks ? commonStocks.size : 0;
    state.ready = days.length >= 30;
  }

  async function refreshCommonStocks() {
    const list = [], info = {};
    let url = `${BASE}/v3/reference/tickers?market=stocks&type=CS&active=true&limit=1000`;
    while (url) {
      const page = parseTickersPage(await call(url));
      list.push(...page.tickers); Object.assign(info, page.info); url = page.next;
    }
    if (list.length < 1000) throw new MassiveError('bad_shape', `قائمة الأسهم العادية ناقصة (${list.length}).`);
    commonStocks = new Set(list); tickerInfo = info;
    await storage.writeMeta('tickers', { at: Date.now(), tickers: list, info });
  }

  // يجلب الأيام الناقصة (تعبئة أولى ~60 يوم تداول ≈ 15 دقيقة بالخطة المجانية، بعدها طلب واحد يوميًا)
  async function sync() {
    if (state.syncing) return;
    state.syncing = true; state.error = null;
    try {
      if (!commonStocks) await refreshCommonStocks();
      const have = new Set(days.map(d => d.date));
      // نطلب أيام عمل أكثر من المطلوب لتعويض العطل الرسمية (ترجع فاضية)
      const wanted = weekdaysBack(Date.now(), Math.ceil(HISTORY_DAYS * 1.1)).filter(d => !have.has(d));
      const newest = wanted.filter(d => !state.lastDay || d > state.lastDay);
      const backfill = days.length >= HISTORY_DAYS ? [] : wanted.filter(d => state.lastDay && d < state.lastDay);
      const todo = [...newest, ...backfill];
      const todayStr = new Date().toISOString().slice(0, 10);
      let i = 0;
      for (const date of todo) {
        state.progress = { done: i++, total: todo.length, date };
        let rows;
        try { rows = parseGroupedDaily(await call(`${BASE}/v2/aggs/grouped/locale/us/market/stocks/${date}?adjusted=true&include_otc=false`)); }
        catch (e) {
          // الخطة المجانية ترفض يوم اليوم قبل نشر بيانات نهاية اليوم — نتخطاه ونعيد المحاولة لاحقًا
          if (e.code === 'not_authorized' && date === todayStr) continue;
          throw e;
        }
        if (rows.length < 1000) continue; // عطلة، أو يوم لم يُنشر بعد (لا نخزّنه حتى يُعاد طلبه لاحقًا)
        await storage.writeDay(date, rows);
        days.push({ date, rows });
        days.sort((a, b) => a.date.localeCompare(b.date));
        if (days.length > KEEP_DAYS) days = days.slice(-KEEP_DAYS);
        rebuild();
      }
      log(`Massive: ${state.days} يوم، ${state.tickers} رمز، آخر يوم ${state.lastDay}`);
    } catch (e) {
      state.error = e.message; log('Massive sync: ' + e.message);
    } finally {
      state.syncing = false; state.progress = null;
    }
  }

  // الكون القابل للمسح: أسهم عادية فقط (بدون صناديق/وارنتات)، تداولت في آخر يوم، سعر ≥ minPrice،
  // ومتوسط قيمة التداول اليومية ≥ minDollarVol — وإلا تسيطر الأسهم الخاملة على «السيولة غير الطبيعية».
  function universe({ minPrice, minDollarVol, avgDays }) {
    const last = days.length - 1, out = [];
    for (const [sym, b] of bars) {
      if (commonStocks && !commonStocks.has(sym)) continue;
      if (b.lastDay !== last || b.c.length < 40) continue;
      const n = b.c.length;
      if (b.c[n - 1] < minPrice) continue;
      let dv = 0; const k = Math.min(avgDays, n - 1);
      for (let i = n - 1 - k; i < n - 1; i++) dv += b.c[i] * b.v[i];
      if (dv / k < minDollarVol) continue;
      out.push(sym);
    }
    return out;
  }

  // شموع 5 دقائق لسهم واحد — نفس طابور الطلبات (الخطة المجانية: حتى إغلاق آخر يوم، مو لحظي)
  async function aggs5m(sym, fromMs, toMs) {
    if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(sym)) throw new MassiveError('bad_symbol', 'رمز غير صالح.');
    const from = etParts(fromMs).date, to = etParts(toMs).date;
    return parseAggs5m(await call(`${BASE}/v2/aggs/ticker/${encodeURIComponent(sym)}/range/5/minute/${from}/${to}?adjusted=true&sort=asc&limit=50000`));
  }

  return {
    state, loadFromDisk, sync, universe, aggs5m,
    profile: sym => tickerInfo[sym] || null,
    // كل شموع السوق المخزّنة (بدون أي طلب): لانفجار السيولة — { bars: Map(sym → bars), dates, commonStocks: Set|null }
    allBars: () => ({ bars, dates: days.map(d => d.date), commonStocks }),
    bars: sym => { const b = bars.get(sym); if (!b) throw new MassiveError('no_data', 'لا توجد بيانات لهذا الرمز في Massive.'); return b; },
  };
}
