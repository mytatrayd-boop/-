// مختبر الاتجاهات — تنزيل شموع 5 دقائق (الجلسة العادية فقط) إلى lab/data/5m/SYM.json
// المصدر: Massive/Polygon إن وُجد MASSIVE_API_KEY (سنتان)، وإلا Yahoo (آخر 60 يوم، بدون مفتاح).
// الاستخدام: node lab/fetch.mjs [SYM …] [--force]
// سهم يفشل يُسجَّل ويُتخطّى — لا يوقف التشغيل. التحليل في دوال صافية مُختبرة بدون شبكة.
import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(HERE, 'data');
const BARS_DIR = path.join(DATA_DIR, '5m');
const ENV = process.env;
const MASSIVE_BASE = (ENV.MASSIVE_API_BASE || 'https://api.polygon.io').replace(/\/+$/, '');
const MASSIVE_GAP_MS = Number(ENV.MASSIVE_GAP_MS) || 12500; // الخطة المجانية: 5 طلبات/دقيقة
const YAHOO_GAP_MS = Number(ENV.YAHOO_GAP_MS) || 1000;
const HISTORY_DAYS = Number(ENV.LAB_HISTORY_DAYS) || 730;   // سنتان
// شمعة 5 دقائق مع ما قبل/بعد السوق ≈ 192 يوميًا؛ 240 يوم تقويمي ≈ 165 يوم تداول ≈ 32 ألف صف (< 50 ألف)
export const CHUNK_DAYS = 240;
const FRESH_MS = 12 * 3600e3; // ملف نُزّل قبل أقل من 12 ساعة (إعادة تشغيل بنفس الأسبوع) لا يُعاد تنزيله
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
const DAY = 86400000;

const err = (code, message) => Object.assign(new Error(message), { code });

/* ---------- الوقت بتوقيت نيويورك (يراعي التوقيت الصيفي عبر Intl) ---------- */

const ET = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', hourCycle: 'h23', weekday: 'short',
  year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
});
const WD = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

export function etClock(ms) {
  const p = {};
  for (const x of ET.formatToParts(new Date(ms))) p[x.type] = x.value;
  return { date: `${p.year}-${p.month}-${p.day}`, weekday: WD[p.weekday], minutes: (Number(p.hour) % 24) * 60 + Number(p.minute) };
}

// t = بداية الشمعة: من 09:30 حتى 15:55 (آخر شمعة) أيام الإثنين–الجمعة
export function isRegularSession(ms) {
  if (!Number.isFinite(ms)) return false;
  const { weekday, minutes } = etClock(ms);
  return weekday <= 5 && minutes >= 570 && minutes < 960;
}

/* ---------- صيغة الشموع ---------- */

export const emptyBars = () => ({ t: [], o: [], h: [], l: [], c: [], v: [] });

// شمعة صالحة: كل الأسعار أرقام موجبة و h ≥ l
function validBar(o, h, l, c) {
  return [o, h, l, c].every(x => typeof x === 'number' && Number.isFinite(x) && x > 0) && h >= l;
}

// يدمج مجموعتين (الأحدث يغلب عند تكرار t) ويرتّب تصاعديًا
export function mergeBars(...sets) {
  const map = new Map();
  for (const b of sets) {
    if (!b || !Array.isArray(b.t)) continue;
    for (let i = 0; i < b.t.length; i++) map.set(b.t[i], [b.o[i], b.h[i], b.l[i], b.c[i], b.v[i]]);
  }
  const out = emptyBars();
  for (const t of [...map.keys()].sort((a, b) => a - b)) {
    const [o, h, l, c, v] = map.get(t);
    out.t.push(t); out.o.push(o); out.h.push(h); out.l.push(l); out.c.push(c); out.v.push(v);
  }
  return out;
}

export function sliceFrom(bars, fromMs) {
  const i = bars.t.findIndex(t => t >= fromMs);
  if (i <= 0) return i === 0 ? bars : emptyBars();
  const out = emptyBars();
  for (const k of Object.keys(out)) out[k] = bars[k].slice(i);
  return out;
}

// تغيّر التعديل (تقسيم سهم) بين تنزيلين؟ نقارن الإغلاق في الشموع المشتركة
export function adjustmentChanged(oldBars, newBars, tol = 0.01) {
  if (!oldBars || !newBars) return false;
  const idx = new Map(oldBars.t.map((t, i) => [t, i]));
  for (let i = 0; i < newBars.t.length; i++) {
    const j = idx.get(newBars.t[i]);
    if (j !== undefined && Math.abs(oldBars.c[j] / newBars.c[i] - 1) > tol) return true;
  }
  return false;
}

/* ---------- تحليل الردود (دوال صافية — مُختبرة) ---------- */

// Yahoo /v8/finance/chart → bars (الجلسة العادية، بدون شموع null، بدون نقطة «السعر الحي» غير المحاذية)
export function parseYahooChart(payload) {
  const chart = payload && payload.chart;
  if (!chart) throw err('bad_shape', 'رد Yahoo غير متوقع: ' + JSON.stringify(payload).slice(0, 200));
  if (chart.error) throw err('yahoo_error', 'Yahoo: ' + String(chart.error.description || chart.error.code || 'error').slice(0, 200));
  const r = Array.isArray(chart.result) ? chart.result[0] : null;
  if (!r) throw err('bad_shape', 'رد Yahoo بدون result.');
  const ts = Array.isArray(r.timestamp) ? r.timestamp : [];
  const q = (r.indicators && Array.isArray(r.indicators.quote) && r.indicators.quote[0]) || {};
  const col = k => (Array.isArray(q[k]) ? q[k] : []);
  const [O, H, L, C, V] = ['open', 'high', 'low', 'close', 'volume'].map(col);
  const out = emptyBars();
  for (let i = 0; i < ts.length; i++) {
    if (!Number.isFinite(ts[i]) || ts[i] % 300 !== 0) continue; // آخر نقطة أحيانًا وقت السعر الحي
    const t = ts[i] * 1000;
    if (!isRegularSession(t)) continue;
    const o = O[i], h = H[i], l = L[i], c = C[i];
    if (!validBar(o, h, l, c)) continue;
    out.t.push(t); out.o.push(o); out.h.push(h); out.l.push(l); out.c.push(c);
    out.v.push(Number.isFinite(V[i]) ? V[i] : 0);
  }
  return mergeBars(out);
}

// Massive/Polygon /v2/aggs → { bars, next }
export function parseMassiveAggs(payload) {
  if (!payload || typeof payload !== 'object') throw err('bad_shape', 'رد Massive غير متوقع.');
  if (payload.status === 'ERROR' || payload.status === 'NOT_AUTHORIZED') {
    const msg = String(payload.error || payload.message || payload.status);
    throw err(/exceeded|maximum requests/i.test(msg) ? 'rate_limited' : 'not_authorized', 'Massive: ' + msg.slice(0, 200));
  }
  if (!('results' in payload) && !('resultsCount' in payload)) throw err('bad_shape', 'رد Massive بدون results: ' + JSON.stringify(payload).slice(0, 200));
  const out = emptyBars();
  for (const r of Array.isArray(payload.results) ? payload.results : []) {
    if (!r || !Number.isFinite(r.t) || !isRegularSession(r.t)) continue;
    if (!validBar(r.o, r.h, r.l, r.c)) continue;
    out.t.push(r.t); out.o.push(r.o); out.h.push(r.h); out.l.push(r.l); out.c.push(r.c);
    out.v.push(Number.isFinite(r.v) ? r.v : 0);
  }
  return { bars: mergeBars(out), next: typeof payload.next_url === 'string' && payload.next_url ? payload.next_url : null };
}

// [from, to] كتواريخ YYYY-MM-DD (UTC) بقطع لا تتجاوز days يومًا ولا تتداخل
export function dateChunks(fromMs, toMs, days = CHUNK_DAYS) {
  const iso = ms => new Date(ms).toISOString().slice(0, 10);
  const out = [];
  let a = Math.floor(fromMs / DAY) * DAY;
  const end = Math.floor(toMs / DAY) * DAY;
  while (a <= end) {
    const b = Math.min(a + (days - 1) * DAY, end);
    out.push([iso(a), iso(b)]);
    a = b + DAY;
  }
  return out;
}

/* ---------- الشبكة ---------- */

const sleep = ms => new Promise(r => setTimeout(r, ms));
let lastCallAt = 0;
async function pace(gap) {
  const wait = lastCallAt + gap - Date.now();
  if (wait > 0) await sleep(wait);
  lastCallAt = Date.now();
}

// 429 / 5xx / انقطاع → إعادة حتى retries مرات مع انتظار متزايد
async function getJson(url, { headers = {}, gap, retries = 3, backoffMs = 2000, label = url }) {
  for (let attempt = 0; ; attempt++) {
    await pace(gap);
    let res = null, netErr = null;
    try { res = await fetch(url, { headers, signal: AbortSignal.timeout(60000) }); }
    catch (e) { netErr = e; }
    const retryable = netErr || res.status === 429 || res.status >= 500;
    if (retryable && attempt < retries) {
      const wait = backoffMs * 2 ** attempt;
      console.log(`  ${label}: ${netErr ? netErr.message : 'HTTP ' + res.status} — إعادة بعد ${wait / 1000} ث`);
      await sleep(wait);
      continue;
    }
    if (netErr) throw err('unavailable', `${label}: ${netErr.message}`);
    let body = null;
    try { body = await res.json(); } catch { /* تحت */ }
    if (!res.ok && !(body && body.status)) throw err('http', `${label}: HTTP ${res.status}`);
    if (!body) throw err('bad_shape', `${label}: رد بدون JSON (HTTP ${res.status})`);
    return body;
  }
}

async function fetchYahoo(sym) {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(sym)}?interval=5m&range=60d&includePrePost=false`;
  const body = await getJson(url, { headers: { 'User-Agent': UA, Accept: 'application/json' }, gap: YAHOO_GAP_MS, label: `Yahoo ${sym}` });
  return parseYahooChart(body);
}

async function fetchMassive(sym, key, fromMs, toMs) {
  const withKey = u => { const x = new URL(u); if (!x.searchParams.has('apiKey')) x.searchParams.set('apiKey', key); return x.toString(); };
  let all = emptyBars(), refused = 0, lastErr = null;
  const chunks = dateChunks(fromMs, toMs);
  for (const [from, to] of chunks) {
    let url = `${MASSIVE_BASE}/v2/aggs/ticker/${encodeURIComponent(sym)}/range/5/minute/${from}/${to}?adjusted=true&sort=asc&limit=50000`;
    try {
      for (let page = 0; url && page < 20; page++) {
        let parsed;
        for (let rl = 0; ; rl++) { // الحد بالدقيقة يرجع أحيانًا كـ status: ERROR داخل 200
          try { parsed = parseMassiveAggs(await getJson(withKey(url), { gap: MASSIVE_GAP_MS, backoffMs: 60000, label: `Massive ${sym} ${from}` })); break; }
          catch (e) { if (e.code === 'rate_limited' && rl < 3) { console.log('  حد الطلبات — انتظار 60 ث'); await sleep(60000); continue; } throw e; }
        }
        all = mergeBars(all, parsed.bars);
        url = parsed.next;
      }
    } catch (e) {
      // قطعة أقدم من حد الخطة ترجع NOT_AUTHORIZED — نتخطاها ونكمل الباقي
      if (e.code !== 'not_authorized') throw e;
      refused++; lastErr = e;
      console.log(`  ${sym} ${from}→${to}: مرفوض (${e.message.slice(0, 80)})`);
    }
  }
  if (refused === chunks.length && lastErr) throw lastErr;
  return all;
}

/* ---------- التشغيل ---------- */

async function readJson(file) {
  try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; }
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const only = args.filter(a => !a.startsWith('--')).map(s => s.toUpperCase());
  const universe = (await readJson(path.join(HERE, 'universe.json')))?.symbols || [];
  const symbols = only.length ? only : universe;
  const key = (ENV.MASSIVE_API_KEY || '').trim();
  const source = key ? 'massive' : 'yahoo';
  await mkdir(BARS_DIR, { recursive: true });

  const prevMeta = await readJson(path.join(DATA_DIR, 'meta.json'));
  const sameSource = prevMeta && prevMeta.source === source;
  const counts = {};
  // نحتفظ بأسهم المصدر نفسه التي لم نطلبها هذه المرة (تشغيل لرموز محددة)
  if (sameSource && only.length) Object.assign(counts, prevMeta.symbols || {});
  let minT = Infinity, maxT = -Infinity, failed = 0, refusedInRow = 0;
  const now = Date.now();
  console.log(`المصدر: ${source} — ${symbols.length} سهم`);

  for (const [n, sym] of symbols.entries()) {
    const file = path.join(BARS_DIR, `${sym}.json`);
    let existing = sameSource ? await readJson(file) : null;
    if (existing && !Array.isArray(existing.t)) existing = null;
    try {
      let bars;
      const fresh = existing && !force && existing.t.length && (now - (await stat(file)).mtimeMs) < FRESH_MS;
      if (fresh) {
        bars = existing;
        console.log(`[${n + 1}/${symbols.length}] ${sym}: حديث — بدون تنزيل (${bars.t.length} شمعة)`);
      } else {
        let fetched;
        if (source === 'massive') {
          // تحديث تدريجي: من آخر شمعة لدينا (مع 3 أيام تداخل للتحقق من التعديل)، وإلا سنتان كاملتان
          const start = existing && existing.t.length ? existing.t[existing.t.length - 1] - 3 * DAY : now - HISTORY_DAYS * DAY;
          fetched = await fetchMassive(sym, key, start, now);
          if (existing && adjustmentChanged(existing, fetched)) {
            console.log(`  ${sym}: تغيّر التعديل (تقسيم؟) — إعادة تنزيل كاملة`);
            existing = null;
            fetched = await fetchMassive(sym, key, now - HISTORY_DAYS * DAY, now);
          }
        } else {
          fetched = await fetchYahoo(sym);
          if (existing && adjustmentChanged(existing, fetched)) existing = null; // Yahoo: نتراكم أسبوعًا بعد أسبوع
        }
        bars = sliceFrom(mergeBars(existing, fetched), now - HISTORY_DAYS * DAY);
        if (!bars.t.length) throw err('empty', 'لا توجد شموع في الجلسة العادية');
        await writeFile(file, JSON.stringify(bars));
        console.log(`[${n + 1}/${symbols.length}] ${sym}: ${bars.t.length} شمعة (+${fetched.t.length} منزّلة)`);
      }
      counts[sym] = bars.t.length; refusedInRow = 0;
      minT = Math.min(minT, bars.t[0]); maxT = Math.max(maxT, bars.t[bars.t.length - 1]);
    } catch (e) {
      failed++;
      console.log(`[${n + 1}/${symbols.length}] ${sym}: فشل — ${e.message} (تخطّي)`);
      if (existing && existing.t.length) { counts[sym] = existing.t.length; } // نحتفظ بالقديم من نفس المصدر
      else delete counts[sym];
      refusedInRow = e.code === 'not_authorized' ? refusedInRow + 1 : 0;
      if (refusedInRow >= 3) { console.log('المفتاح مرفوض 3 مرات متتالية — إيقاف.'); break; }
    }
  }

  for (const sym of Object.keys(counts)) {
    const b = await readJson(path.join(BARS_DIR, `${sym}.json`));
    if (b && b.t && b.t.length) { minT = Math.min(minT, b.t[0]); maxT = Math.max(maxT, b.t[b.t.length - 1]); }
  }
  const ok = Object.keys(counts).length;
  const meta = {
    source, fetchedAt: new Date().toISOString(),
    from: ok ? etClock(minT).date : null, to: ok ? etClock(maxT).date : null,
    symbols: counts,
  };
  await writeFile(path.join(DATA_DIR, 'meta.json'), JSON.stringify(meta, null, 2) + '\n');
  console.log(`تم: ${ok} سهم، فشل ${failed}. البيانات ${meta.from} → ${meta.to}`);
  if (!ok) { console.error('لم ينجح أي سهم.'); process.exit(1); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(e => { console.error(e); process.exit(1); });
}
