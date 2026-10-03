// زخم مع دخول على تراجع قصير: سهم في أعلى 10% بزخم 12-1 (ترتيب مقطعي في ذلك اليوم) وفوق متوسط 50، تراجع يومين/ثلاثة
// متتالية أو RSI(2) < 15 → شراء افتتاح الغد. الخروج: إغلاق فوق متوسط 5 أيام أو بعد 5/10 أيام. فلتر SPY فوق متوسط 200.
import { regimeFn, mom121, xsRank } from './common.mjs';
export default {
  family: 'mom-pullback', name: 'زخم قوي + شراء التراجع القصير', universe: 'large',
  grid: { pull: ['down2', 'down3', 'rsi15'], hold: [5, 10], maxPositions: [5, 10] },
  make(p) {
    let c, m, rk, m50, m5, dn, r2;
    const cfg = {
      universe: 'large', maxPositions: p.maxPositions, entryAt: 'open', exitAt: 'open', hold: p.hold,
      init(P) { c = P.c; m = mom121(P); rk = xsRank(P, 'mom121', m); m50 = P.series('sma:50'); m5 = P.series('sma:5'); dn = P.series('down'); r2 = P.series('rsi:2'); cfg.regime = regimeFn(P, 'sma200'); },
      score(d, s) {
        if (!(rk[s][d] >= 0.9) || !(c[s][d] > m50[s][d])) return null;
        const ok = p.pull === 'down2' ? dn[s][d] >= 2 : p.pull === 'down3' ? dn[s][d] >= 3 : r2[s][d] < 15;
        return ok ? m[s][d] : null;
      },
      exitSignal: (d, s) => c[s][d] > m5[s][d],
    };
    return cfg;
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الإعداد: السهم في أعلى 10% من الكون بزخم 12-1 شهر، فوق متوسط 50 يومًا، و${p.pull === 'rsi15' ? 'RSI(2) < 15' : `${p.pull === 'down2' ? 'يومي' : 'ثلاثة أيام'} هبوط متتالية`} → شراء بافتتاح الغد (الأولوية للأقوى زخمًا)، و SPY فوق متوسط 200.`,
    `الخروج: أول إغلاق فوق متوسط 5 أيام → بيع بافتتاح الغد، أو بعد ${p.hold} أيام تداول كحد أقصى.`,
    `الحجم: ${(100 / p.maxPositions).toFixed(1)}% لكل سهم، حد أقصى ${p.maxPositions} مراكز، بلا رافعة.`,
  ],
};
