// تراجع إلى المتوسط في سهم قوي: إغلاق > متوسط 50 > متوسط 200 وعائد 6 أشهر > 20%، ولمس أدنى اليوم للمتوسط 10/20
// مع إغلاق فوقه → شراء افتتاح الغد. الخروج: إغلاق فوق أعلى سعر 10 أيام سابقة، أو الوقت، أو وقف ATR.
export default {
  family: 'pullback-ma', name: 'تراجع إلى المتوسط في سهم قوي', universe: 'large',
  grid: { ma: [10, 20], hold: [5, 10], stopAtr: [2, 3] },
  make(p) {
    let c, l, m, m50, m200, r126, hh;
    return {
      universe: 'large', maxPositions: 5, entryAt: 'open', exitAt: 'open', hold: p.hold, stopAtr: p.stopAtr,
      init(P) { c = P.c; l = P.l; m = P.series('sma:' + p.ma); m50 = P.series('sma:50'); m200 = P.series('sma:200'); r126 = P.series('ret:126'); hh = P.series('hh:10'); },
      score(d, s) {
        const x = c[s][d];
        if (!(x > m50[s][d] && m50[s][d] > m200[s][d] && r126[s][d] > 0.2)) return null;
        return l[s][d] <= m[s][d] && x > m[s][d] ? r126[s][d] : null;
      },
      exitSignal: (d, s) => d > 0 && c[s][d] > hh[s][d - 1],
    };
  },
};
