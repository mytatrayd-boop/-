// ارتداد IBS: إغلاق قرب قاع اليوم (IBS منخفض) بعد أيام هبوط متتالية وفوق متوسط 200 → شراء افتتاح الغد.
// الخروج: إغلاق فوق أعلى الأمس، أو بعد 5 أيام.
export default {
  family: 'mr-ibs', name: 'ارتداد IBS بعد أيام هبوط', universe: 'large',
  grid: { ibs: [0.1, 0.2], down: [1, 2, 3], maxPositions: [5, 10] },
  make(p) {
    let c, h, ib, dn, m200;
    return {
      universe: 'large', maxPositions: p.maxPositions, entryAt: 'open', exitAt: 'open', hold: 5,
      init(P) { c = P.c; h = P.h; ib = P.series('ibs'); dn = P.series('down'); m200 = P.series('sma:200'); },
      score: (d, s) => (ib[s][d] < p.ibs && dn[s][d] >= p.down && c[s][d] > m200[s][d] ? -ib[s][d] : null),
      exitSignal: (d, s) => d > 0 && c[s][d] > h[s][d - 1],
    };
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الدخول: بعد الإغلاق، سهم فوق متوسط 200 يوم، أغلق في أدنى ${p.ibs * 100}% من مدى يومه (IBS) بعد ${p.down} يوم هبوط متتالية على الأقل → شراء بافتتاح الغد؛ الأولوية لأدنى IBS.`,
    'الخروج: أول إغلاق فوق أعلى سعر الأمس → بيع بافتتاح الغد، أو بعد 5 أيام تداول كحد أقصى.',
    `الحجم: ${(100 / p.maxPositions).toFixed(1)}% لكل سهم، حد أقصى ${p.maxPositions} مراكز.`,
  ],
};
