// تتبع الاتجاه على الأسهم: إغلاق عند أعلى إغلاق 6 أشهر أو 52 أسبوعًا (اختراق) و SPY فوق متوسط 200 → شراء افتتاح الغد.
// لا هدف ثابت: وقف متحرك = أعلى إغلاق منذ الدخول − k × ATR(14) (k = 3/4/5)، يُرفع فقط. حد للمراكز وسقف 30% للقطاع.
import { regimeFn } from './common.mjs';
export default {
  family: 'trend-breakout', name: 'اختراق قمة + وقف متحرك (ATR)', universe: 'large',
  grid: { look: [126, 252], trail: [3, 4, 5], maxPositions: [10, 15] },
  make(p) {
    let c, hi, r126;
    const cfg = {
      universe: 'large', maxPositions: p.maxPositions, entryAt: 'open', exitAt: 'open', trailAtr: p.trail, stopAtr: p.trail, sectorCap: 0.3,
      init(P) { c = P.c; hi = P.series('hi:' + p.look); r126 = P.series('ret:126'); cfg.regime = regimeFn(P, 'sma200'); },
      score: (d, s) => (c[s][d] >= hi[s][d] && Number.isFinite(r126[s][d]) ? r126[s][d] : null),
    };
    return cfg;
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الدخول: بعد الإغلاق، سهم أغلق عند أعلى إغلاق له في ${p.look === 252 ? '52 أسبوعًا' : '6 أشهر'} و SPY فوق متوسط 200 → شراء بافتتاح الغد؛ عند الزحام الأولوية لأعلى عائد 6 أشهر.`,
    `الوقف: مبدئيًا سعر الدخول − ${p.trail} × ATR(14)، ثم يُرفع يوميًا إلى (أعلى إغلاق منذ الدخول − ${p.trail} × ATR) ولا ينزل؛ التنفيذ عند لمسه (أو بالافتتاح لو فتح تحته).`,
    'الخروج: بالوقف فقط — لا هدف ثابت ولا خروج بالوقت.',
    `الحجم: ${(100 / p.maxPositions).toFixed(1)}% لكل سهم، حد أقصى ${p.maxPositions} مراكز، و30% كحد أقصى لكل قطاع.`,
  ],
};
