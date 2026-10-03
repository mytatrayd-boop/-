// ارتداد قصير الأجل في اتجاه صاعد: RSI(2) منخفض جدًا والإغلاق فوق متوسط 200 → شراء افتتاح الغد.
// الخروج: إغلاق فوق متوسط 5 أيام (أو RSI(2) > 70)، أو بعد 10 أيام كحد أقصى. أولوية لأدنى RSI.
export default {
  family: 'mr-rsi2', name: 'ارتداد RSI(2) في اتجاه صاعد', universe: 'large',
  grid: { th: [5, 10, 15], exit: ['sma5', 'rsi70'], maxPositions: [5, 10] },
  make(p) {
    let c, r, m200, m5;
    return {
      universe: 'large', maxPositions: p.maxPositions, entryAt: 'open', exitAt: 'open', hold: 10,
      init(P) { c = P.c; r = P.series('rsi:2'); m200 = P.series('sma:200'); m5 = P.series('sma:5'); },
      score: (d, s) => (c[s][d] > m200[s][d] && r[s][d] < p.th ? -r[s][d] : null),
      exitSignal: (d, s) => (p.exit === 'sma5' ? c[s][d] > m5[s][d] : r[s][d] > 70),
    };
  },
};
