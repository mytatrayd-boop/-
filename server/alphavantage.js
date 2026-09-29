// عميل Alpha Vantage — المفتاح يبقى في الخادم فقط، ولا يُرسل للواجهة أبدًا.
import { barsFromAlphaVantage, parseNewsFeed, parseEarningsCalendar, toAvTime } from './engine.js';

const BASE = 'https://www.alphavantage.co/query';
const CACHE_TTL_MS = (Number(process.env.CACHE_TTL_MIN) || 240) * 60 * 1000;
const EARNINGS_TTL_MS = 24 * 60 * 60 * 1000;
const MIN_GAP_MS = 1100; // الخطة المجانية: طلب واحد بالثانية كحد أقصى (مُلاحظ فعليًا)
const cache = new Map(); // key -> {at, value}
let lastCallAt = 0;
let queue = Promise.resolve();

export class ProviderError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

// الحصة المجانية ~25 طلب/يوم: نخزّن الردود مؤقتًا حتى لا يستهلك تكرار المسح الحصة.
async function cached(key, ttl, load) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < ttl) return { value: hit.value, cached: true };
  const value = await load();
  cache.set(key, { at: Date.now(), value });
  return { value, cached: false };
}

// كل الطلبات تمر بطابور واحد بفاصل ≥ 1.1 ثانية، حتى لو جاءت من مسحين متزامنين.
function query(params, apiKey) {
  const run = async () => {
    const wait = lastCallAt + MIN_GAP_MS - Date.now();
    if (wait > 0) await new Promise(r => setTimeout(r, wait));
    lastCallAt = Date.now();
    const qs = new URLSearchParams({ ...params, apikey: apiKey });
    let res;
    try { res = await fetch(`${BASE}?${qs}`, { signal: AbortSignal.timeout(20000) }); }
    catch { throw new ProviderError('server_unavailable', 'تعذّر الوصول لـ Alpha Vantage.'); }
    if (!res.ok) throw new ProviderError('server_unavailable', `Alpha Vantage رد بالحالة ${res.status}.`);
    // لا نفترض صيغة: الرد قد يكون JSON أو CSV حتى لو طلبنا JSON.
    const text = await res.text();
    let payload = text;
    try { payload = JSON.parse(text); } catch { /* CSV خام */ }
    if (payload && typeof payload === 'object') {
      if (payload.Note || payload.Information) throw new ProviderError('rate_limited', 'تجاوزت حصة Alpha Vantage — قلّل عدد الأسهم أو انتظر لبكرة.');
      if (payload['Error Message']) throw new ProviderError('tool_error', 'رمز غير صحيح أو غير مدعوم.');
    }
    return payload;
  };
  const p = queue.then(run, run);
  queue = p.catch(() => {});
  return p;
}

export async function fetchDailyBars(symbol, apiKey) {
  const { value, cached: c } = await cached('bars:' + symbol, CACHE_TTL_MS, async () =>
    barsFromAlphaVantage(await query({ function: 'TIME_SERIES_DAILY', symbol, outputsize: 'compact', datatype: 'json' }, apiKey)));
  return { bars: value, cached: c };
}

export async function fetchNews(symbol, apiKey, { newsDays, minRelevance }) {
  const sinceMs = Date.now() - newsDays * 86400000;
  const { value, cached: c } = await cached(`news:${symbol}:${newsDays}:${minRelevance}`, CACHE_TTL_MS, async () =>
    parseNewsFeed(await query({ function: 'NEWS_SENTIMENT', tickers: symbol, time_from: toAvTime(sinceMs), sort: 'LATEST', limit: '50' }, apiKey), symbol, { sinceMs, minRelevance }));
  return { news: value, cached: c };
}

// طلب واحد يغطي السوق كله — لا نطلبه لكل سهم.
export async function fetchEarningsCalendar(apiKey) {
  const { value, cached: c } = await cached('earnings', EARNINGS_TTL_MS, async () =>
    parseEarningsCalendar(await query({ function: 'EARNINGS_CALENDAR', horizon: '3month' }, apiKey)));
  return { calendar: value, cached: c };
}
