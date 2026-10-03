// السلة الأساسية المتوافقة: لا يوجد صندوق متوافق بتاريخ 10 سنوات، فنقرّبه بأكبر 20/30 سهمًا متوافقًا بقيمة التداول 60 يومًا
// (بديل تقريبي للقيمة السوقية)، بالتساوي أو بوزن قيمة التداول (سقف 15% للسهم). إعادة توازن شهرية. تُستخدم وحدها و«أساسًا» في
// «أساس + قمر صناعي» (core-satellite).
import { lastOfMonth } from './common.mjs';
export function advWeights(xs, cap = 0.15) {
  let w = xs.map(x => Math.max(0, x.adv));
  const tot = w.reduce((a, b) => a + b, 0) || 1;
  w = w.map(x => x / tot);
  for (let it = 0; it < 10; it++) {
    const over = w.reduce((a, x) => a + Math.max(0, x - cap), 0);
    if (over < 1e-12) break;
    const free = w.reduce((a, x) => a + (x < cap ? x : 0), 0);
    w = w.map(x => (x >= cap ? cap : x + over * (x / free)));
  }
  return w;
}
export default {
  family: 'core-basket', name: 'السلة الأساسية المتوافقة (أكبر الأسهم بالسيولة)', universe: 'large',
  grid: { k: [20, 30], weight: ['equal', 'adv'] },
  make(p) {
    let P, adv;
    return {
      universe: 'large', maxPositions: p.k, entryAt: 'open', exitAt: 'open',
      init(x) { P = x; adv = P.series('adv:60'); },
      rebalance: d => lastOfMonth(P, d),
      score: (d, s) => (adv[s][d] > 0 ? { score: adv[s][d], adv: adv[s][d] } : null),
      select(d, cands) {
        const top = cands.slice(0, p.k);
        const w = p.weight === 'adv' ? advWeights(top) : top.map(() => 1 / top.length);
        return top.map((x, i) => ({ ...x, w: w[i] }));
      },
    };
  },
  rules: p => [
    `السلة: أكبر ${p.k} سهمًا متوافقًا بمتوسط قيمة التداول 60 يومًا (بديل تقريبي للقيمة السوقية؛ لا يوجد صندوق متوافق بتاريخ 10 سنوات).`,
    p.weight === 'adv' ? 'الوزن: بنسبة قيمة التداول، بحد أقصى 15% للسهم.' : `الوزن: بالتساوي (${(100 / p.k).toFixed(1)}% لكل سهم).`,
    'إعادة التوازن: بعد إغلاق آخر يوم تداول في الشهر، التنفيذ بافتتاح اليوم التالي؛ ما خرج من القائمة يُباع، والمراكز الباقية لا يُعاد وزنها.',
  ],
};
