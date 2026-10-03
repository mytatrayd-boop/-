// مزوّدات المسح حسب المفاتيح المتوفرة — مشترك بين الخادم وتطبيق الأندرويد (بدون اعتماد على Node).
// Massive: أسعار السوق كامل من مخزن محلي (بدون طلبات وقت المسح).
// Alpha Vantage: الأخبار وتقويم الأرباح (وأسعار «قائمتي» إذا ما فيه Massive).
// بدون أي مفتاح: وضع تجريبي ببيانات مصطنعة موسومة بوضوح في الواجهة.
import { fetchDailyBars, fetchNews, fetchEarningsCalendar } from './alphavantage.js';
import { demoProviders } from './demo.js';
import { HISTORY_DAYS } from './massive.js';
import { liveSignal } from './trend.js';

const TREND_DAYS = 10;                 // أيام تقويمية: الأسبوع الحالي + سياق الأسبوع الماضي (الخط قد يبدأ هناك)
const TREND_CACHE_MS = 10 * 60 * 1000; // كاش 10 دقائق لكل سهم — الخطة المجانية 5 طلبات/دقيقة مشتركة مع المزامنة
export const NO_MASSIVE_MSG = 'الشارت يحتاج مفتاح Massive — الإعدادات ← المفاتيح';

export function buildProviders({ massiveKey, alphaKey, store }) {
  if (!massiveKey && !alphaKey) return demoProviders;
  const pv = { demo: false };
  if (store) {
    pv.bars = async sym => ({ bars: store.bars(sym), cached: true });
    pv.profile = store.profile;
    pv.universe = async opts => {
      if (!store.state.ready) {
        const pr = store.state.progress;
        throw new Error(store.state.error && !store.state.syncing
          ? 'المزامنة متوقفة: ' + store.state.error
          : `بيانات السوق تتجهز (${store.state.days} يوم من ${HISTORY_DAYS}${pr ? `، يجلب ${pr.date}` : ''}) — حاول بعد دقائق.`);
      }
      return { tickers: store.universe(opts), lastDay: store.state.lastDay };
    };
    const cache = new Map(); // sym → { at, p } (الطلب الجاري يُشارك أيضًا)
    pv.trend5m = sym => {
      const hit = cache.get(sym);
      if (hit && Date.now() - hit.at < TREND_CACHE_MS) return hit.p;
      const now = Date.now();
      const p = store.aggs5m(sym, now - TREND_DAYS * 86400000, now)
        .then(bars => ({ bars, demo: false, dataAsOf: bars.t.length ? bars.t[bars.t.length - 1] : null }));
      cache.set(sym, { at: now, p });
      p.catch(() => { if (cache.get(sym) && cache.get(sym).p === p) cache.delete(sym); }); // الخطأ لا يُخزّن
      return p;
    };
  } else {
    pv.bars = sym => fetchDailyBars(sym, alphaKey);
  }
  if (alphaKey) {
    pv.news = (sym, newsP) => fetchNews(sym, alphaKey, newsP);
    pv.earnings = () => fetchEarningsCalendar(alphaKey);
  }
  return pv;
}

// رد تبويب الاتجاهات (نفس الشكل في الخادم /api/trend وفي التطبيق RASED_LOCAL.trend)
export async function trendFor(providers, sym, nowMs = Date.now()) {
  sym = String(sym || '').trim().toUpperCase();
  if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(sym)) throw Object.assign(new Error('رمز غير صالح.'), { code: 'bad_symbol' });
  if (!providers.trend5m) throw Object.assign(new Error(NO_MASSIVE_MSG), { code: 'no_massive' });
  const { bars, demo, dataAsOf } = await providers.trend5m(sym);
  const profile = providers.profile ? providers.profile(sym) : null;
  return { sym, bars, live: liveSignal(bars, undefined, nowMs), demo: !!demo, dataAsOf, profile: profile || null };
}
