// استمرار الفجوة الصاعدة: افتتاح أعلى من إغلاق الأمس بـ g، وإغلاق فوق الافتتاح (الفجوة صمدت)، وحجم ≥ k × المتوسط،
// وإغلاق فوق متوسط 50 → شراء افتتاح الغد. وقف تحت أدنى يوم الفجوة، خروج بعد 3/7 أيام.
export default {
  family: 'gap-up', name: 'استمرار الفجوة الصاعدة بحجم', universe: 'large',
  grid: { gap: [0.02, 0.04], volMult: [1.5, 3], hold: [3, 7] },
  make(p) {
    let o, c, l, v, va, gp, m50;
    return {
      universe: 'large', maxPositions: 5, entryAt: 'open', exitAt: 'open', hold: p.hold,
      init(P) { o = P.o; c = P.c; l = P.l; v = P.v; va = P.series('vavg:20'); gp = P.series('gap'); m50 = P.series('sma:50'); },
      score(d, s) {
        if (d < 1 || !(gp[s][d] >= p.gap) || !(c[s][d] > o[s][d]) || !(v[s][d] >= p.volMult * va[s][d - 1]) || !(c[s][d] > m50[s][d])) return null;
        return { score: gp[s][d], stop: l[s][d] };
      },
    };
  },
};
