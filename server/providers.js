// مزوّدات المسح حسب المفاتيح المتوفرة — مشترك بين الخادم وتطبيق الأندرويد (بدون اعتماد على Node).
// Massive: أسعار السوق كامل من مخزن محلي (بدون طلبات وقت المسح).
// Alpha Vantage: الأخبار وتقويم الأرباح (وأسعار «قائمتي» إذا ما فيه Massive).
// بدون أي مفتاح: وضع تجريبي ببيانات مصطنعة موسومة بوضوح في الواجهة.
import { fetchDailyBars, fetchNews, fetchEarningsCalendar } from './alphavantage.js';
import { demoProviders } from './demo.js';
import { HISTORY_DAYS } from './massive.js';
import { liveSignal } from './trend.js';
import { applyYaqeen } from './engine.js';
import { SPIKE_DEFAULTS, spikeLookback, marketDays, latestMarketDayIdx, scanSpikes, spikeCard, isoDay } from './spike.js';
import { fetchYahoo5m } from './yahoo.js';
import { demoBars5m } from './demo.js';

const TREND_DAYS = 10;                 // أيام تقويمية: الأسبوع الحالي + سياق الأسبوع الماضي (الخط قد يبدأ هناك)
const TREND_CACHE_MS = 10 * 60 * 1000; // كاش 10 دقائق لكل سهم — الخطة المجانية 5 طلبات/دقيقة مشتركة مع المزامنة
export const NO_MASSIVE_MSG = 'الشارت يحتاج مفتاح Massive — الإعدادات ← المفاتيح';

// شموع 5 دقائق من Yahoo (بدون مفتاح). fallbackDemo: لو فشل Yahoo نرجع شموع تجريبية موسومة (demo: true + السبب).
export function yahooTrend5m({ fallbackDemo = true, fetchImpl } = {}) {
  const cache = new Map(); // sym → { at, p } — النجاح فقط يُخزّن
  return sym => {
    const hit = cache.get(sym);
    if (hit && Date.now() - hit.at < TREND_CACHE_MS) return hit.p;
    const now = Date.now();
    const p = fetchYahoo5m(sym, now, fetchImpl ? { fetchImpl } : {})
      .then(bars => ({ bars, demo: false, source: 'yahoo', dataAsOf: bars.t.length ? bars.t[bars.t.length - 1] : null }));
    cache.set(sym, { at: now, p });
    p.catch(() => { if (cache.get(sym) && cache.get(sym).p === p) cache.delete(sym); });
    if (!fallbackDemo) return p;
    return p.catch(e => {
      const bars = demoBars5m(sym);
      return { bars, demo: true, source: 'demo', fallback: 'تعذّر جلب Yahoo (' + (e && e.message ? e.message : 'خطأ') + ') — شموع تجريبية', dataAsOf: bars.t.length ? bars.t[bars.t.length - 1] : null };
    });
  };
}

// yahoo: true = شموع الاتجاهات من Yahoo لما ما فيه مفتاح Massive (التطبيق والخادم؛ الاختبارات والنسخة المستقلة بدونها)
export function buildProviders({ massiveKey, alphaKey, store, yahoo = false, fetchImpl }) {
  if (!massiveKey && !alphaKey) return yahoo ? { ...demoProviders, trend5m: yahooTrend5m({ fetchImpl }) } : demoProviders;
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
    // انفجار السيولة محليًا من أيام السوق المخزّنة (بدون أي طلب إضافي) — فقط لما يكفي التاريخ
    pv.spikeMarket = () => store.state.days > spikeLookback() ? { ...store.allBars(), profile: store.profile } : null;
  } else {
    pv.bars = sym => fetchDailyBars(sym, alphaKey);
    if (yahoo) pv.trend5m = yahooTrend5m({ fetchImpl });
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
  const profile = providers.profile ? providers.profile(sym) : null;
  const out = await providers.trend5m(sym);
  const res = { sym, bars: out.bars, live: liveSignal(out.bars, undefined, nowMs), demo: !!out.demo, dataAsOf: out.dataAsOf, profile: profile || null };
  if (out.source) res.source = out.source;
  if (out.fallback) res.fallback = out.fallback;
  return res;
}

/* ---------- انفجار السيولة ---------- */
// المصدر بالترتيب: 1) حساب محلي من مخزن Massive الحقيقي (إن كان فيه أيام كافية)
// 2) أحدث spikes-today.json من المسح الليلي (مضمّن/محدّث من GitHub أو من قرص الخادم)  3) سوق تجريبي (بدون مفاتيح)  4) لا شيء.
// فلتر يقين بنفس applyYaqeen في المسح الرئيسي. الشكل نفسه في /api/spikes و RASED_LOCAL.spikes.
const validNightly = n => !!(n && typeof n === 'object' && typeof n.day === 'string' && Array.isArray(n.signals));
export function newestNightly(list) {
  return (list || []).filter(validNightly)
    .sort((a, b) => b.day.localeCompare(a.day) || String(b.generatedAt || '').localeCompare(String(a.generatedAt || '')))[0] || null;
}
const spikeMemo = new WeakMap(); // bars Map → { key, out } — المسح على آخر يوم مرة واحدة لكل تحديث للمخزن
function computeSpikes(m, p = SPIKE_DEFAULTS) {
  const key = m.dates ? m.dates.length + ':' + m.dates[m.dates.length - 1] : '';
  const memo = m.bars && spikeMemo.get(m.bars);
  if (memo && memo.key === key && key) return memo.out;
  const days = marketDays(m.bars), di = latestMarketDayIdx(m.bars, days);
  const sigs = di < 0 ? [] : scanSpikes(m.bars, di, p, { days, commonStocks: m.commonStocks || null });
  const bars = sym => m.bars instanceof Map ? m.bars.get(sym) : m.bars[sym];
  const out = { day: di < 0 ? null : isoDay(days[di]), signals: sigs.map(s => {
    const pr = m.profile ? m.profile(s.sym) : null;
    return spikeCard(s.sym, bars(s.sym), s, { name: (pr && pr.name) || null, exchange: (pr && pr.exchange) || null, p });
  }) };
  if (m.bars && key) spikeMemo.set(m.bars, { key, out });
  return out;
}

export function spikesFor(providers, req = {}, nightlies = []) {
  const yaqeen = req.yaqeen && typeof req.yaqeen === 'object' ? req.yaqeen : {};
  const p = SPIKE_DEFAULTS;
  let out = null;
  const local = !providers.demo && providers.spikeMarket ? providers.spikeMarket() : null;
  if (local) out = { source: 'local', demo: false, generatedAt: new Date().toISOString(), dataSource: 'massive', ...computeSpikes(local, p) };
  const n = out ? null : newestNightly(nightlies);
  if (n) out = { source: 'nightly', demo: false, generatedAt: n.generatedAt || null, dataSource: n.source || null, day: n.day, signals: n.signals };
  if (!out && providers.demo && providers.spikeMarket) out = { source: 'demo', demo: true, generatedAt: new Date().toISOString(), dataSource: 'demo', ...computeSpikes(providers.spikeMarket(), p) };
  if (!out) out = { source: 'none', demo: false, generatedAt: null, dataSource: null, day: null, signals: [] };
  const { kept, excluded } = applyYaqeen(out.signals.map(s => s.sym), yaqeen, { excludeHaram: req.excludeHaram !== false, excludeMashbooh: !!req.excludeMashbooh });
  const keep = new Set(kept);
  return {
    ...out,
    signals: out.signals.filter(s => keep.has(s.sym)).map(s => ({ ...s, yaqeen: yaqeen[s.sym] || 'غير معروف' })),
    yaqeenExcluded: excluded,
    params: { entry: p.entry, hold: p.hold, stop: p.stop, volMult: p.volMult, minChange: p.minChange, minPrice: p.minPrice, maxPrice: p.maxPrice },
  };
}
