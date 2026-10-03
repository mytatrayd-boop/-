// Yahoo Finance (بدون مفتاح) — شموع يومية (المختبر والمسح الليلي) وشموع 5 دقائق (تبويب الاتجاهات).
// بدون أي اعتماد على Node: الخادم يجلب مباشرة، وتطبيق الأندرويد عبر جسر Java (fetch → RasedNative).
// التحليل في دوال صافية مُختبرة على عينات ثابتة (بدون شبكة).
import { etParts } from './trend.js';

export const YAHOO_HOSTS = ['query1.finance.yahoo.com', 'query2.finance.yahoo.com'];
export const YAHOO_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
const DAY_MS = 86400000;

const yErr = (code, message) => Object.assign(new Error(message), { code });
const good = (...xs) => xs.every(x => typeof x === 'number' && Number.isFinite(x) && x > 0);

// الجزء المشترك: { meta, ts[], O, H, L, C, V } أو خطأ واضح
function chartParts(payload) {
  const chart = payload && payload.chart;
  if (!chart) throw yErr('bad_shape', 'رد Yahoo غير متوقع: ' + JSON.stringify(payload).slice(0, 200));
  if (chart.error) {
    const msg = String(chart.error.description || chart.error.code || 'error');
    throw yErr(/not found|no data|delisted/i.test(msg) ? 'no_data' : 'yahoo_error', 'Yahoo: ' + msg.slice(0, 200));
  }
  const r = Array.isArray(chart.result) ? chart.result[0] : null;
  if (!r) throw yErr('bad_shape', 'رد Yahoo بدون result.');
  const q = (r.indicators && Array.isArray(r.indicators.quote) && r.indicators.quote[0]) || {};
  const col = k => (Array.isArray(q[k]) ? q[k] : []);
  return { meta: r.meta || {}, ts: Array.isArray(r.timestamp) ? r.timestamp : [], O: col('open'), H: col('high'), L: col('low'), C: col('close'), V: col('volume') };
}

const emptyBars = () => ({ t: [], o: [], h: [], l: [], c: [], v: [] });
function pushSorted(rows) {
  rows.sort((a, b) => a[0] - b[0]);
  const out = emptyBars();
  for (const [t, o, h, l, c, v] of rows) {
    if (out.t.length && out.t[out.t.length - 1] === t) { // تكرار نفس اليوم/الشمعة: الأحدث يغلب
      const k = out.t.length - 1; out.o[k] = o; out.h[k] = h; out.l[k] = l; out.c[k] = c; out.v[k] = v; continue;
    }
    out.t.push(t); out.o.push(o); out.h.push(h); out.l.push(l); out.c.push(c); out.v.push(v);
  }
  return out;
}

// interval=1d → bars يومية بنفس صيغة buildBars (t = منتصف ليل UTC لتاريخ اليوم بتوقيت نيويورك).
// يوم الجلسة الجارية (قبل الإغلاق) يُحذف — شمعته ناقصة. nowMs للاختبار.
export function parseYahooDaily(payload, nowMs = Date.now()) {
  const { meta, ts, O, H, L, C, V } = chartParts(payload);
  const reg = meta.currentTradingPeriod && meta.currentTradingPeriod.regular;
  const openDay = reg && Number.isFinite(reg.start) && Number.isFinite(reg.end) && nowMs < reg.end * 1000 && nowMs >= reg.start * 1000
    ? etParts(reg.start * 1000).date : null;
  const rows = [];
  for (let i = 0; i < ts.length; i++) {
    if (!Number.isFinite(ts[i])) continue;
    const o = O[i], h = H[i], l = L[i], c = C[i];
    if (!good(o, h, l, c) || h < l) continue;
    const date = etParts(ts[i] * 1000).date;
    if (date === openDay) continue;
    rows.push([Date.parse(date + 'T00:00:00Z'), o, h, l, c, Number.isFinite(V[i]) ? V[i] : 0]);
  }
  return pushSorted(rows);
}

// interval=5m → الجلسة النظامية فقط (09:30–16:00 نيويورك)، بدون نقطة «السعر الحي» غير المحاذية
export function parseYahoo5m(payload) {
  const { ts, O, H, L, C, V } = chartParts(payload);
  const rows = [];
  for (let i = 0; i < ts.length; i++) {
    if (!Number.isFinite(ts[i]) || ts[i] % 300 !== 0) continue;
    const t = ts[i] * 1000, e = etParts(t);
    if (e.weekday > 5 || e.minutes < 570 || e.minutes >= 960) continue;
    const o = O[i], h = H[i], l = L[i], c = C[i];
    if (!good(o, h, l, c) || h < l) continue;
    rows.push([t, o, h, l, c, Number.isFinite(V[i]) ? V[i] : 0]);
  }
  return pushSorted(rows);
}

// اسم الشركة من meta (إن وُجد)
export const yahooName = payload => {
  try { const m = payload.chart.result[0].meta; return m.longName || m.shortName || null; } catch { return null; }
};

export function yahooChartUrl(sym, query, host = YAHOO_HOSTS[0]) {
  const s = encodeURIComponent(String(sym).replace(/\./g, '-')); // BRK.B → BRK-B
  return `https://${host}/v8/finance/chart/${s}?${query}`;
}

// يجرب query1 ثم query2. fetchImpl قابل للحقن (الاختبارات). المتصفح يمنع تغيير User-Agent فيتجاهله؛ جسر Java يضبطه.
export async function fetchYahooChart(sym, query, { fetchImpl = (u, o) => fetch(u, o), timeoutMs = 30000 } = {}) {
  let last = null;
  for (const host of YAHOO_HOSTS) {
    try {
      const opts = { headers: { Accept: 'application/json' } };
      if (typeof AbortSignal !== 'undefined' && AbortSignal.timeout) opts.signal = AbortSignal.timeout(timeoutMs);
      const res = await fetchImpl(yahooChartUrl(sym, query, host), opts);
      let body = null;
      try { body = await res.json(); } catch { /* تحت */ }
      if (body && body.chart) return body; // حتى رد الخطأ (رمز غير موجود) نرجعه للمحلل
      last = yErr(res.status === 429 ? 'rate_limited' : 'unavailable', `Yahoo رد بالحالة ${res.status}`);
    } catch (e) {
      last = yErr('unavailable', 'تعذّر الوصول لـ Yahoo: ' + (e && e.message ? e.message : e));
    }
  }
  throw last;
}

// شموع 5 دقائق لآخر 10 أيام تقويمية (الأسبوع الحالي + سياق الأسبوع الماضي، مثل مسار Massive)
export async function fetchYahoo5m(sym, nowMs = Date.now(), opts = {}) {
  const p1 = Math.floor((nowMs - 10 * DAY_MS) / 1000), p2 = Math.floor(nowMs / 1000);
  return parseYahoo5m(await fetchYahooChart(sym, `interval=5m&period1=${p1}&period2=${p2}&includePrePost=false`, opts));
}
