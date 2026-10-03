// زخم مركّز: أقوى 5/10/15 سهمًا (بين الأسهم الكبيرة السائلة المتوافقة) بإعادة توازن أسبوعية، وفلتر SPY فوق متوسط 200 (وإلا نقد).
// طرق الترتيب: 12-1 خام، معدّل بالتذبذب (12-1 ÷ تذبذب 6 أشهر)، مع القرب من قمة السنة (≥ 85% منها)، أو مع شرط التسارع
// (عائد 3 أشهر > نصف عائد 6 أشهر وموجب).
import { lastOfWeek, regimeFn, mom121 } from './common.mjs';
export const SCORES = {
  r12_1: 'زخم 12-1 شهر',
  riskadj: 'زخم 12-1 ÷ تذبذب 6 أشهر',
  hi52mix: 'زخم 12-1 × القرب من قمة السنة (≥ 85%)',
  accel: 'زخم 12-1 بشرط تسارع (عائد 3 أشهر > نصف عائد 6 أشهر)',
};
export default {
  family: 'conc-mom', name: 'زخم مركّز أسبوعي', universe: 'large',
  grid: { score: Object.keys(SCORES), n: [5, 10, 15] },
  make(p) {
    let P, c, m, v126, hi, r63, r126;
    const cfg = {
      universe: 'large', maxPositions: p.n, entryAt: 'open', exitAt: 'open',
      init(x) { P = x; c = P.c; m = mom121(P); v126 = P.series('vol:126'); hi = P.series('hi:252'); r63 = P.series('ret:63'); r126 = P.series('ret:126'); cfg.regime = regimeFn(P, 'sma200'); },
      rebalance: d => lastOfWeek(P, d),
      score(d, s) {
        const x = m[s][d];
        if (!(x > 0)) return null;
        if (p.score === 'riskadj') return v126[s][d] > 0 ? x / v126[s][d] : null;
        if (p.score === 'hi52mix') { const k = c[s][d] / hi[s][d]; return k >= 0.85 ? x * k : null; }
        if (p.score === 'accel') return r63[s][d] > 0 && r63[s][d] > r126[s][d] / 2 ? x : null;
        return x;
      },
    };
    return cfg;
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الترتيب: ${SCORES[p.score]}؛ نختار أعلى ${p.n} سهمًا (زخم موجب فقط).`,
    'التوقيت: بعد إغلاق آخر يوم تداول في الأسبوع؛ التنفيذ بافتتاح أول يوم تداول بعده.',
    `الخروج: أي سهم خرج من أعلى ${p.n} يُباع في إعادة التوازن؛ الداخل الجديد يُشترى.`,
    `الحجم: ${(100 / p.n).toFixed(1)}% من رأس المال لكل سهم (بلا رافعة)، بلا إعادة موازنة للمراكز الباقية.`,
    'حالة السوق: إذا أغلق SPY تحت متوسط 200 يوم في يوم إعادة التوازن → بيع الكل والبقاء نقدًا حتى إعادة توازن يكون فيها فوقه.',
  ],
};
