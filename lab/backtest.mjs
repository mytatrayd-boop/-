// مختبر الاتجاهات — الحساب الوهمي: كل أسابيع البيانات، بنفس weeklyTrade الذي يستخدمه التطبيق.
// الاستخدام: node lab/backtest.mjs          → lab/results/backtest.json (القيم الافتراضية TREND_DEFAULTS)
//            node lab/backtest.mjs --sweep  → lab/results/sweep.json (شبكة TREND_GRID + اختبار أمامي walk-forward)
// الاستراتيجية و splitWeeks تُمرَّر كدوال (حقن) — الاختبارات تستخدم استراتيجية وهمية بدون server/trend.js.
//
// اصطلاحات الأرقام: الحقول المنتهية بـ Pct في الحساب والأسابيع (returnPct, maxDrawdownPct) بالنقاط المئوية
// (5.2 = ‎5.2%‎، والتراجع رقم موجب). pct للصفقة و avgPct للسهم كسر كما يرجعه weeklyTrade (0.052).
// winRate كسر 0..1. r و pct من الاستراتيجية (بدون انزلاق)؛ pnl ورصيد الحساب بعد الانزلاق.
import { readFile, writeFile, readdir, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, '..');
const RESULTS = path.join(HERE, 'results');

export const ACCOUNT_DEFAULTS = { start: 10000, riskPct: 0.01, maxPositions: 5, slippage: 0.0002 };
export const SWEEP_MIN_TRADES = 10; // أقل عدد صفقات داخل العينة حتى يُعتبر التركيب في الاختيار

const round = (x, d = 2) => (x === null || !Number.isFinite(x) ? null : Math.round(x * 10 ** d) / 10 ** d);
const mean = a => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);
const fin = x => typeof x === 'number' && Number.isFinite(x);

// صفقة مكتملة قابلة للتنفيذ: إشارة + خروج + أسعار منطقية
function completed(res) {
  const s = res && res.signal, x = res && res.exit;
  return !!(s && x && fin(s.entry) && fin(s.stop) && fin(x.price) && s.entry > s.stop && s.entry > 0 && fin(s.entryT) && fin(x.t));
}

/* ---------- 1) الإشارات: الاستراتيجية على كل سهم × كل أسبوع ---------- */

export function simulateSignals({ barsBySym, strategy, splitWeeks, params }) {
  const weekMap = new Map(); // weekKey → [{ sym, res }]
  const symbols = Object.keys(barsBySym);
  let errors = 0;
  for (const sym of symbols) {
    const bars = barsBySym[sym];
    if (!bars || !Array.isArray(bars.t) || !bars.t.length) continue;
    for (const week of splitWeeks(bars)) {
      let res = null;
      try { res = strategy(bars, week, params); }
      catch (e) { errors++; if (errors <= 5) console.warn(`  ${sym} ${week.weekKey}: ${e.message}`); }
      if (!weekMap.has(week.weekKey)) weekMap.set(week.weekKey, []);
      weekMap.get(week.weekKey).push({ sym, res: res || { weekKey: week.weekKey, signal: null, exit: null, r: null, pct: null } });
    }
  }
  return { weekKeys: [...weekMap.keys()].sort(), weekMap, symbols, errors };
}

/* ---------- 2) الحساب الوهمي على أسابيع محددة ---------- */

// حجم المركز: floor(خطر ÷ (دخول − وقف))، والقيمة ≤ الرصيد ÷ maxPositions وبحدود النقد المتاح، أسهم كاملة فقط
export function positionSize({ equity, cash = equity, entry, stop, riskPct, maxPositions, slippage = 0 }) {
  const perShare = entry - stop;
  if (!(perShare > 0) || !(equity > 0)) return 0;
  const fill = entry * (1 + slippage);
  const byRisk = Math.floor((equity * riskPct) / perShare + 1e-9);
  const byValue = Math.floor(Math.min(equity / maxPositions, cash) / fill + 1e-9);
  return Math.max(0, Math.min(byRisk, byValue));
}

export function runAccount({ sim, weekKeys = sim.weekKeys, account = {} }) {
  const acc = { ...ACCOUNT_DEFAULTS, ...account };
  let equity = acc.start, peak = acc.start, maxDD = 0;
  const weeks = [], trades = [];
  for (const wk of weekKeys) {
    const cands = (sim.weekMap.get(wk) || []).filter(x => completed(x.res))
      .sort((a, b) => a.res.signal.entryT - b.res.signal.entryT || (a.sym < b.sym ? -1 : a.sym > b.sym ? 1 : 0));
    const weekStart = equity;
    let realized = 0;
    const open = [], taken = [];
    for (const { sym, res } of cands) {
      const s = res.signal, x = res.exit;
      // مركز خرج في شمعة قبل شمعة الدخول هذه → يحرّر خانته ويُضاف ربحه للرصيد
      for (let k = open.length - 1; k >= 0; k--) {
        if (open[k].exitT < s.entryT) { realized += open[k].pnl; open.splice(k, 1); }
      }
      if (open.length >= acc.maxPositions) continue;
      const eqNow = weekStart + realized;
      const cash = eqNow - open.reduce((t, p) => t + p.value, 0);
      const shares = positionSize({ equity: eqNow, cash, entry: s.entry, stop: s.stop, riskPct: acc.riskPct, maxPositions: acc.maxPositions, slippage: acc.slippage });
      if (shares < 1) continue;
      const entryFill = s.entry * (1 + acc.slippage), exitFill = x.price * (1 - acc.slippage);
      const pnl = shares * (exitFill - entryFill);
      const r = fin(res.r) ? res.r : (x.price - s.entry) / (s.entry - s.stop);
      const pct = fin(res.pct) ? res.pct : x.price / s.entry - 1;
      open.push({ exitT: x.t, pnl, value: shares * entryFill });
      taken.push({ sym, weekKey: wk, entryT: s.entryT, entry: s.entry, stop: s.stop, target: fin(s.target) ? s.target : null,
        exitT: x.t, exit: x.price, how: x.how || null, r: round(r, 4), pct: round(pct, 5), shares, pnl, _r: r });
    }
    const weekPnl = taken.reduce((t, x) => t + x.pnl, 0);
    equity = weekStart + weekPnl;
    peak = Math.max(peak, equity);
    maxDD = Math.max(maxDD, (peak - equity) / peak);
    weeks.push({ weekKey: wk, trades: taken.length, wins: taken.filter(x => x.pnl > 0).length, pnl: round(weekPnl),
      equityEnd: round(equity), returnPct: round((equity / weekStart - 1) * 100, 3) });
    trades.push(...taken);
  }
  const wins = trades.filter(x => x.pnl > 0);
  const grossWin = wins.reduce((t, x) => t + x.pnl, 0);
  const grossLoss = -trades.filter(x => x.pnl < 0).reduce((t, x) => t + x.pnl, 0);
  const summary = {
    start: acc.start, end: round(equity), returnPct: round((equity / acc.start - 1) * 100, 3),
    maxDrawdownPct: round(maxDD * 100, 3), trades: trades.length,
    winRate: trades.length ? round(wins.length / trades.length, 4) : null,
    avgR: round(mean(trades.map(x => x._r)), 4),
    profitFactor: grossLoss > 0 ? round(grossWin / grossLoss, 3) : null, // null = لا خسائر (أو لا صفقات)
  };
  return { weeks, account: summary, trades: trades.map(({ _r, pnl, ...t }) => ({ ...t, pnl: round(pnl) })) };
}

/* ---------- 3) إحصاء كل سهم (على مستوى الاستراتيجية، بغض النظر عن خانات الحساب) ---------- */

export function perSymbolStats(sim, weekKeys = sim.weekKeys, symbols = sim.symbols) {
  const out = {};
  for (const sym of symbols) out[sym] = { weeks: 0, signals: 0, rs: [], pcts: [] };
  for (const wk of weekKeys) {
    for (const { sym, res } of sim.weekMap.get(wk) || []) {
      const st = out[sym] || (out[sym] = { weeks: 0, signals: 0, rs: [], pcts: [] });
      st.weeks++;
      if (res && res.signal) st.signals++;
      if (completed(res)) {
        st.rs.push(fin(res.r) ? res.r : (res.exit.price - res.signal.entry) / (res.signal.entry - res.signal.stop));
        st.pcts.push(fin(res.pct) ? res.pct : res.exit.price / res.signal.entry - 1);
      }
    }
  }
  const result = {};
  for (const [sym, st] of Object.entries(out)) {
    const n = st.rs.length, wins = st.rs.filter(r => r > 0).length;
    result[sym] = {
      weeks: st.weeks, signals: st.signals, trades: n, wins,
      winRate: n ? round(wins / n, 4) : null, avgR: round(mean(st.rs), 4),
      totalR: round(st.rs.reduce((t, r) => t + r, 0), 4), avgPct: round(mean(st.pcts), 5),
      bestR: n ? round(Math.max(...st.rs), 4) : null, worstR: n ? round(Math.min(...st.rs), 4) : null,
    };
  }
  return result;
}

/* ---------- 4) التشغيل الكامل بصيغة العقد ---------- */

export function runBacktest({ barsBySym, strategy, splitWeeks, params, account = {}, meta = {}, universe, sim }) {
  sim = sim || simulateSignals({ barsBySym, strategy, splitWeeks, params });
  const acc = runAccount({ sim, account });
  const syms = universe || Object.keys(barsBySym);
  return {
    generatedAt: new Date().toISOString(),
    source: meta.source || null, dataFrom: meta.from || null, dataTo: meta.to || null,
    params, universe: syms,
    weeks: acc.weeks, account: acc.account, trades: acc.trades,
    perSymbol: perSymbolStats(sim, sim.weekKeys, [...new Set([...syms, ...sim.symbols])]),
  };
}

/* ---------- 5) شبكة المعاملات + الاختبار الأمامي ---------- */

// { a: [1, 2], b: [x] } → [{a:1,b:x}, {a:2,b:x}]
export function gridCombos(grid) {
  let combos = [{}];
  for (const [k, vals] of Object.entries(grid || {})) {
    const list = Array.isArray(vals) && vals.length ? vals : [];
    if (!list.length) continue;
    combos = combos.flatMap(c => list.map(v => ({ ...c, [k]: v })));
  }
  return combos;
}

// الأقدم 50% (داخل العينة) / الأحدث 50% (خارجها). العدد الفردي يعطي الأسبوع الزائد للأحدث.
export function walkForwardSplit(weekKeys) {
  const sorted = [...weekKeys].sort();
  const half = Math.floor(sorted.length / 2);
  return { inSample: sorted.slice(0, half), outSample: sorted.slice(half) };
}

// الأفضل داخل العينة: أعلى عائد ثم أعلى avgR، بشرط حد أدنى للصفقات (إن لم يحققه أحد → الكل)
export function pickBest(rows, minTrades = SWEEP_MIN_TRADES) {
  const idx = rows.map((r, i) => i);
  const eligible = idx.filter(i => rows[i].trades >= minTrades);
  const pool = eligible.length ? eligible : idx;
  return pool.sort((a, b) => (rows[b].returnPct ?? -Infinity) - (rows[a].returnPct ?? -Infinity)
    || (rows[b].avgR ?? -Infinity) - (rows[a].avgR ?? -Infinity) || a - b)[0] ?? -1;
}

const brief = a => ({ trades: a.trades, winRate: a.winRate, avgR: a.avgR, returnPct: a.returnPct, maxDD: a.maxDrawdownPct });

export function runSweep({ barsBySym, strategy, splitWeeks, defaults, grid, account = {}, minTrades = SWEEP_MIN_TRADES, log = () => {} }) {
  const combos = gridCombos(grid);
  const rows = [], isRows = [], oosRows = [];
  // تقسيم الأسابيع لا يعتمد على المعاملات → يُحسب مرة لكل سهم
  const weeksCache = new Map();
  const cachedSplit = bars => { if (!weeksCache.has(bars)) weeksCache.set(bars, splitWeeks(bars)); return weeksCache.get(bars); };
  let split = null;
  const evalParams = (params) => {
    const sim = simulateSignals({ barsBySym, strategy, splitWeeks: cachedSplit, params });
    if (!split) split = walkForwardSplit(sim.weekKeys);
    return {
      all: brief(runAccount({ sim, account }).account),
      is: brief(runAccount({ sim, weekKeys: split.inSample, account }).account),
      oos: brief(runAccount({ sim, weekKeys: split.outSample, account }).account),
    };
  };
  combos.forEach((combo, i) => {
    const ev = evalParams({ ...defaults, ...combo });
    rows.push({ params: combo, ...ev.all });
    isRows.push(ev.is); oosRows.push(ev.oos);
    log(`[${i + 1}/${combos.length}] ${JSON.stringify(combo)} → ${ev.all.trades} صفقة، ${ev.all.returnPct}%`);
  });
  const def = evalParams(defaults);
  const best = pickBest(isRows, minTrades);
  const range = keys => ({ from: keys[0] || null, to: keys[keys.length - 1] || null, weeks: keys.length });
  return {
    combos: combos.length, rows,
    walkForward: {
      method: `choose by in-sample returnPct (then avgR) among combos with ≥ ${minTrades} in-sample trades; report the chosen combo on the newer half only`,
      minTrades,
      inSample: range(split ? split.inSample : []), outSample: range(split ? split.outSample : []),
      chosen: best >= 0 ? { params: combos[best], inSample: isRows[best], outSample: oosRows[best] } : null,
      defaults: { inSample: def.is, outSample: def.oos },
    },
  };
}

/* ---------- التشغيل كسكربت ---------- */

async function readJson(file) {
  try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; }
}

async function loadTrend() {
  const file = path.join(ROOT, 'server', 'trend.js');
  try { return await import(pathToFileURL(file).href); }
  catch (e) {
    if (e.code === 'ERR_MODULE_NOT_FOUND' && String(e.message).includes('trend.js')) {
      console.error('server/trend.js غير موجود بعد (يكتبه مطور الاتجاهات). لا يمكن تشغيل الاختبار الخلفي بدونه.');
    } else console.error('تعذّر تحميل server/trend.js: ' + e.message);
    process.exit(1);
  }
}

async function loadData() {
  const meta = (await readJson(path.join(HERE, 'data', 'meta.json'))) || {};
  const universe = (await readJson(path.join(HERE, 'universe.json')))?.symbols || [];
  const dir = path.join(HERE, 'data', '5m');
  let files = [];
  try { files = (await readdir(dir)).filter(f => f.endsWith('.json')); } catch { /* لا بيانات */ }
  // meta.symbols = ما نزّله آخر تشغيل من نفس المصدر (يتجاهل ملفات قديمة من مصدر آخر)
  const allowed = meta.symbols ? new Set(Object.keys(meta.symbols)) : null;
  const barsBySym = {};
  for (const f of files.sort()) {
    const sym = f.slice(0, -5);
    if (allowed && !allowed.has(sym)) continue;
    const b = await readJson(path.join(dir, f));
    if (b && Array.isArray(b.t) && b.t.length) barsBySym[sym] = b;
  }
  const order = [...universe, ...Object.keys(barsBySym).filter(s => !universe.includes(s))];
  return { meta, barsBySym, universe: order };
}

async function main() {
  const sweep = process.argv.includes('--sweep');
  const trend = await loadTrend();
  const { weeklyTrade, splitWeeks, TREND_DEFAULTS, TREND_GRID } = trend;
  if (typeof weeklyTrade !== 'function' || typeof splitWeeks !== 'function') {
    console.error('server/trend.js لا يصدّر weeklyTrade و splitWeeks.'); process.exit(1);
  }
  const { meta, barsBySym, universe } = await loadData();
  const n = Object.keys(barsBySym).length;
  if (!n) { console.error('لا توجد بيانات في lab/data/5m — شغّل node lab/fetch.mjs أولًا.'); process.exit(1); }
  await mkdir(RESULTS, { recursive: true });
  console.log(`البيانات: ${meta.source || '?'} ${meta.from || ''} → ${meta.to || ''}، ${n} سهم`);

  if (sweep) {
    if (!TREND_GRID || typeof TREND_GRID !== 'object' || !gridCombos(TREND_GRID).length) {
      console.log('server/trend.js لا يصدّر TREND_GRID — لا شبكة للتجربة.'); return;
    }
    const t0 = Date.now();
    const res = runSweep({ barsBySym, strategy: weeklyTrade, splitWeeks, defaults: TREND_DEFAULTS, grid: TREND_GRID, log: console.log });
    const out = { generatedAt: new Date().toISOString(), source: meta.source || null, dataFrom: meta.from || null, dataTo: meta.to || null,
      defaults: TREND_DEFAULTS, grid: TREND_GRID, ...res };
    await writeFile(path.join(RESULTS, 'sweep.json'), JSON.stringify(out, null, 2) + '\n');
    const wf = res.walkForward;
    console.log(`\nالشبكة: ${res.combos} تركيب في ${Math.round((Date.now() - t0) / 1000)} ث`);
    if (wf.chosen) {
      console.log(`المختار على الأقدم (${wf.inSample.from}→${wf.inSample.to}): ${JSON.stringify(wf.chosen.params)}`);
      console.log(`  داخل العينة: ${JSON.stringify(wf.chosen.inSample)}`);
      console.log(`  خارج العينة (${wf.outSample.from}→${wf.outSample.to}): ${JSON.stringify(wf.chosen.outSample)}`);
      console.log(`  الافتراضي خارج العينة: ${JSON.stringify(wf.defaults.outSample)}`);
    }
    console.log('→ lab/results/sweep.json (الافتراضي يبقى هو التشغيل الأساسي)');
    return;
  }

  const sim = simulateSignals({ barsBySym, strategy: weeklyTrade, splitWeeks, params: TREND_DEFAULTS });
  if (sim.errors) console.warn(`تحذير: ${sim.errors} خطأ من الاستراتيجية (اعتُبرت بلا إشارة).`);
  const result = runBacktest({ barsBySym, strategy: weeklyTrade, splitWeeks, params: TREND_DEFAULTS, meta, universe, sim });
  await writeFile(path.join(RESULTS, 'backtest.json'), JSON.stringify(result, null, 2) + '\n');
  const a = result.account;
  console.log(`أسابيع: ${result.weeks.length}، صفقات: ${a.trades}، فوز: ${a.winRate === null ? '-' : Math.round(a.winRate * 100) + '%'}، متوسط R: ${a.avgR ?? '-'}`);
  console.log(`الحساب: ${a.start} → ${a.end} (${a.returnPct}%)، أقصى تراجع ${a.maxDrawdownPct}%، معامل الربح ${a.profitFactor ?? '-'}`);
  console.log('→ lab/results/backtest.json');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(e => { console.error(e); process.exit(1); });
}
