// الجولة 2 بحثت «تراجع < 10% + التفوق على SPY» (غير ممكن بلا رافعة). الجولة 3 (قرار المالك): الأولوية للتفوق على SPY
// بتراجع ≤ 25% — نفس الأدوات بطبقات أخف.
// 1) طبقات على مستوى المحفظة (applyOverlay في engine.mjs): استهداف التذبذب، فلتر سوق أقوى، قاطع تراجع.
//    شبكة ثابتة من 12 طبقة (مُعرّفة مسبقًا، لا تُبنى من نتائج خارج العينة)، تُختار داخل العينة فقط.
// 2) طبقات على مستوى المركز داخل المحرك: وقف ATR أو نسبة ثابتة + سقف 30% للقطاع → عائلات «+risk».
import { regimeFn } from './strategies/common.mjs';
import { FAMILIES } from './strategies/index.mjs';

export const SECTOR_CAP = 0.30;
export const OVERLAY_COST = 0.001; // 0.10% لكل جانب على قيمة التعديل (سلة أسهم سائلة)

// مجموعتان ثابتتان من 12 طبقة (مُعرّفتان مسبقًا، لا تُبنى من نتائج خارج العينة):
//  'strict' (الجولة 2، هدف تراجع < 10%) و 'mild' (الجولة 3، هدف التفوق على SPY بتراجع ≤ 25%: استهداف تذبذب 15–25% وفلاتر انهيار فقط).
export function overlaySpecs(P, set = 'mild') {
  const strong = regimeFn(P, 'strong'), br = regimeFn(P, 'breadth'), sma = regimeFn(P, 'sma200'), y12 = regimeFn(P, 'spy12m');
  const W = 5; // أيام تداول في الأسبوع
  const L = set === 'strict' ? [
    ['none', 'بدون طبقة', {}],
    ['vt6-60', 'تذبذب 6% (60ي)', { vt: { target: 0.06, lookback: 60 } }],
    ['vt8-60', 'تذبذب 8% (60ي)', { vt: { target: 0.08, lookback: 60 } }],
    ['vt10-60', 'تذبذب 10% (60ي)', { vt: { target: 0.10, lookback: 60 } }],
    ['vt8-20', 'تذبذب 8% (20ي)', { vt: { target: 0.08, lookback: 20 } }],
    ['reg-strong', 'SPY > SMA200 وعائد شهر > 0', { regime: strong }],
    ['reg-breadth', 'اتساع > 50% فوق SMA50', { regime: br }],
    ['dd5-2w', 'قاطع 5% → نقد أسبوعين', { dd: { x: 0.05, days: 2 * W } }],
    ['dd7-4w', 'قاطع 7% → نقد 4 أسابيع', { dd: { x: 0.07, days: 4 * W } }],
    ['dd5-reg', 'قاطع 5% → نقد حتى يتحسن السوق', { dd: { x: 0.05, days: W, untilRegime: true } }],
    ['vt8-strong', 'تذبذب 8% + فلتر قوي', { vt: { target: 0.08, lookback: 60 }, regime: strong }],
    ['vt8-strong-dd5', 'تذبذب 8% + فلتر قوي + قاطع 5%/أسبوعين', { vt: { target: 0.08, lookback: 60 }, regime: strong, dd: { x: 0.05, days: 2 * W } }],
  ] : [
    ['none', 'بدون طبقة', {}],
    ['vt15-60', 'استهداف تذبذب المحفظة 15% (تذبذب 60 يومًا)', { vt: { target: 0.15, lookback: 60 } }],
    ['vt20-60', 'استهداف تذبذب المحفظة 20% (تذبذب 60 يومًا)', { vt: { target: 0.20, lookback: 60 } }],
    ['vt25-60', 'استهداف تذبذب المحفظة 25% (تذبذب 60 يومًا)', { vt: { target: 0.25, lookback: 60 } }],
    ['vt20-20', 'استهداف تذبذب المحفظة 20% (تذبذب 20 يومًا)', { vt: { target: 0.20, lookback: 20 } }],
    ['crash-sma200', 'فلتر انهيار: نقد إذا SPY تحت متوسط 200', { regime: sma }],
    ['crash-spy12m', 'فلتر انهيار: نقد إذا عائد SPY 12 شهرًا سالب', { regime: y12 }],
    ['reg-breadth', 'نقد إذا أقل من 50% من الكون فوق متوسط 50', { regime: br }],
    ['reg-strong', 'نقد إذا SPY تحت متوسط 200 أو عائده الشهري سالب', { regime: strong }],
    ['dd15-4w', 'قاطع تراجع 15% → نقد 4 أسابيع', { dd: { x: 0.15, days: 4 * W } }],
    ['dd20-reg', 'قاطع تراجع 20% → نقد حتى يعود SPY فوق متوسط 200', { dd: { x: 0.20, days: W, untilRegime: true } }],
    ['vt20-crash', 'تذبذب 20% + فلتر انهيار SMA200', { vt: { target: 0.20, lookback: 60 }, regime: sma }],
  ];
  const rf = set === 'strict' ? strong : sma;
  return L.map(([id, label, spec]) => ({ id, label, spec: { ...spec, cost: OVERLAY_COST }, regimeFn: rf }));
}

// عائلة «+risk»: نفس الإشارة + وقف لكل مركز (none | atrK | pctK) + فلتر دخول اختياري (gate) + سقف قطاع 30%
const STOPS = { none: {}, atr2: { stopAtr: 2 }, atr3: { stopAtr: 3 }, pct5: { stopPct: 0.05 }, pct10: { stopPct: 0.10 } };
export function withRisk(base, { grid, fixed = {}, suffix = '+risk' }) {
  const defaults = Object.fromEntries(Object.entries(base.grid).map(([k, v]) => [k, v[0]]));
  return {
    family: base.family + suffix, base: base.family, name: base.name + ' + وقف وسقف قطاع', universe: base.universe, grid,
    make(p) {
      const cfg = base.make({ ...defaults, ...fixed, ...p });
      Object.assign(cfg, STOPS[p.stop || 'none'], { sectorCap: SECTOR_CAP });
      if (p.gate && p.gate !== 'none') {
        const init0 = cfg.init;
        cfg.init = P => { if (init0) init0(P); const g = regimeFn(P, p.gate), r0 = cfg.regime; cfg.regime = r0 ? d => r0(d) && g(d) : g; };
      }
      return cfg;
    },
    rules: p => [
      ...(base.rules ? base.rules({ ...defaults, ...fixed, ...p }) : []),
      ({ none: 'الوقف: بلا وقف إضافي.', atr2: 'الوقف: سعر الدخول − 2 × ATR(14).', atr3: 'الوقف: سعر الدخول − 3 × ATR(14).', pct5: 'الوقف: 5% تحت سعر الدخول.', pct10: 'الوقف: 10% تحت سعر الدخول.' })[p.stop || 'none'],
      ...(p.gate && p.gate !== 'none' ? [`بوابة الدخول: ${p.gate === 'strong' ? 'SPY فوق متوسط 200 وعائد شهر موجب' : 'أكثر من 50% من الكون فوق متوسط 50'}.`] : []),
      'سقف القطاع: 30% من رأس المال كحد أقصى لكل قطاع.',
    ],
  };
}

const F = id => FAMILIES.find(f => f.family === id);
export const RISK_FAMILIES = [
  withRisk(F('mom-12-1'), { grid: { n: [10, 20], sizing: ['equal', 'vol'], stop: ['none', 'atr3', 'pct10'] } }),
  withRisk(F('hi52-momentum'), { grid: { n: [10, 20], regime: ['sma200', 'strong'], stop: ['none', 'atr3', 'pct10'] } }),
  withRisk(F('mr-ibs'), { grid: { ibs: [0.1, 0.2], down: [2, 3], stop: ['none', 'atr2', 'pct5'] }, fixed: { maxPositions: 10 } }),
  withRisk(F('mr-rsi2'), { grid: { th: [5, 10], exit: ['sma5', 'rsi70'], stop: ['none', 'atr2', 'pct5'] }, fixed: { maxPositions: 10 } }),
  withRisk(F('gap-up'), { grid: { volMult: [1.5, 3], hold: [3, 7], gate: ['none', 'strong', 'breadth'] }, fixed: { gap: 0.04 } }),
];

// الجولة 3: العائلات التي يُبنى لها مرشح «+طبقات» (هدف: أعلى CAGR داخل العينة بتراجع < 25%)
export const OVERLAY_TARGETS = ['conc-mom', 'mom-rotation', 'trend-breakout', 'sector-mom', 'mom-pullback', 'mom-12-1', 'hi52-momentum', 'core-satellite'];
export const OVERLAY_SET = 'mild';
export const OBJECTIVE_DD = 0.25; // حد التراجع داخل العينة لاختيار الطبقة/الميزانية (= شرط المالك 5)
// «أساس + قمر صناعي»: الأساس = السلة الأساسية المتوافقة، والقمر = أفضل عائلة زخم داخل العينة
export const SAT_FAMILIES = ['conc-mom', 'mom-rotation', 'trend-breakout', 'sector-mom', 'mom-12-1', 'hi52-momentum'];
export const CORE_WEIGHTS = [0.6, 0.7, 0.8];
// أكمام المزيج: زخم + ارتداد قصير، كل كم بميزانية تذبذب ثابتة والباقي نقد
export const MOM_SLEEVES = ['mom-12-1', 'hi52-momentum', 'mom-12-1+risk', 'hi52-momentum+risk'];
export const MR_SLEEVES = ['mr-ibs', 'mr-rsi2', 'mr-ibs+risk', 'mr-rsi2+risk'];
export const SLEEVE_BUDGETS = [0.02, 0.03, 0.04, 0.06]; // تذبذب سنوي مستهدف لكل كم
export const FRONTIER_DD = [0.15, 0.20, 0.25];
