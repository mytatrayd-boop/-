// زخم القرب من قمة 52 أسبوعًا: إعادة توازن أسبوعية، نشتري الأقرب لقمته السنوية (≥ 90% منها)،
// مع فلتر اختياري: SPY فوق متوسط 200 (وإلا نقد).
import { lastOfWeek, regimeFn } from './common.mjs';
export default {
  family: 'hi52-momentum', name: 'زخم القرب من قمة السنة', universe: 'large',
  grid: { n: [5, 10, 20], regime: ['none', 'sma200'] },
  make(p) {
    let P, c, hi, r126;
    const cfg = {
      universe: 'large', maxPositions: p.n, entryAt: 'open', exitAt: 'open',
      init(x) { P = x; c = P.c; hi = P.series('hi:252'); r126 = P.series('ret:126'); cfg.regime = regimeFn(P, p.regime); },
      rebalance: d => lastOfWeek(P, d),
      score: (d, s) => { const k = c[s][d] / hi[s][d]; return k >= 0.9 && r126[s][d] > 0 ? k + 0.01 * Math.min(r126[s][d], 1) : null; },
    };
    return cfg;
  },
};
