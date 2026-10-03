// تتبع الاتجاه على صندوق المؤشر: نحتفظ بـ SPY/QQQ ما دام الإغلاق فوق متوسط 100/200، وإلا نقد.
// الفحص يوميًا أو آخر يوم في الشهر، والتنفيذ بافتتاح اليوم التالي.
import { lastOfMonth } from './common.mjs';
export default {
  family: 'etf-trend', name: 'تتبع اتجاه صندوق المؤشر', universe: 'etf',
  grid: { asset: ['SPY', 'QQQ'], sma: [100, 200], check: ['day', 'month'] },
  make(p) {
    let P, c, m;
    return {
      universe: [p.asset], maxPositions: 1, entryAt: 'open', exitAt: 'open',
      init(x) { P = x; c = P.c; m = P.series('sma:' + p.sma); },
      rebalance: d => p.check === 'day' || lastOfMonth(P, d),
      score: (d, s) => (c[s][d] > m[s][d] ? 1 : null),
    };
  },
};
