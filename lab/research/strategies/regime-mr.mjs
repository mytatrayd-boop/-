// طبقة حالة السوق فوق فكرة الارتداد (RSI(2) < 10 فوق متوسط 200، خروج فوق متوسط 5):
// لا دخول إلا إذا SPY فوق متوسط 200 و/أو تذبذب SPY 20 يوم < 25%، مع تحجيم متساوٍ أو حسب التذبذب.
// الطبقة تُختار داخل الاختبار الأمامي نفسه (لا نختارها بعد رؤية النتائج خارج العينة).
import { regimeFn, sizing } from './common.mjs';
export default {
  family: 'regime-mr', name: 'ارتداد RSI(2) + فلتر حالة السوق', universe: 'large',
  grid: { regime: ['sma200', 'vol', 'both'], sizing: ['equal', 'vol'], maxPositions: [5, 10] },
  make(p) {
    let c, r, m200, m5;
    const cfg = {
      universe: 'large', maxPositions: p.maxPositions, entryAt: 'open', exitAt: 'open', hold: 10, sizing: sizing(p.sizing),
      init(P) { c = P.c; r = P.series('rsi:2'); m200 = P.series('sma:200'); m5 = P.series('sma:5'); cfg.regime = regimeFn(P, p.regime); },
      score: (d, s) => (c[s][d] > m200[s][d] && r[s][d] < 10 ? -r[s][d] : null),
      exitSignal: (d, s) => c[s][d] > m5[s][d],
    };
    return cfg;
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    'الدخول: بعد الإغلاق، سهم فوق متوسط 200 يوم و RSI(2) < 10 → شراء بافتتاح الغد؛ الأولوية لأدنى RSI(2).',
    `حالة السوق (للدخول فقط): ${p.regime === 'sma200' ? 'SPY فوق متوسط 200' : p.regime === 'vol' ? 'تذبذب SPY 20 يومًا < 25% سنويًا' : 'SPY فوق متوسط 200 وتذبذبه 20 يومًا < 25%'}.`,
    'الخروج: أول إغلاق فوق متوسط 5 أيام → بيع بافتتاح الغد، أو بعد 10 أيام تداول.',
    `الحجم: ${(100 / p.maxPositions).toFixed(1)}% لكل سهم${p.sizing === 'vol' ? ' × min(1، 30% ÷ تذبذب السهم السنوي 20 يومًا)' : ''}، حد أقصى ${p.maxPositions} مراكز.`,
  ],
};
