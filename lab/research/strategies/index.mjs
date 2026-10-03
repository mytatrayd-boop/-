// كل عائلات الاستراتيجيات (كل واحدة بشبكة صغيرة ≤ 12 تركيبة لتقليل الإفراط في التوفيق).
// العائلة الخامسة عشرة «ensemble» تُبنى في run.mjs من نتائج هذه العائلات داخل الاختبار الأمامي.
import mrRsi2 from './mr-rsi2.mjs';
import mrIbs from './mr-ibs.mjs';
import xsReversal from './xs-reversal.mjs';
import hi52 from './hi52-momentum.mjs';
import mom121 from './mom-12-1.mjs';
import vcp from './vcp-breakout.mjs';
import volSpike from './vol-spike.mjs';
import tom from './calendar-tom.mjs';
import overnight from './overnight.mjs';
import gapUp from './gap-up.mjs';
import pullback from './pullback-ma.mjs';
import regimeMr from './regime-mr.mjs';
import lowvol from './lowvol-trend.mjs';
import etfTrend from './etf-trend.mjs';
import concMom from './conc-mom.mjs';
import momRotation from './mom-rotation.mjs';
import trendBreakout from './trend-breakout.mjs';
import sectorMom from './sector-mom.mjs';
import momPullback from './mom-pullback.mjs';
import coreBasket from './core-basket.mjs';

export const FAMILIES = [mrRsi2, mrIbs, xsReversal, hi52, mom121, vcp, volSpike, tom, overnight, gapUp, pullback, regimeMr, lowvol, etfTrend,
  // الجولة 3: الزخم/الاتجاه للتفوق على SPY
  concMom, momRotation, trendBreakout, sectorMom, momPullback, coreBasket];

// { a: [1, 2], b: [x] } → [{a:1,b:x}, {a:2,b:x}]
export function gridCombos(grid) {
  let combos = [{}];
  for (const [k, vals] of Object.entries(grid || {})) combos = combos.flatMap(c => vals.map(v => ({ ...c, [k]: v })));
  return combos;
}
