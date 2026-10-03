// انعكاس أسبوعي مقطعي في الأسهم الكبيرة: آخر يوم تداول في الأسبوع نشتري الأكثر هبوطًا خلال 5/10 أيام
// (اختياريًا فوق متوسط 200)، ونحتفظ حتى إعادة التوازن التالية (أسبوع).
import { lastOfWeek } from './common.mjs';
export default {
  family: 'xs-reversal', name: 'انعكاس أسبوعي للخاسرين (أسهم كبيرة)', universe: 'large',
  grid: { n: [5, 10], look: [5, 10], trend: ['none', 'sma200'] },
  make(p) {
    let P, rt, c, m200;
    return {
      universe: 'large', maxPositions: p.n, entryAt: 'open', exitAt: 'open',
      init(x) { P = x; rt = P.series('ret:' + p.look); c = P.c; m200 = P.series('sma:200'); },
      rebalance: d => lastOfWeek(P, d),
      score: (d, s) => (rt[s][d] < 0 && (p.trend === 'none' || c[s][d] > m200[s][d]) ? -rt[s][d] : null),
    };
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الترتيب: بعد إغلاق آخر يوم تداول في الأسبوع، أكثر ${p.n} أسهم هبوطًا خلال ${p.look} أيام${p.trend === 'sma200' ? ' (فوق متوسط 200 فقط)' : ''}.`,
    'التنفيذ: افتتاح أول يوم تداول بعده؛ الاحتفاظ أسبوعًا حتى إعادة التوازن التالية (ما خرج من القائمة يُباع).',
    `الحجم: ${(100 / p.n).toFixed(1)}% لكل سهم.`,
  ],
};
