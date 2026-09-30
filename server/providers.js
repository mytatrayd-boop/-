// مزوّدات المسح حسب المفاتيح المتوفرة — مشترك بين الخادم وتطبيق الأندرويد (بدون اعتماد على Node).
// Massive: أسعار السوق كامل من مخزن محلي (بدون طلبات وقت المسح).
// Alpha Vantage: الأخبار وتقويم الأرباح (وأسعار «قائمتي» إذا ما فيه Massive).
// بدون أي مفتاح: وضع تجريبي ببيانات مصطنعة موسومة بوضوح في الواجهة.
import { fetchDailyBars, fetchNews, fetchEarningsCalendar } from './alphavantage.js';
import { demoProviders } from './demo.js';
import { HISTORY_DAYS } from './massive.js';

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
  } else {
    pv.bars = sym => fetchDailyBars(sym, alphaKey);
  }
  if (alphaKey) {
    pv.news = (sym, newsP) => fetchNews(sym, alphaKey, newsP);
    pv.earnings = () => fetchEarningsCalendar(alphaKey);
  }
  return pv;
}
