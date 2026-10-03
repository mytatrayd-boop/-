// استمرار انفجار الحجم: حجم اليوم ≥ k × متوسط 20 يومًا قبله، صعود ≥ 3%، إغلاق في أعلى 30% من مدى اليوم،
// وإغلاق فوق أعلى إغلاق 20 يومًا سابقة (كسر قاعدة) → شراء افتتاح الغد، خروج بعد 3/5 أيام، وقف كارثي تحت أدنى يوم الإشارة.
// (نسخة أوسع من server/spike.js تعمل على الأسهم الكبيرة وسلة الأسهم الأصغر.)
export default {
  family: 'vol-spike', name: 'استمرار انفجار الحجم', universe: 'large|small',
  grid: { volMult: [2, 3, 5], hold: [3, 5], universe: ['large', 'small'] },
  make(p) {
    let c, l, v, va, ib, hi20;
    return {
      universe: p.universe, maxPositions: 5, entryAt: 'open', exitAt: 'open', hold: p.hold,
      init(P) { c = P.c; l = P.l; v = P.v; va = P.series('vavg:20'); ib = P.series('ibs'); hi20 = P.series('hi:20'); },
      score(d, s) {
        if (d < 1) return null;
        const ratio = v[s][d] / va[s][d - 1];
        if (!(ratio >= p.volMult) || !(c[s][d] / c[s][d - 1] - 1 >= 0.03) || !(ib[s][d] >= 0.7) || !(c[s][d] > hi20[s][d - 1])) return null;
        return { score: ratio, stop: l[s][d] };
      },
    };
  },
  rules: p => [
    `الكون: ${p.universe === 'small' ? 'سلة الأسهم الأصغر (سيولة ≥ 1M$، سعر ≥ 3$)' : 'أعلى 500 سهم متوافق بالسيولة، سعر ≥ 5$'}.`,
    `الدخول: حجم اليوم ≥ ${p.volMult}× متوسط 20 يومًا قبله، صعود ≥ 3%، إغلاق في أعلى 30% من المدى وفوق أعلى إغلاق 20 يومًا → شراء بافتتاح الغد.`,
    `الوقف: أدنى يوم الإشارة. الخروج: بافتتاح اليوم ${p.hold} بعد الدخول.`,
    'الحجم: 20% لكل سهم، حد أقصى 5 مراكز.',
  ],
};
