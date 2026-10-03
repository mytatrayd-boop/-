// مفلتر النتائج — يرتّب الأسهم حسب استجابتها التاريخية لاختراق خط الاتجاه الهابط (أسبوعي، شراء فقط).
// يقرأ lab/results/backtest.json ويكتب lab/results/top5.json (المخطط في lab/CONTRACT.md).
// دوال نقية + تشغيل كسكربت: node lab/rank.mjs [--min-trades=4] [--prior=6]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// ===== الإعدادات =====
// الأوزان (مجموعها 1). كل مكوّن مُطبَّع إلى 0..1 ثم score = 100 × Σ(وزن × مكوّن).
export const WEIGHTS = {
  expectancy: 0.40,   // متوسط R المنكمش ناقص نصف الخطأ المعياري، مُطبَّع: −1R→0 ، +1R→1
  winRate: 0.25,      // نسبة الربح المنكمشة نحو متوسط الكون
  posWeeks: 0.15,     // حصة الأسابيع (التي فيها صفقة) بصفقة رابحة، منكمشة
  stability: 0.10,    // 1/(1+σR) حيث σR منكمش نحو σ الكون — أقل تذبذبًا = أفضل
  frequency: 0.10,    // كم مرة يظهر الإعداد: إشارات/أسبوع (حدّها 1 لأن صفقة واحدة أسبوعيًا)
};

// أقل عدد صفقات للمختارين في النصف الأحدث قبل ما نقول «صمد» أو «لم يصمد»
export const OOS_MIN_TRADES = 5;

export const RANK_DEFAULTS = {
  minTrades: 4,        // أقل عدد صفقات ليدخل السهم الترتيب
  prior: 6,            // k: وزن المتوسط المسبق (بعدد صفقات وهمية) في (n·x + k·μ)/(n + k)
  seWeight: 0.5,       // كم نطرح من الخطأ المعياري من متوسط R (عقوبة إضافية للعينة الصغيرة)
  topN: 5,
  oosMinTrades: null,  // حد الصفقات في النصف الأقدم؛ null = max(2, ceil(minTrades/2))
  requirePositive: true, // لازم متوسط R المنكمش > 0 — سهم خسران ما يدخل أفضل 5 حتى لو تكرر كثير
};

// ===== أدوات =====
const isNum = (x) => typeof x === 'number' && Number.isFinite(x);
const clamp01 = (x) => Math.max(0, Math.min(1, x));
const mean = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : 0);
function stdev(a) {
  if (a.length < 2) return 0;
  const m = mean(a);
  return Math.sqrt(a.reduce((s, x) => s + (x - m) ** 2, 0) / (a.length - 1));
}
export const shrink = (n, x, k, mu) => (n + k > 0 ? (n * x + k * mu) / (n + k) : mu);
const round = (x, d = 4) => (isNum(x) ? Math.round(x * 10 ** d) / 10 ** d : 0);

// قائمة الأسابيع مرتبة زمنيًا (من weeks ثم من الصفقات احتياطًا)
export function weekKeys(bt) {
  const s = new Set();
  for (const w of bt.weeks || []) if (w && w.weekKey) s.add(w.weekKey);
  for (const t of bt.trades || []) if (t && t.weekKey) s.add(t.weekKey);
  return [...s].sort();
}

// كل الرموز: الكون + perSymbol + من تداول فعلًا
export function allSymbols(bt) {
  const s = new Set([...(bt.universe || []), ...Object.keys(bt.perSymbol || {})]);
  for (const t of bt.trades || []) if (t && t.sym) s.add(t.sym);
  return [...s].sort();
}

// إحصاءات الكون (موزونة بالصفقات) لاستخدامها كمسبق في الانكماش
export function universeStats(trades) {
  const rs = trades.map((t) => t.r);
  const wins = rs.filter((r) => r > 0).length;
  return { trades: rs.length, avgR: mean(rs), winRate: rs.length ? wins / rs.length : 0, sdR: stdev(rs) };
}

// إحصاءات سهم واحد من صفقاته
export function symbolStats(trades) {
  const rs = trades.map((t) => t.r);
  const byWeek = new Map();
  for (const t of trades) byWeek.set(t.weekKey, (byWeek.get(t.weekKey) || false) || t.r > 0);
  const posWeeks = [...byWeek.values()].filter(Boolean).length;
  return {
    trades: rs.length,
    wins: rs.filter((r) => r > 0).length,
    avgR: mean(rs),
    totalR: rs.reduce((s, x) => s + x, 0),
    sdR: stdev(rs),
    weeksTraded: byWeek.size,
    posWeeks,
  };
}

// الدرجة: كل الأجزاء منكمشة نحو الكون، فالصفقة المحظوظة الواحدة لا تكفي للصدارة
export function scoreSymbol(st, uni, freq, opt = RANK_DEFAULTS) {
  const k = opt.prior ?? RANK_DEFAULTS.prior, n = st.trades;
  const winRate = n ? st.wins / n : 0;
  const sAvgR = shrink(n, st.avgR, k, uni.avgR);
  const sWin = shrink(n, winRate, k, uni.winRate);
  const sPos = shrink(st.weeksTraded, st.weeksTraded ? st.posWeeks / st.weeksTraded : 0, k, uni.winRate);
  const sSd = shrink(n >= 2 ? n : 0, st.sdR, k, uni.sdR);
  const se = sSd / Math.sqrt(Math.max(n, 1));
  const lcbR = sAvgR - (opt.seWeight ?? RANK_DEFAULTS.seWeight) * se;
  const parts = {
    expectancy: clamp01(0.5 + lcbR / 2),
    winRate: clamp01(sWin),
    posWeeks: clamp01(sPos),
    stability: 1 / (1 + sSd),
    frequency: clamp01(isNum(freq) ? freq : 0),
  };
  let score = 0;
  for (const key of Object.keys(WEIGHTS)) score += WEIGHTS[key] * parts[key];
  return { score: 100 * score, shrunkAvgR: sAvgR, shrunkWinRate: sWin, lcbR, parts };
}

// ترتيب حتمي: الدرجة ↓ ثم متوسط R المنكمش ↓ ثم عدد الصفقات ↓ ثم الرمز أبجديًا
export function compareRows(a, b) {
  if (a.eligible !== b.eligible) return a.eligible ? -1 : 1;
  const d = b.score - a.score;
  if (Math.abs(d) > 1e-9) return d;
  const d2 = b.shrunkAvgR - a.shrunkAvgR;
  if (Math.abs(d2) > 1e-12) return d2;
  if (b.trades !== a.trades) return b.trades - a.trades;
  return a.sym < b.sym ? -1 : a.sym > b.sym ? 1 : 0;
}

const sgn = (x) => (x >= 0 ? '+' : '-') + Math.abs(x).toFixed(2);
export function whyText(row) {
  return `${row.trades} صفقات، متوسط ${sgn(row.avgR)}R، ربحت ${row.posWeeks} أسابيع من ${row.weeksTraded}`;
}

// يرتّب كل الرموز على مجموعة أسابيع محددة (null = كل الأسابيع)
// signalsPerWeek من perSymbol يُستعمل فقط عند الترتيب على كل البيانات، حتى لا يتسرّب النصف الأحدث.
export function rankSymbols(bt, opts = {}) {
  const opt = { ...RANK_DEFAULTS, ...opts };
  const keys = opts.weeks ? new Set(opts.weeks) : null;
  const nWeeks = keys ? keys.size : weekKeys(bt).length;
  const trades = (bt.trades || []).filter((t) => t && t.sym && isNum(t.r) && (!keys || keys.has(t.weekKey)));
  const uni = universeStats(trades);
  const bySym = new Map(allSymbols(bt).map((s) => [s, []]));
  for (const t of trades) bySym.get(t.sym).push(t);

  const rows = [];
  for (const [sym, list] of bySym) {
    const st = symbolStats(list);
    const ps = (bt.perSymbol || {})[sym];
    let freq = nWeeks ? st.weeksTraded / nWeeks : 0;
    if (!keys && ps && isNum(ps.signals) && isNum(ps.weeks) && ps.weeks > 0) freq = ps.signals / ps.weeks;
    const sc = scoreSymbol(st, uni, freq, opt);
    const row = {
      sym,
      score: sc.score,
      eligible: st.trades >= opt.minTrades && (!opt.requirePositive || sc.shrunkAvgR > 0),
      trades: st.trades,
      wins: st.wins,
      winRate: st.trades ? st.wins / st.trades : 0,
      avgR: st.avgR,
      totalR: st.totalR,
      sdR: st.sdR,
      weeksTraded: st.weeksTraded,
      posWeeks: st.posWeeks,
      signalsPerWeek: freq,
      shrunkAvgR: sc.shrunkAvgR,
      shrunkWinRate: sc.shrunkWinRate,
    };
    rows.push(row);
  }
  rows.sort(compareRows);
  return { rows, universe: uni, weeks: nWeeks };
}

// إحصاء بسيط لمجموعة صفقات (للنصف الأحدث)
function simple(trades) {
  const rs = trades.map((t) => t.r);
  return {
    trades: rs.length,
    avgR: round(mean(rs)),
    winRate: round(rs.length ? rs.filter((r) => r > 0).length / rs.length : 0),
  };
}

// فحص خارج العينة: رتّب على النصف الأقدم فقط، ثم قِس أداء المختارين في النصف الأحدث
export function oosCheck(bt, opts = {}) {
  const opt = { ...RANK_DEFAULTS, ...opts };
  const all = weekKeys(bt);
  if (all.length < 2) {
    return { available: false, olderWeeks: all.length, newerWeeks: 0, picks: [], note: 'عدد الأسابيع أقل من 2 — لا يمكن فحص خارج العينة.' };
  }
  const half = Math.floor(all.length / 2);
  const older = all.slice(0, half), newer = all.slice(half);
  const minT = opt.oosMinTrades ?? Math.max(2, Math.ceil(opt.minTrades / 2));
  const ranked = rankSymbols(bt, { ...opt, minTrades: minT, weeks: older });
  const picks = ranked.rows.filter((r) => r.eligible).slice(0, opt.topN);
  const newSet = new Set(newer);
  const newerTrades = (bt.trades || []).filter((t) => t && isNum(t.r) && newSet.has(t.weekKey));
  const pickSet = new Set(picks.map((p) => p.sym));
  const pickRes = picks.map((p, i) => ({
    sym: p.sym, olderRank: i + 1, olderScore: round(p.score, 2), olderTrades: p.trades, olderAvgR: round(p.avgR),
    ...simple(newerTrades.filter((t) => t.sym === p.sym)),
  }));
  const pAll = simple(newerTrades.filter((t) => pickSet.has(t.sym)));
  const uAll = simple(newerTrades);
  // heldUp = تفوّق على الكون وبقي رابحًا؛ beatUniverse = تفوّق فقط
  let heldUp = null, beatUniverse = null, note;
  if (!picks.length) note = 'لا يوجد سهم مؤهَّل في النصف الأقدم.';
  else if (!pAll.trades) note = 'المختارون من النصف الأقدم لم يتداولوا في النصف الأحدث.';
  // أقل من OOS_MIN_TRADES صفقة = ما نحكم (صفقة وحدة محظوظة ما تثبت شي)
  else if (pAll.trades < OOS_MIN_TRADES) note = `العينة غير كافية للحكم: ${pAll.trades} صفقة فقط للمختارين في النصف الأحدث (نحتاج ${OOS_MIN_TRADES} على الأقل).`;
  else {
    beatUniverse = pAll.avgR > uAll.avgR;
    heldUp = beatUniverse && pAll.avgR > 0;
    const cmp = `متوسط المختارين ${sgn(pAll.avgR)}R مقابل ${sgn(uAll.avgR)}R للكون في النصف الأحدث`;
    note = heldUp ? `صمد الاختيار: ${cmp}.`
      : beatUniverse ? `صمد جزئيًا: تفوّق على الكون لكنه بقي خاسرًا (${cmp}).`
        : `لم يصمد الاختيار: ${cmp}.`;
  }
  return {
    available: true,
    olderWeeks: older.length, newerWeeks: newer.length,
    olderFrom: older[0], olderTo: older[older.length - 1], newerFrom: newer[0], newerTo: newer[newer.length - 1],
    minTrades: minT,
    picks: pickRes,
    picksNewer: pAll,
    universeNewer: uAll,
    heldUp,
    beatUniverse,
    note,
    newerTradesBySym: Object.fromEntries(
      [...new Set(newerTrades.map((t) => t.sym))].sort().map((s) => [s, simple(newerTrades.filter((t) => t.sym === s))])),
  };
}

// يبني top5.json كاملًا
export function buildTop5(bt, opts = {}, now = new Date()) {
  const opt = { ...RANK_DEFAULTS, ...opts };
  const { rows, universe, weeks } = rankSymbols(bt, opt);
  const oos = oosCheck(bt, opt);
  const bySymNewer = oos.newerTradesBySym || {};
  const olderPicks = new Set((oos.picks || []).map((p) => p.sym));
  delete oos.newerTradesBySym;

  const pub = (r) => ({
    sym: r.sym, score: round(r.score, 2), eligible: r.eligible, trades: r.trades, wins: r.wins,
    winRate: round(r.winRate), avgR: round(r.avgR), totalR: round(r.totalR), sdR: round(r.sdR),
    weeksTraded: r.weeksTraded, posWeeks: r.posWeeks, signalsPerWeek: round(r.signalsPerWeek),
    shrunkAvgR: round(r.shrunkAvgR), shrunkWinRate: round(r.shrunkWinRate),
  });
  const eligible = rows.filter((r) => r.eligible);
  const top = eligible.slice(0, opt.topN).map((r) => ({
    ...pub(r),
    oos: { trades: 0, avgR: 0, winRate: 0, ...(bySymNewer[r.sym] || {}), pickedOnOlderHalf: olderPicks.has(r.sym) },
    why: whyText(r),
  }));

  const w = Object.entries(WEIGHTS).map(([k, v]) => `${k} ${v}`).join('، ');
  let method = `درجة 0..100 = Σ وزن×مكوّن (${w}). متوسط R ونسبة الربح والأسابيع الرابحة وσ منكمشة نحو متوسط الكون `
    + `بالصيغة (n·x + k·μ)/(n + k) مع k=${opt.prior}، ومن متوسط R يُطرح ${opt.seWeight}×الخطأ المعياري. `
    + `الحد الأدنى ${opt.minTrades} صفقات. التعادل: متوسط R المنكمش ثم عدد الصفقات ثم الرمز. `
    + `فحص خارج العينة: ترتيب على النصف الأقدم من الأسابيع (حد ${oos.minTrades ?? '-'} صفقات) وقياس النصف الأحدث.`;
  if (eligible.length < opt.topN) method += ` تنبيه: المؤهَّل ${eligible.length} فقط من ${opt.topN}.`;

  return {
    generatedAt: now.toISOString(),
    method,
    minTrades: opt.minTrades,
    prior: opt.prior,
    weights: WEIGHTS,
    eligibleCount: eligible.length,
    universeStats: { trades: universe.trades, avgR: round(universe.avgR), winRate: round(universe.winRate), sdR: round(universe.sdR), weeks },
    top,
    oosSummary: oos,
    all: rows.map(pub),
  };
}

// ===== التشغيل كسكربت =====
function parseArgs(argv) {
  const o = {};
  for (const a of argv) {
    const m = /^--(min-trades|prior|top)=(\d+(?:\.\d+)?)$/.exec(a);
    if (m) o[{ 'min-trades': 'minTrades', prior: 'prior', top: 'topN' }[m[1]]] = Number(m[2]);
  }
  return o;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const dir = join(dirname(fileURLToPath(import.meta.url)), 'results');
  const bt = JSON.parse(readFileSync(join(dir, 'backtest.json'), 'utf8'));
  const out = buildTop5(bt, parseArgs(process.argv.slice(2)));
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'top5.json'), JSON.stringify(out, null, 2) + '\n');
  console.log(`top5: ${out.top.map((t) => `${t.sym} ${t.score}`).join(' | ') || '—'} (مؤهَّل ${out.eligibleCount})`);
  if (out.oosSummary.note) console.log(out.oosSummary.note);
}
