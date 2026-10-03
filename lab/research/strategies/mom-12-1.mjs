// زخم 12-1 شهر: العائد من قبل 252 يومًا حتى قبل 21 يومًا (نتجاهل آخر شهر). إعادة توازن شهرية أو أسبوعية،
// فلتر SPY فوق متوسط 200 (وإلا نقد)، تحجيم متساوٍ أو حسب التذبذب.
import { lastOfWeek, lastOfMonth, regimeFn, sizing } from './common.mjs';
export default {
  family: 'mom-12-1', name: 'زخم 12-1 شهر مع فلتر السوق', universe: 'large',
  grid: { n: [5, 10, 20], rebalance: ['month', 'week'], sizing: ['equal', 'vol'] },
  make(p) {
    let P, r252, r21;
    const cfg = {
      universe: 'large', maxPositions: p.n, entryAt: 'open', exitAt: 'open', sizing: sizing(p.sizing),
      init(x) { P = x; r252 = P.series('ret:252'); r21 = P.series('ret:21'); cfg.regime = regimeFn(P, 'sma200'); },
      rebalance: d => (p.rebalance === 'month' ? lastOfMonth(P, d) : lastOfWeek(P, d)),
      score: (d, s) => { const m = (1 + r252[s][d]) / (1 + r21[s][d]) - 1; return m > 0 ? m : null; },
    };
    return cfg;
  },
};
