// تشغيل البحث كاملاً: كل عائلة × شبكتها الصغيرة → اختبار أمامي سنوي (نافذة متوسعة) → مقاييس خارج العينة
// مقابل SPY على نفس الأيام → فحص الشروط السبعة آليًا → lab/results/research.json و RESEARCH_REPORT.md (عربي).
// الجولة 2: طبقات مخاطر (استهداف تذبذب، فلتر سوق أقوى، قاطع تراجع، وقف لكل مركز، سقف قطاع)، أكمام بميزانية مخاطر،
// حدود الكفاءة (أفضل CAGR خارج العينة بتراجع < 10/15/20% مُختار داخل العينة)، وفترات التراجع.
// الاستخدام: node lab/research/run.mjs                 (بيانات lab/data/research من data.mjs)
//            node lab/research/run.mjs --synthetic[=1500x2500] [--out=DIR]   (قياس السرعة/تجربة بلا شبكة)
import { writeFile, mkdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { buildPanel, runStrategy, fullMetrics, returnStats, ENGINE_DEFAULTS, streamFromRun, combineStreams, applyOverlay,
  makeFolds, wfSelectMulti, drawdownEpisodes } from './engine.mjs';
import { FAMILIES, gridCombos } from './strategies/index.mjs';
import { RISK_FAMILIES, overlaySpecs, OVERLAY_TARGETS, MOM_SLEEVES, MR_SLEEVES, SLEEVE_BUDGETS, FRONTIER_DD } from './overlays.mjs';
import { loadResearchData } from './data.mjs';
import { synthUniverse } from './synth.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const RESULTS = path.join(HERE, '..', 'results');
export const CRITERIA = {
  minDataYears: 9.5, minTrades: 100, minOosYears: 3, maxDD: 0.10,
};
const r4 = x => (x === null || x === undefined ? null : !Number.isFinite(x) ? (x > 0 ? 'Infinity' : x < 0 ? '-Infinity' : null) : Math.round(x * 1e4) / 1e4);
const pct = (x, d = 1) => (x === null || x === undefined || !Number.isFinite(Number(x)) ? '—' : (Number(x) * 100).toFixed(d) + '%');
const num = (x, d = 2) => (x === null || x === undefined ? '—' : x === 'Infinity' || x === Infinity ? '∞' : Number.isFinite(Number(x)) ? Number(x).toFixed(d) : '—');
const fmtDay = (P, d) => new Date(P.dates[d]).toISOString().slice(0, 10);

/* ---------- الشروط السبعة ---------- */
// c: { dataYears, folds, oos: {...fullMetrics}, shariah: {ok, why} } → { passed, score, checks: [{id, label, ok, value, why}] }
export function checkCriteria(c, k = CRITERIA) {
  const o = c.oos || {}, b = o.bench || {};
  const checks = [
    { id: 1, label: 'نحو 10 سنوات بيانات', ok: c.dataYears >= k.minDataYears, value: r4(c.dataYears),
      why: `${num(c.dataYears, 1)} سنة (المطلوب ≥ ${k.minDataYears})` },
    { id: 2, label: '≥ 100 صفقة', ok: o.trades >= k.minTrades, value: o.trades ?? 0, why: `${o.trades ?? 0} صفقة خارج العينة` },
    { id: 3, label: 'رابحة خارج العينة (اختبار أمامي)', ok: (c.folds || 0) >= k.minOosYears && o.ret > 0, value: r4(o.ret),
      why: `${c.folds || 0} سنوات خارج العينة، العائد ${pct(o.ret)}` },
    { id: 4, label: 'تتفوق على SPY بعد التكاليف', ok: Number.isFinite(b.ret) && o.ret > b.ret, value: r4((o.ret ?? 0) - (b.ret ?? 0)),
      why: `${pct(o.ret)} مقابل SPY ${pct(b.ret)} (CAGR ${pct(o.cagr)} مقابل ${pct(b.cagr)})` },
    { id: 5, label: 'أقصى تراجع < 10%', ok: Number.isFinite(o.maxDD) && o.maxDD < k.maxDD, value: r4(o.maxDD), why: `أقصى تراجع ${pct(o.maxDD)}` },
    { id: 6, label: 'لا تعتمد على صفقتين + رابحة أغلب السنوات', ok: o.best2Removed >= 0 && o.yearsProfitable > (o.yearsTotal || 0) / 2,
      value: r4(o.best2Removed), why: `بعد حذف أفضل صفقتين ${pct(o.best2Removed)}، سنوات رابحة ${o.yearsProfitable ?? 0}/${o.yearsTotal ?? 0}` },
    { id: 7, label: 'شراء فقط ومتوافقة شرعيًا في الشكل', ok: !!(c.shariah && c.shariah.ok) && !(o.maxGross > 1 + 1e-9),
      value: r4(o.maxGross), why: `${c.shariah ? c.shariah.why : '—'}؛ أقصى تعرض ${pct(o.maxGross, 0)} بلا رافعة ولا بيع على المكشوف` },
  ];
  const score = checks.filter(x => x.ok).length;
  return { passed: score === checks.length, score, checks };
}

/* ---------- أدوات ---------- */
function benchRets(P, days) {
  const s = P.sym('SPY'); if (s < 0) return null;
  return days.map(d => { const a = P.c[s][d - 1], b = P.c[s][d]; return a > 0 && b > 0 ? b / a - 1 : 0; });
}

function sampleEquity(P, days, rets, bench, every = 5) {
  const out = []; let e = 1, b = 1;
  for (let i = 0; i < days.length; i++) {
    e *= 1 + rets[i]; if (bench) b *= 1 + bench[i];
    if (i % every === 0 || i === days.length - 1) out.push([fmtDay(P, days[i]), r4(e), bench ? r4(b) : null]);
  }
  return out;
}

function corr(a, b) {
  const n = a.length; let ma = 0, mb = 0; for (let i = 0; i < n; i++) { ma += a[i]; mb += b[i]; } ma /= n; mb /= n;
  let sab = 0, sa = 0, sb = 0; for (let i = 0; i < n; i++) { const x = a[i] - ma, y = b[i] - mb; sab += x * y; sa += x * x; sb += y * y; }
  return sa > 0 && sb > 0 ? sab / Math.sqrt(sa * sb) : 0;
}
const isSlice = (st, ctx, f) => Array.prototype.slice.call(st.rets, ctx.start + 1, f.from);
const annVol = a => { const n = a.length; if (n < 2) return 0; const m = a.reduce((x, y) => x + y, 0) / n; return Math.sqrt(a.reduce((x, y) => x + (y - m) ** 2, 0) / (n - 1) * 252); };
const cashStream = D => ({ rets: new Float64Array(D), gross: new Float64Array(D), turn: new Float64Array(D), trades: [], start: 0 });

function summarize(P, ctx, { id, name, universe, grid, combos, wf, paramsOf, shariah, extra = {} }) {
  const bench = benchRets(P, wf.days);
  const m = fullMetrics({ rets: wf.rets, years: wf.years, trades: wf.trades, gross: wf.gross, turn: wf.turn, bench });
  const folds = wf.folds.map((f, j) => ({ year: f.year, params: paramsOf(f, j), isScore: r4(f.isScore), isTrades: f.isTrades, isDD: r4(f.isDD), isCagr: r4(f.isCagr) }));
  const oos = {
    from: wf.days.length ? fmtDay(P, wf.days[0]) : null,
    to: wf.days.length ? fmtDay(P, wf.days[wf.days.length - 1]) : null,
    ...Object.fromEntries(Object.entries(m).filter(([k]) => !['yearly', 'bench'].includes(k)).map(([k, v]) => [k, typeof v === 'number' ? r4(v) : v])),
    yearly: Object.fromEntries(Object.entries(m.yearly).map(([y, v]) => [y, r4(v)])),
    bench: m.bench ? { ret: r4(m.bench.ret), cagr: r4(m.bench.cagr), sharpe: r4(m.bench.sharpe), maxDD: r4(m.bench.maxDD), mar: r4(m.bench.mar),
      yearly: Object.fromEntries(Object.entries(m.bench.yearly).map(([y, v]) => [y, r4(v)])) } : null,
  };
  const criteria = checkCriteria({ dataYears: ctx.dataYears, folds: wf.folds.length, oos: m, shariah });
  const lastTrades = wf.trades.slice(-10).map(t => ({ sym: t.sym, entry: fmtDay(P, t.entryIdx), exit: fmtDay(P, t.exitIdx), ret: r4(t.ret), how: t.how }));
  const episodes = drawdownEpisodes(wf.rets, wf.days).slice(0, 5).map(e => ({ start: fmtDay(P, e.start), trough: fmtDay(P, e.trough),
    recovery: e.recovery === null ? null : fmtDay(P, e.recovery), depth: r4(e.depth) }));
  return { id, name, universe, grid, combos, folds, oos, criteria, episodes, equity: sampleEquity(P, wf.days, wf.rets, bench), lastTrades, ...extra };
}

function shariahFor(universe, ctx) {
  if (universe === 'etf') return { ok: false, why: 'صندوق مؤشر (SPY/QQQ) يحوي شركات غير متوافقة؛ البديل المتوافق (SPUS/HLAL) تاريخه أقصر من 10 سنوات' };
  return { ok: true, why: ctx.screen };
}

/* ---------- تقييم عائلة (المرحلة 1: أعلى MAR داخل العينة) ---------- */
export function evaluateFamily(P, fam, ctx, log = () => {}) {
  const combos = gridCombos(fam.grid);
  const streams = combos.map(p => { const st = streamFromRun(runStrategy(P, fam.make(p))); st.label = p; return st; });
  const wf = wfSelectMulti(ctx.folds, () => streams, ['mar'], { start: ctx.start, years: P.years })[0];
  const res = summarize(P, ctx, { id: fam.family, name: fam.name, universe: fam.universe, grid: fam.grid, combos: combos.length, wf,
    paramsOf: f => combos[f.chosen], shariah: shariahFor(fam.universe, ctx) });
  // للمعلومة فقط (داخل العينة بالكامل، متفائل): أفضل تركيبة على كل الفترة
  const full = streams.map((st, k) => ({ k, st: returnStats(Array.prototype.slice.call(st.rets, ctx.start + 1)), n: st.trades.length })).sort((a, b) => b.st.mar - a.st.mar)[0];
  res.bestFullPeriod = { params: combos[full.k], cagr: r4(full.st.cagr), maxDD: r4(full.st.maxDD), mar: r4(full.st.mar), trades: full.n, note: 'داخل العينة — للمقارنة فقط' };
  log(`${fam.family}: ${combos.length} تركيبة، OOS ${pct(res.oos.ret)} MAR ${num(res.oos.mar)} DD ${pct(res.oos.maxDD)} صفقات ${res.oos.trades} — ${res.criteria.score}/7`);
  // التركيبة المختارة لكل سنة (تُبنى عليها الطبقات والمزائج)
  return { id: fam.family, name: fam.name, universe: fam.universe, res, combos, wf, baseFor: j => streams[wf.folds[j].chosen], paramsFor: j => combos[wf.folds[j].chosen] };
}

/* ---------- المزيج (ensemble) ---------- */
// لكل سنة: عائلات الأسهم بأعلى MAR داخل العينة (موجب) وارتباط عوائد داخل العينة < 0.5، حتى 3، بالتساوي.
function ensembleMembers(fams, ctx, j, { maxMembers = 3, maxCorr = 0.5 } = {}) {
  const f = ctx.folds[j];
  const cand = fams.filter(x => x.universe !== 'etf').map(x => ({ x, fold: x.wf.folds[j] })).filter(o => o.fold && o.fold.isScore > 0).sort((a, b) => b.fold.isScore - a.fold.isScore);
  const picked = [];
  for (const o of cand) {
    if (picked.length >= maxMembers) break;
    const st = o.x.baseFor(j), isR = isSlice(st, ctx, f);
    if (picked.every(p => corr(p.isR, isR) < maxCorr)) picked.push({ ...o, st, isR });
  }
  return picked;
}

/* ---------- الطبقات + حدود الكفاءة ---------- */
// base(j) → stream الأساس لتلك السنة؛ الخيارات = 12 طبقة ثابتة. نختار داخل العينة بأعلى CAGR بشرط تراجع < T.
function overlayWF(P, ctx, specs, baseFor) {
  const options = (f, j) => { const b = baseFor(j); return specs.map(o => Object.assign(applyOverlay(b, o.spec, { regimeFn: o.regimeFn }), { label: o.id })); };
  return wfSelectMulti(ctx.folds, options, FRONTIER_DD.map(T => ({ maxDD: T })), { start: ctx.start, years: P.years });
}

function frontierRow(P, id, name, wfs) {
  return { id, name, rows: wfs.map((wf, q) => {
    const st = returnStats(wf.rets), b = returnStats(benchRets(P, wf.days) || []);
    return { maxDD: FRONTIER_DD[q], cagr: r4(st.cagr), oosDD: r4(st.maxDD), ret: r4(st.ret), sharpe: r4(st.sharpe), benchCagr: r4(b.cagr),
      beatsSpy: st.cagr > b.cagr, meetsDD: st.maxDD < FRONTIER_DD[q], choices: wf.folds.map(f => `${f.year}:${typeof f.label === 'string' ? f.label : JSON.stringify(f.label)}`) };
  }) };
}

/* ---------- أكمام بميزانية مخاطر ---------- */
// كل كم وزنه = min(maxW, ميزانية التذبذب ÷ تذبذبه داخل العينة)، والباقي نقد (0%). الميزانية تُختار داخل العينة.
function budgetOptions(members, ctx, f, maxW) {
  if (!members.length) return [Object.assign(cashStream(ctx.D), { label: 'cash' })];
  return SLEEVE_BUDGETS.map(b => {
    const parts = members.map(m => { const v = annVol(isSlice(m.st, ctx, f)); return { stream: m.st, w: Math.min(maxW, v > 0 ? b / v : maxW) }; });
    return Object.assign(combineStreams(parts), { label: `b${b * 100}%: ` + members.map((m, i) => `${m.id}×${parts[i].w.toFixed(2)}`).join(' + ') });
  });
}

/* ---------- التقرير العربي ---------- */
export function buildReport(out) {
  const L = [];
  const cands = out.candidates;
  L.push('# تقرير البحث — استراتيجيات مضاربة (شراء فقط) على الأسهم الأمريكية', '');
  L.push(`> أُنشئ: ${out.generatedAt} — المصدر: ${out.data.source} — البيانات من ${out.data.from} إلى ${out.data.to} (${num(out.data.years, 1)} سنة)، ${out.data.symbols} سهمًا (large ${out.data.large}، small ${out.data.small}) + SPY/QQQ/IWM. الجولة ${out.round}.`, '');
  L.push('## الحكم', '', out.verdict, '');
  if (out.tradeoff) L.push(out.tradeoff, '');
  L.push('## ملخص كل المرشحين (مرتبة بـ MAR خارج العينة)', '');
  L.push('| # | الاستراتيجية | خارج العينة | العائد | CAGR | SPY CAGR | شارب | أقصى تراجع | MAR | صفقات | سنوات رابحة | بعد حذف أفضل صفقتين | الشروط |');
  L.push('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  cands.forEach((c, i) => {
    const o = c.oos;
    L.push(`| ${i + 1} | ${c.name} (\`${c.id}\`) | ${o.from ?? '—'} → ${o.to ?? '—'} | ${pct(o.ret)} | ${pct(o.cagr)} | ${pct(o.bench && o.bench.cagr)} | ${num(o.sharpe)} | ${pct(o.maxDD)} | ${num(o.mar)} | ${o.trades} | ${o.yearsProfitable}/${o.yearsTotal} | ${pct(o.best2Removed)} | ${c.criteria.score}/7${c.criteria.passed ? ' ✅' : ''} |`);
  });
  L.push('');
  if (out.frontier && out.frontier.length) {
    L.push('## حدود الكفاءة: أفضل CAGR خارج العينة مع حد للتراجع (الاختيار داخل العينة فقط)', '');
    L.push('لكل سنة نختار الطبقة (من 12) أو ميزانية الأكمام بأعلى CAGR داخل العينة بشرط أن يبقى تراجعها داخل العينة تحت الحد، ثم نقيس السنة التالية. الخانة: CAGR / أقصى تراجع خارج العينة. ✅ = التراجع خارج العينة تحت الحد **و** CAGR > SPY؛ ⚠️ = تجاوز الحد خارج العينة.', '');
    L.push(`| الأساس | تراجع < ${FRONTIER_DD.map(x => x * 100 + '%').join(' | تراجع < ')} |`);
    L.push('|---|' + FRONTIER_DD.map(() => '---').join('|') + '|');
    const spy = out.frontier[0].rows[0].benchCagr;
    for (const f of out.frontier) L.push(`| ${f.name} (\`${f.id}\`) | ` + f.rows.map(r => `${pct(r.cagr)} / ${pct(r.oosDD)}${r.meetsDD ? (r.beatsSpy ? ' ✅' : '') : ' ⚠️'}`).join(' | ') + ' |');
    L.push('', `SPY على نفس الأيام: CAGR ${pct(spy)}.`, '');
  }
  L.push('## تفاصيل أفضل 3', '');
  for (const c of cands.slice(0, 3)) {
    const o = c.oos;
    L.push(`### ${c.name} (\`${c.id}\`) — ${c.criteria.score}/7`, '');
    if (c.grid) L.push(`- الشبكة: ${c.combos} تركيبة \`${JSON.stringify(c.grid)}\``);
    L.push(`- خارج العينة ${o.from} → ${o.to}: عائد ${pct(o.ret)}، CAGR ${pct(o.cagr)}، تذبذب ${pct(o.vol)}، شارب ${num(o.sharpe)}، أقصى تراجع ${pct(o.maxDD)}، MAR ${num(o.mar)}`);
    if (o.bench) L.push(`- SPY على نفس الأيام: عائد ${pct(o.bench.ret)}، CAGR ${pct(o.bench.cagr)}، شارب ${num(o.bench.sharpe)}، أقصى تراجع ${pct(o.bench.maxDD)}، MAR ${num(o.bench.mar)}`);
    L.push(`- الصفقات: ${o.trades}، نسبة الربح ${pct(o.winRate)}، متوسط ${pct(o.avgTrade, 2)}، وسيط ${pct(o.medianTrade, 2)}، معامل الربح ${num(o.profitFactor)}، متوسط الاحتفاظ ${num(o.avgHold, 1)} يوم`);
    L.push(`- التعرض المتوسط ${pct(o.exposure, 0)}، الدوران السنوي ${num(o.turnover, 1)}×، الارتباط مع SPY ${num(o.corrBench)}`);
    L.push('- الاختيار الأمامي (لكل سنة من السنوات السابقة فقط): ' + (c.folds || []).map(f => `${f.year}: \`${JSON.stringify(f.params)}\``).join('، '));
    L.push('', '| السنة | الاستراتيجية | SPY |', '|---|---|---|');
    for (const y of Object.keys(o.yearly || {})) L.push(`| ${y} | ${pct(o.yearly[y])} | ${pct(o.bench && o.bench.yearly[y])} |`);
    if (c.episodes && c.episodes.length) {
      L.push('', 'أعمق فترات التراجع خارج العينة:', '', '| البداية (القمة) | القاع | التعافي | العمق |', '|---|---|---|---|');
      for (const e of c.episodes) L.push(`| ${e.start} | ${e.trough} | ${e.recovery ?? 'لم يتعافَ بعد'} | ${pct(e.depth)} |`);
    }
    L.push('', 'الشروط:', '');
    for (const k of c.criteria.checks) L.push(`- ${k.ok ? '✅' : '❌'} ${k.id}) ${k.label}: ${k.why}`);
    L.push('');
  }
  L.push('## المنهجية', '');
  L.push('- **الاختبار الأمامي:** لكل سنة تقويمية Y (بعد سنتين تدريب على الأقل) نختار تركيبة المعاملات بأعلى MAR (ثم شارب) على كل الأيام قبل Y فقط (نافذة متوسعة، بحد أدنى 20 صفقة داخل العينة)، ثم نأخذ أداءها في Y. السنوات الخارجية تُوصل ببعضها. سنوات الاختبار لا تدخل أبدًا في الاختيار.');
  L.push('- **طبقات المخاطر (الجولة 2):** فوق التركيبة المختارة لكل سنة نجرب 12 طبقة ثابتة: بدون، استهداف تذبذب المحفظة 6/8/10% (تذبذب 60 يومًا) و8% (20 يومًا) بسقف تعرض 100%، فلتر سوق قوي (SPY فوق متوسط 200 **و** عائد شهر > 0)، فلتر اتساع (> 50% من الكون فوق متوسط 50)، قاطع تراجع 5% → نقد أسبوعين، 7% → نقد 4 أسابيع، 5% → نقد حتى يتحسن السوق، وتركيبتان. الطبقة تُختار داخل العينة بأعلى CAGR بشرط تراجع داخل العينة < 10% (وإلا الأقل تراجعًا). الإشارة بعد إغلاق يوم والتنفيذ بإغلاق اليوم التالي، وتكلفة 0.10% على قيمة كل تعديل. النقد بعائد 0% (البديل المتوافق؛ لا صناديق سندات، وصناديق الصكوك تاريخها أقصر من 10 سنوات).');
  L.push('- **عائلات «+risk»:** نفس الإشارة مع وقف لكل مركز (ATR×2/3 أو 5%/10%) أو فلتر دخول، وسقف 30% من رأس المال لكل قطاع (من Yahoo).');
  L.push('- **الأكمام:** «زخم + ارتداد» = أفضل كم زخم وأفضل كم ارتداد داخل العينة، و«ميزانية المخاطر» = أعضاء المزيج؛ وزن كل كم = ميزانية تذبذب (2/3/4/6%) ÷ تذبذبه داخل العينة (بسقف)، والباقي نقد.');
  L.push('- **التنفيذ:** القرار بعد إغلاق يوم الإشارة والتنفيذ بافتتاح اليوم التالي. استثناءات موثقة: أثر بداية الشهر والاحتفاظ الليلي يشتريان بالإغلاق بقرار تقويمي/ببيانات الأمس (يُعرف قبل الإغلاق). أمر إيقاف الشراء (الاختراق) يُنفّذ عند max(الافتتاح، سعر التفعيل).');
  L.push('- **الوقف:** يُفحص على أدنى اليوم؛ فجوة تحته → التنفيذ بالافتتاح؛ لو لُمس الوقف والهدف بنفس اليوم نفترض الوقف أولاً (تحفّظ). في يوم الدخول بأمر إيقاف (الاختراق) لو لمس أدنى اليوم الوقف نفترض أنه حدث بعد الدخول — تحفّظ يضر عائلة الاختراق عمدًا لأن الشمعة اليومية لا تكشف الترتيب.');
  L.push('- **التكاليف لكل جانب:** 0.05% أساس + حسب متوسط قيمة التداول 20 يومًا (≥100M$: +0، ≥20M$: +0.05%، ≥5M$: +0.15%، ≥1M$: +0.35%، أقل: +0.60%) + للسعر (<5$: +0.20%، <10$: +0.05%).');
  L.push('- **رأس المال:** شراء فقط بالنقد المتاح (بلا رافعة ⇒ تعرض ≤ 100%)، حد أقصى للمراكز لكل استراتيجية، حجم متساوٍ (أو مخفّض حسب التذبذب)، أسهم كسرية مسموحة.');
  L.push(`- **الكون:** ${out.data.universeRule}. داخل الاختبار، «large» في كل يوم = أعلى ${ENGINE_DEFAULTS.largeN} سهم بمتوسط قيمة التداول 60 يومًا حتى ذلك اليوم وسعر ≥ 5$ وتاريخ ≥ 200 يوم.`);
  L.push(`- **الفلتر الشرعي في الاختبار:** ${out.data.screen}. المستبعَد: ${out.data.excluded} سهمًا.`);
  L.push('');
  L.push('## تحفّظات مهمة', '');
  L.push('- **انحياز البقاء:** قائمة NASDAQ Trader وYahoo فيها الأسهم المدرجة حاليًا فقط؛ الشركات التي أفلست أو شُطبت خلال السنوات العشر غائبة، واختيار الكون بسيولة اليوم يستخدم معلومة من المستقبل. هذا يرفع النتائج (خصوصًا للأسهم الصغيرة واستراتيجيات الارتداد). الفلتر اليومي بالسيولة يخفف ولا يلغي.');
  L.push('- **الطبقات تقريبية:** تُطبّق على منحنى رأس مال الاستراتيجية (كأن جزءًا من رأس المال فقط يُستثمر فيها)، وحصة الصفقة من الربح تُضرب في متوسط الوزن أثناء الاحتفاظ. الأكمام تُعاد موازنتها يوميًا بلا تكلفة إضافية.');
  L.push('- **التكاليف:** تقديرية؛ الانزلاق الحقيقي في أيام الذعر أو للأسهم الصغيرة قد يكون أكبر. لا ضرائب ولا عائد على النقد.');
  L.push('- **مصدر البيانات:** Yahoo Finance بلا مفتاح (أسعار معدّلة للتوزيعات والتقسيمات)؛ قد تحوي أخطاء أو فجوات. القطاعات من Yahoo إن توفرت.');
  L.push('- **الأداء الماضي لا يضمن المستقبل.** هذا بحث تعليمي وليس نصيحة مالية؛ أي استراتيجية ناجحة تمر أولاً على الحساب التجريبي وفق PLAYBOOK.md وبموافقة المالك.');
  L.push('');
  return L.join('\n');
}

/* ---------- التشغيل ---------- */
export async function runResearch({ barsBySym, groups, info = {}, log = console.log, families = [...FAMILIES, ...RISK_FAMILIES], panelOpt = {} }) {
  const T0 = Date.now();
  const P = buildPanel(barsBySym, groups, { ...panelOpt, sectors: info.sectors || panelOpt.sectors });
  const dataYears = P.D > 1 ? (P.dates[P.D - 1] - P.dates[0]) / (365.25 * 86400000) : 0;
  const start = Math.min(P.opt.warmup, P.D - 1);
  const ctx = { dataYears, screen: info.screen || 'استبعاد بالاسم فقط', start, D: P.D, folds: makeFolds(P.dates, { start }) };
  log(`اللوحة: ${P.S} رمزًا × ${P.D} يومًا، ${ctx.folds.length} سنوات خارج العينة (${(Date.now() - T0) / 1000} ث)`);
  const fams = [];
  let configs = 0;
  for (const fam of families) {
    const t = Date.now();
    const f = evaluateFamily(P, fam, ctx, log);
    configs += f.res.combos; f.res.seconds = (Date.now() - t) / 1000;
    fams.push(f);
  }
  const candidates = fams.map(f => f.res);
  const byId = new Map(fams.map(f => [f.id, f]));
  const sh = { ok: true, why: ctx.screen };

  // المزيج (الجولة 1)
  const ensPick = ctx.folds.map((f, j) => ensembleMembers(fams, ctx, j));
  const ensStream = ensPick.map(ms => (ms.length ? combineStreams(ms.map(m => ({ stream: m.st, w: 1 / ms.length }))) : cashStream(P.D)));
  const ensFolds = ensPick.map(ms => ms.map(m => ({ family: m.x.id, isScore: r4(m.fold.isScore) })));
  if (ctx.folds.length && fams.some(f => f.universe !== 'etf')) {
    const wf = wfSelectMulti(ctx.folds, (f, j) => [ensStream[j]], ['mar'], { start, years: P.years })[0];
    const res = summarize(P, ctx, { id: 'ensemble', name: 'مزيج أفضل العائلات غير المترابطة', universe: 'large|small', grid: null, combos: 0, wf,
      paramsOf: (f, j) => ensFolds[j], shariah: sh });
    candidates.push(res); byId.set('ensemble', { id: 'ensemble', name: res.name, universe: 'large|small', baseFor: j => ensStream[j], paramsFor: j => ensFolds[j] });
    log(`ensemble: OOS ${pct(res.oos.ret)} MAR ${num(res.oos.mar)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
  }

  // طبقات المخاطر فوق كل أساس → حدود الكفاءة؛ ومرشح «+طبقات» (هدف: تراجع < 10%) للأسس المستهدفة
  const specs = overlaySpecs(P);
  const frontier = [];
  for (const [id, b] of byId) {
    const wfs = overlayWF(P, ctx, specs, b.baseFor);
    frontier.push(frontierRow(P, id, b.name, wfs));
    if (OVERLAY_TARGETS.includes(id)) {
      const res = summarize(P, ctx, { id: id + '+overlay', name: b.name + ' + طبقات المخاطر', universe: b.universe, grid: null, combos: specs.length, wf: wfs[0],
        paramsOf: (f, j) => ({ base: b.paramsFor(j), overlay: f.label }), shariah: shariahFor(b.universe, ctx) });
      candidates.push(res);
      log(`${id}+overlay: OOS CAGR ${pct(res.oos.cagr)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
    }
  }

  // الأكمام بميزانية مخاطر
  const best = (ids, j) => ids.map(i => byId.get(i)).filter(Boolean).map(x => ({ x, fold: x.wf && x.wf.folds[j] })).filter(o => o.fold)
    .sort((a, b) => b.fold.isScore - a.fold.isScore)[0];
  const sleeves = [
    ['combo-mom-mr', 'زخم + ارتداد قصير بميزانية مخاطر لكل كم', (f, j) => {
      const ms = [best(MOM_SLEEVES, j), best(MR_SLEEVES, j)].filter(Boolean).map(o => ({ id: o.x.id, st: o.x.baseFor(j) }));
      return budgetOptions(ms, ctx, f, 0.5);
    }],
    ['combo-budget', 'أعضاء المزيج بميزانية مخاطر لكل كم', (f, j) => {
      const ms = ensPick[j].map(m => ({ id: m.x.id, st: m.st }));
      return budgetOptions(ms, ctx, f, ms.length ? 1 / ms.length : 1);
    }],
  ];
  for (const [id, name, optionsFor] of sleeves) {
    const wfs = wfSelectMulti(ctx.folds, optionsFor, FRONTIER_DD.map(T => ({ maxDD: T })), { start, years: P.years });
    frontier.push(frontierRow(P, id, name, wfs));
    const res = summarize(P, ctx, { id, name, universe: 'large|small', grid: { budget: SLEEVE_BUDGETS }, combos: SLEEVE_BUDGETS.length, wf: wfs[0],
      paramsOf: f => f.label, shariah: sh });
    candidates.push(res);
    log(`${id}: OOS CAGR ${pct(res.oos.cagr)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
  }

  const marKey = c => (c.oos.mar === 'Infinity' ? 1e9 : Number.isFinite(c.oos.mar) ? c.oos.mar : -1e9);
  candidates.sort((a, b) => marKey(b) - marKey(a));
  const passed = candidates.filter(c => c.criteria.passed);
  const closest = [...candidates].sort((a, b) => b.criteria.score - a.criteria.score || marKey(b) - marKey(a))[0];
  const failedOf = c => c.criteria.checks.filter(k => !k.ok).map(k => k.label).join('، ');
  const spyC = closest && closest.oos.bench ? closest.oos.bench.cagr : null;
  // المفاضلة الصريحة: أعلى CAGR بتراجع < 10%، وأقل تراجع مع CAGR > SPY (من كل المرشحين وكل خانات حدود الكفاءة)
  const points = [...candidates.filter(c => c.universe !== 'etf').map(c => ({ name: c.name, id: c.id, cagr: c.oos.cagr, dd: c.oos.maxDD })),
    ...frontier.filter(f => byId.get(f.id) ? byId.get(f.id).universe !== 'etf' : true).flatMap(f => f.rows.map(r => ({ name: `${f.name} (حد ${r.maxDD * 100}%)`, id: f.id, cagr: r.cagr, dd: r.oosDD })))]
    .filter(x => Number.isFinite(x.cagr) && Number.isFinite(x.dd));
  const under10 = points.filter(x => x.dd < CRITERIA.maxDD).sort((a, b) => b.cagr - a.cagr)[0];
  const beating = points.filter(x => spyC !== null && x.cagr > spyC).sort((a, b) => a.dd - b.dd)[0];
  const tradeoff = `**المفاضلة الصريحة (أسهم متوافقة فقط، خارج العينة):** أعلى CAGR مع تراجع < 10% = ${under10 ? `${pct(under10.cagr)} (${under10.name}، تراجع ${pct(under10.dd)})` : 'لا يوجد'} مقابل SPY ${pct(spyC)}؛ وأقل تراجع مع CAGR أعلى من SPY = ${beating ? `${pct(beating.dd)} (${beating.name}، CAGR ${pct(beating.cagr)})` : 'لا يوجد'}.`;
  const impossible = !passed.length && !(under10 && spyC !== null && under10.cagr > spyC);
  const verdict = passed.length
    ? `«✅ وصلنا لنتيجة ممتازة: ${passed.map(c => `${c.name} (\`${c.id}\`) — CAGR خارج العينة ${pct(c.oos.cagr)} مقابل SPY ${pct(c.oos.bench && c.oos.bench.cagr)}، أقصى تراجع ${pct(c.oos.maxDD)}، ${c.oos.trades} صفقة`).join('؛ ')}»`
    : `«❌ لا توجد استراتيجية تحقق كل الشروط بعد — الأقرب: ${closest ? `${closest.name} (\`${closest.id}\`) ${closest.criteria.score}/7، CAGR ${pct(closest.oos.cagr)} مقابل SPY ${pct(spyC)}، أقصى تراجع ${pct(closest.oos.maxDD)}، تفشل في: ${failedOf(closest)}` : '—'}${impossible ? `. بصراحة: لم نجد خارج العينة أي تركيبة تجمع تراجعًا < 10% مع CAGR أعلى من SPY — ${beating ? `أقل تراجع حققناه مع التفوق على SPY هو ${pct(beating.dd)} (${beating.name})` : 'ولا توجد أصلًا تركيبة أسهم متوافقة تتفوق على SPY خارج العينة'}، وأعلى CAGR بتراجع < 10% هو ${under10 ? `${pct(under10.cagr)} (${under10.name})` : '—'}` : ''}»`;
  const seconds = (Date.now() - T0) / 1000;
  log(`انتهى: ${candidates.length} مرشحًا، ${configs} تركيبة + ${specs.length} طبقة، ${seconds.toFixed(1)} ث`);
  const fmt = t => new Date(t).toISOString().slice(0, 10);
  return {
    generatedAt: new Date().toISOString(), round: 2, runtimeSec: r4(seconds), configs, overlays: specs.map(o => ({ id: o.id, label: o.label })),
    data: { source: info.source || 'yahoo', from: P.D ? fmt(P.dates[0]) : null, to: P.D ? fmt(P.dates[P.D - 1]) : null, years: r4(dataYears), days: P.D,
      symbols: P.S, large: P.group.filter(g => g === 'large').length, small: P.group.filter(g => g === 'small').length,
      excluded: info.excluded || 0, screen: ctx.screen, universeRule: info.universeRule || '—', fetchedAt: info.fetchedAt || null,
      sectorsKnown: P.sector.filter(Boolean).length },
    criteriaRules: CRITERIA, verdict, tradeoff, impossible, bestUnder10: under10 || null, lowestDDBeatingSpy: beating || null,
    passed: passed.map(c => c.id), closest: closest ? closest.id : null, frontier, candidates,
  };
}

async function main(args) {
  const outArg = args.find(a => a.startsWith('--out='));
  const synth = args.find(a => a.startsWith('--synthetic'));
  let input, outDir = outArg ? path.resolve(outArg.slice(6)) : RESULTS;
  if (synth) {
    const [S, D] = (synth.split('=')[1] || '1500x2500').split('x').map(Number);
    console.log(`بيانات اصطناعية: ${S} سهم × ${D} يوم`);
    const t = Date.now();
    const u = synthUniverse({ nLarge: Math.round(S * 0.75), nSmall: S - Math.round(S * 0.75), days: D });
    console.log(`  التوليد ${(Date.now() - t) / 1000} ث`);
    input = { barsBySym: u.barsBySym, groups: u.groups, info: { source: 'synthetic', screen: 'بيانات اصطناعية', universeRule: 'اصطناعي', sectors: u.sectors } };
    if (!outArg) outDir = path.join(os.tmpdir(), 'rased-research-synthetic');
  } else {
    const d = await loadResearchData();
    if (!d.selection || d.barsBySym.size < 10 || !d.barsBySym.has('SPY')) {
      console.log('لا توجد بيانات بحث كافية (شغّل lab/research/data.mjs أولاً) — لا تغيير على النتائج.');
      return;
    }
    const prof = Object.values(d.profiles).filter(p => p && !p.err).length;
    const total = d.selection.large.length + d.selection.small.length;
    const screen = prof >= total * 0.5
      ? `استبعاد بالقطاع/الصناعة من Yahoo (${prof} من ${total} سهمًا لها قطاع) + بالاسم: بنوك، تأمين، خمور، قمار، تبغ، رهن عقاري، إقراض استهلاكي. لا فحص للنسب المالية (يتم حيًّا عبر يقين)`
      : `القطاعات من Yahoo غير متاحة لأغلب الأسهم (${prof} من ${total}) — استبعاد بالاسم فقط (بنوك، تأمين، خمور، قمار، تبغ، رهن عقاري)؛ فجوة موثقة. لا فحص للنسب المالية (يتم حيًّا عبر يقين)`;
    const sectors = Object.fromEntries(Object.entries(d.profiles).filter(([, p]) => p && !p.err && p.sector).map(([s, p]) => [s, p.sector]));
    input = { barsBySym: d.barsBySym, groups: d.groups,
      info: { source: 'yahoo', screen, excluded: Object.keys(d.excluded).length, universeRule: d.selection.rule, fetchedAt: d.meta.fetchedAt, sectors } };
  }
  const out = await runResearch(input);
  await mkdir(outDir, { recursive: true });
  await writeFile(path.join(outDir, 'research.json'), JSON.stringify(out, null, 1));
  await writeFile(path.join(outDir, 'RESEARCH_REPORT.md'), buildReport(out));
  console.log(out.verdict);
  console.log('كُتب: ' + path.join(outDir, 'research.json'));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(e => { console.error(e); process.exit(1); });
}
