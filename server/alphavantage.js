// عميل Alpha Vantage — المفتاح يبقى في الخادم فقط، ولا يُرسل للواجهة أبدًا.
import { barsFromAlphaVantage } from './engine.js';

const BASE = 'https://www.alphavantage.co/query';
const CACHE_TTL_MS = (Number(process.env.CACHE_TTL_MIN) || 240) * 60 * 1000;
const cache = new Map(); // sym -> {at, bars}

export class ProviderError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

// الحصة المجانية ~25 طلب/يوم: نخزّن الرد مؤقتًا حتى لا يستهلك تكرار المسح الحصة.
export async function fetchDailyBars(symbol, apiKey) {
  const hit = cache.get(symbol);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return { bars: hit.bars, cached: true };

  const url = `${BASE}?function=TIME_SERIES_DAILY&symbol=${encodeURIComponent(symbol)}&outputsize=compact&datatype=json&apikey=${encodeURIComponent(apiKey)}`;
  let res;
  try { res = await fetch(url, { signal: AbortSignal.timeout(20000) }); }
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
  const bars = barsFromAlphaVantage(payload);
  cache.set(symbol, { at: Date.now(), bars });
  return { bars, cached: false };
}
