// دفاعي: أقل الأسهم تذبذبًا (60 يومًا) بين الأسهم في اتجاه صاعد (فوق متوسط 200 وعائد 6 أشهر موجب)،
// إعادة توازن شهرية، مع فلتر سوق اختياري. الهدف تراجع منخفض أكثر من العائد الأعلى.
import { lastOfMonth, regimeFn, sizing } from './common.mjs';
export default {
  family: 'lowvol-trend', name: 'أسهم منخفضة التذبذب في اتجاه صاعد', universe: 'large',
  grid: { n: [10, 20], regime: ['none', 'sma200'], sizing: ['equal', 'vol'] },
  make(p) {
    let P, c, m200, r126, v60;
    const cfg = {
      universe: 'large', maxPositions: p.n, entryAt: 'open', exitAt: 'open', sizing: sizing(p.sizing),
      init(x) { P = x; c = P.c; m200 = P.series('sma:200'); r126 = P.series('ret:126'); v60 = P.series('vol:60'); cfg.regime = regimeFn(P, p.regime); },
      rebalance: d => lastOfMonth(P, d),
      score: (d, s) => (c[s][d] > m200[s][d] && r126[s][d] > 0 && v60[s][d] > 0 ? -v60[s][d] : null),
    };
    return cfg;
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الترتيب: آخر يوم تداول في الشهر، أقل ${p.n} سهمًا تذبذبًا (60 يومًا) بين الأسهم فوق متوسط 200 وبعائد 6 أشهر موجب.`,
    'التنفيذ: افتتاح اليوم التالي؛ ما خرج يُباع.',
    `الحجم: ${(100 / p.n).toFixed(1)}% لكل سهم${p.sizing === 'vol' ? ' × min(1، 30% ÷ تذبذب السهم)' : ''}${p.regime === 'sma200' ? '؛ SPY تحت متوسط 200 → نقد' : ''}.`,
  ],
};
