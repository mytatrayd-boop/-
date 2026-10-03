// تدوير الزخم مع بوابة السوق: إذا البوابة مفتوحة (SPY فوق متوسط 200، أو عائد SPY 12 شهرًا > 0) نمسك أقوى n سهمًا بزخم 12-1؛
// وإذا أُغلقت ننتقل إلى نقد (0%) أو إلى «السلة الأساسية»: أكبر 20 سهمًا متوافقًا بقيمة التداول (بديل تقريبي للقيمة السوقية)
// بالتساوي، حتى لا نغيب عن السوق طويلاً. إعادة توازن أسبوعية.
import { lastOfWeek, regimeFn, mom121 } from './common.mjs';
export const CORE_N = 20;
export default {
  family: 'mom-rotation', name: 'تدوير الزخم ↔ السلة الأساسية', universe: 'large',
  grid: { gate: ['sma200', 'spy12m'], off: ['cash', 'core'], n: [5, 10, 15] },
  make(p) {
    let P, m, adv, gate;
    return {
      universe: 'large', maxPositions: Math.max(p.n, CORE_N), entryAt: 'open', exitAt: 'open',
      init(x) { P = x; m = mom121(P); adv = P.series('adv:60'); gate = regimeFn(P, p.gate); },
      rebalance: d => lastOfWeek(P, d),
      score: (d, s) => (Number.isFinite(adv[s][d]) ? { score: m[s][d] > 0 ? m[s][d] : -1e9, adv: adv[s][d] } : null),
      select(d, cands) {
        if (gate(d)) return cands.filter(x => x.score > 0).slice(0, p.n).map(x => ({ ...x, w: 1 / p.n }));
        if (p.off === 'cash') return [];
        return [...cands].sort((a, b) => b.adv - a.adv || a.s - b.s).slice(0, CORE_N).map(x => ({ ...x, w: 1 / CORE_N }));
      },
    };
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `البوابة: ${p.gate === 'sma200' ? 'إغلاق SPY فوق متوسط 200 يوم' : 'عائد SPY آخر 12 شهرًا > 0'} عند إغلاق آخر يوم تداول في الأسبوع.`,
    `البوابة مفتوحة: أعلى ${p.n} سهمًا بزخم 12-1 شهر (موجب)، ${(100 / p.n).toFixed(1)}% لكل سهم.`,
    p.off === 'cash' ? 'البوابة مغلقة: بيع الكل والبقاء نقدًا.' : `البوابة مغلقة: سلة أكبر ${CORE_N} سهمًا متوافقًا بقيمة التداول، ${100 / CORE_N}% لكل سهم.`,
    'التنفيذ: بافتتاح أول يوم تداول بعد يوم القرار؛ ما خرج من القائمة يُباع، والجديد يُشترى؛ بلا رافعة.',
  ],
};
