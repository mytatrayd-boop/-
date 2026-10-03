// زخم القطاعات: نرتب القطاعات (من Yahoo) بمتوسط زخم 12-1 لأسهمها المؤهلة (3 أسهم على الأقل)، ونأخذ أفضل 2/3 قطاعات
// بزخم موجب، وداخل كل منها أقوى 2/3/5 أسهم. إعادة توازن أسبوعية أو شهرية، فلتر SPY فوق متوسط 200 (وإلا نقد).
import { lastOfWeek, lastOfMonth, regimeFn, mom121 } from './common.mjs';
export function pickSectors(cands, sectorOf, sectors, per) {
  const by = new Map();
  for (const x of cands) { const sec = sectorOf(x.s); if (!sec) continue; if (!by.has(sec)) by.set(sec, []); by.get(sec).push(x); }
  const ranked = [...by].filter(([, xs]) => xs.length >= 3).map(([sec, xs]) => [sec, xs.reduce((a, x) => a + x.score, 0) / xs.length, xs])
    .filter(([, mean]) => mean > 0).sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).slice(0, sectors);
  const n = sectors * per, out = [];
  for (const [, , xs] of ranked) out.push(...xs.filter(x => x.score > 0).sort((a, b) => b.score - a.score || a.s - b.s).slice(0, per));
  return out.map(x => ({ ...x, w: 1 / n }));
}
export default {
  family: 'sector-mom', name: 'زخم القطاعات (أفضل القطاعات ثم أقوى أسهمها)', universe: 'large',
  grid: { sectors: [2, 3], per: [2, 3, 5], rebalance: ['week', 'month'] },
  make(p) {
    let P, m;
    const cfg = {
      universe: 'large', maxPositions: p.sectors * p.per, entryAt: 'open', exitAt: 'open',
      init(x) { P = x; m = mom121(P); cfg.regime = regimeFn(P, 'sma200'); },
      rebalance: d => (p.rebalance === 'month' ? lastOfMonth(P, d) : lastOfWeek(P, d)),
      score: (d, s) => (P.sector[s] && Number.isFinite(m[s][d]) ? m[s][d] : null),
      select: (d, cands) => pickSectors(cands, s => P.sector[s], p.sectors, p.per),
    };
    return cfg;
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$، بقطاع معروف من Yahoo.',
    `القطاعات: متوسط زخم 12-1 شهر لأسهم كل قطاع (3 أسهم على الأقل)؛ نأخذ أفضل ${p.sectors} قطاعات بمتوسط موجب.`,
    `الأسهم: أقوى ${p.per} أسهم بزخم 12-1 داخل كل قطاع مختار؛ ${(100 / (p.sectors * p.per)).toFixed(1)}% لكل سهم.`,
    `التوقيت: بعد إغلاق آخر يوم تداول في ${p.rebalance === 'month' ? 'الشهر' : 'الأسبوع'}، التنفيذ بافتتاح اليوم التالي؛ ما خرج يُباع.`,
    'حالة السوق: SPY تحت متوسط 200 يوم في يوم إعادة التوازن → نقد.',
  ],
};
