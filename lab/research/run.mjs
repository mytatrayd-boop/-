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
  makeFolds, wfSelectMulti, drawdownEpisodes, pickLive } from './engine.mjs';
import { FAMILIES, gridCombos } from './strategies/index.mjs';
import { RISK_FAMILIES, overlaySpecs, OVERLAY_TARGETS, OVERLAY_SET, OBJECTIVE_DD, SAT_FAMILIES, CORE_WEIGHTS, MOM_SLEEVES, MR_SLEEVES, SLEEVE_BUDGETS, FRONTIER_DD } from './overlays.mjs';
import { loadResearchData } from './data.mjs';
import { synthUniverse } from './synth.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const RESULTS = path.join(HERE, '..', 'results');
// شروط «النتيجة الممتازة» — مُحدَّثة بقرار المالك (desk/ROADMAP.md، 2026-10-03): الأولوية للتفوق على SPY، وتراجع ≤ 25%.
export const CRITERIA = {
  minDataYears: 9.5, minTrades: 100, minOosYears: 3, maxDD: 0.25, beatYearsFrac: 4 / 7,
};
const r4 = x => (x === null || x === undefined ? null : !Number.isFinite(x) ? (x > 0 ? 'Infinity' : x < 0 ? '-Infinity' : null) : Math.round(x * 1e4) / 1e4);
const pct = (x, d = 1) => (x === null || x === undefined || !Number.isFinite(Number(x)) ? '—' : (Number(x) * 100).toFixed(d) + '%');
const num = (x, d = 2) => (x === null || x === undefined ? '—' : x === 'Infinity' || x === Infinity ? '∞' : Number.isFinite(Number(x)) ? Number(x).toFixed(d) : '—');
const fmtDay = (P, d) => new Date(P.dates[d]).toISOString().slice(0, 10);

/* ---------- الشروط السبعة ---------- */
// c: { dataYears, folds, oos: {...fullMetrics}, shariah: {ok, why} } → { passed, score, checks: [{id, label, ok, value, why}] }
export function checkCriteria(c, k = CRITERIA) {
  const o = c.oos || {}, b = o.bench || {}, rc = o.recent || {};
  const needBeat = Math.ceil((o.yearsTotal || 0) * k.beatYearsFrac - 1e-9);
  const checks = [
    { id: 1, label: 'نحو 10 سنوات بيانات', ok: c.dataYears >= k.minDataYears, value: r4(c.dataYears),
      why: `${num(c.dataYears, 1)} سنة (المطلوب ≥ ${k.minDataYears})` },
    { id: 2, label: '≥ 100 صفقة', ok: o.trades >= k.minTrades, value: o.trades ?? 0, why: `${o.trades ?? 0} صفقة خارج العينة` },
    { id: 3, label: 'رابحة خارج العينة (اختبار أمامي)', ok: (c.folds || 0) >= k.minOosYears && o.ret > 0, value: r4(o.ret),
      why: `${c.folds || 0} سنوات خارج العينة، العائد ${pct(o.ret)}` },
    { id: 4, label: 'تتفوق على SPY بعد التكاليف (كامل الفترة + النصف الأحدث)',
      ok: Number.isFinite(b.ret) && o.ret > b.ret && Number.isFinite(rc.benchRet) && rc.ret > rc.benchRet, value: r4((rc.cagr ?? 0) - (rc.benchCagr ?? 0)),
      why: `كامل: ${pct(o.ret)} مقابل SPY ${pct(b.ret)} (CAGR ${pct(o.cagr)} مقابل ${pct(b.cagr)})؛ النصف الأحدث من ${rc.from ?? '—'}: CAGR ${pct(rc.cagr)} مقابل ${pct(rc.benchCagr)}` },
    { id: 5, label: `أقصى تراجع ≤ ${k.maxDD * 100}%`, ok: Number.isFinite(o.maxDD) && o.maxDD <= k.maxDD, value: r4(o.maxDD), why: `أقصى تراجع ${pct(o.maxDD)}` },
    { id: 6, label: 'لا تعتمد على صفقتين + رابحة أغلب السنوات + تتفوق على SPY في 4 من 7 سنوات',
      ok: o.best2Removed > 0 && o.yearsProfitable > (o.yearsTotal || 0) / 2 && (o.yearsBeatSpy ?? 0) >= needBeat && needBeat > 0,
      value: r4(o.best2Removed), why: `بعد حذف أفضل صفقتين ${pct(o.best2Removed)}، سنوات رابحة ${o.yearsProfitable ?? 0}/${o.yearsTotal ?? 0}، تفوق على SPY ${o.yearsBeatSpy ?? 0}/${o.yearsTotal ?? 0} (المطلوب ${needBeat})` },
    { id: 7, label: 'شراء فقط ومتوافقة شرعيًا في الشكل (تعرض ≤ 100%)', ok: !!(c.shariah && c.shariah.ok) && !(o.maxGross > 1 + 1e-9),
      value: r4(o.maxGross), why: `${c.shariah ? c.shariah.why : '—'}؛ أقصى تعرض ${pct(o.maxGross, 0)} بلا رافعة ولا بيع على المكشوف ولا خيارات` },
  ];
  const score = checks.filter(x => x.ok).length;
  return { passed: score === checks.length, score, checks };
}

// النصف الأحدث من فترة خارج العينة (تقسيم بالتاريخ عند المنتصف) + عدد السنوات التي تفوقت فيها على SPY
export function recentHalf(dates, days, rets, bench) {
  if (!days.length) return null;
  const mid = (dates[days[0]] + dates[days[days.length - 1]]) / 2;
  const i0 = days.findIndex(d => dates[d] >= mid);
  const a = returnStats(rets.slice(i0)), b = returnStats((bench || []).slice(i0));
  return { from: new Date(dates[days[i0]]).toISOString().slice(0, 10), ret: a.ret, cagr: a.cagr, maxDD: a.maxDD, benchRet: b.ret, benchCagr: b.cagr };
}
export const yearsBeating = (yearly, benchYearly) => Object.keys(yearly).filter(y => benchYearly && Number.isFinite(benchYearly[y]) && yearly[y] > benchYearly[y]).length;

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
  const rh = recentHalf(P.dates, wf.days, wf.rets, bench);
  m.recent = rh; m.yearsBeatSpy = m.bench ? yearsBeating(m.yearly, m.bench.yearly) : 0;
  const folds = wf.folds.map((f, j) => ({ year: f.year, params: paramsOf(f, j), isScore: r4(f.isScore), isTrades: f.isTrades, isDD: r4(f.isDD), isCagr: r4(f.isCagr) }));
  const oos = {
    from: wf.days.length ? fmtDay(P, wf.days[0]) : null,
    to: wf.days.length ? fmtDay(P, wf.days[wf.days.length - 1]) : null,
    ...Object.fromEntries(Object.entries(m).filter(([k]) => !['yearly', 'bench', 'recent'].includes(k)).map(([k, v]) => [k, typeof v === 'number' ? r4(v) : v])),
    recent: rh ? Object.fromEntries(Object.entries(rh).map(([k, v]) => [k, typeof v === 'number' ? r4(v) : v])) : null,
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
  // المعاملات «الحية»: نفس قاعدة الاختيار على كل البيانات حتى اليوم (لقواعد التداول — ليست نتيجة اختبار)
  const live = pickLive(streams, { start: ctx.start });
  return { id: fam.family, name: fam.name, universe: fam.universe, fam, res, combos, wf, baseFor: j => streams[wf.folds[j].chosen], paramsFor: j => combos[wf.folds[j].chosen],
    liveStream: streams[live], liveParams: combos[live] };
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
  L.push(`**الشروط (قرار المالك):** ${out.criteriaRules ? `10 سنوات بيانات، ≥ 100 صفقة، رابحة خارج العينة، تتفوق على SPY بعد التكاليف خارج العينة كاملًا **وفي نصفه الأحدث**، أقصى تراجع ≤ ${out.criteriaRules.maxDD * 100}%، بعد حذف أفضل صفقتين تبقى موجبة + رابحة أغلب السنوات + تتفوق على SPY في 4 من 7 سنوات على الأقل، شراء فقط بلا رافعة وتعرض ≤ 100%.` : ''}`, '');
  for (const c of cands.filter(x => x.tradingRules)) {
    L.push(`### قواعد التداول — ${c.name} (\`${c.id}\`)`, '');
    if (c.live) L.push(`> ${c.live.note}: \`${JSON.stringify(c.live.params)}\``, '');
    for (const r of c.tradingRules) L.push(r.startsWith('  ') ? `   - ${r.trim()}` : `- ${r}`);
    L.push('');
  }
  L.push('## ملخص كل المرشحين (مرتبة بـ MAR خارج العينة)', '');
  L.push('| # | الاستراتيجية | العائد | CAGR | SPY CAGR | النصف الأحدث: CAGR / SPY | شارب | أقصى تراجع | MAR | صفقات | سنوات رابحة | تفوق على SPY (سنوات) | بعد حذف أفضل صفقتين | الشروط |');
  L.push('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  cands.forEach((c, i) => {
    const o = c.oos, rc = o.recent || {};
    L.push(`| ${i + 1} | ${c.name} (\`${c.id}\`) | ${pct(o.ret)} | ${pct(o.cagr)} | ${pct(o.bench && o.bench.cagr)} | ${pct(rc.cagr)} / ${pct(rc.benchCagr)} | ${num(o.sharpe)} | ${pct(o.maxDD)} | ${num(o.mar)} | ${o.trades} | ${o.yearsProfitable}/${o.yearsTotal} | ${o.yearsBeatSpy ?? 0}/${o.yearsTotal} | ${pct(o.best2Removed)} | ${c.criteria.score}/7${c.criteria.passed ? ' ✅' : ''} |`);
  });
  if (cands.length) L.push('', `فترة خارج العينة: ${cands[0].oos.from} → ${cands[0].oos.to}؛ النصف الأحدث يبدأ ${(cands[0].oos.recent || {}).from ?? '—'}.`);
  L.push('');
  if (out.frontier && out.frontier.length) {
    L.push('## حدود الكفاءة: أفضل CAGR خارج العينة مع حد للتراجع (الاختيار داخل العينة فقط)', '');
    L.push(`لكل سنة نختار الطبقة (من 12 طبقة «${out.overlaySet || 'mild'}») أو ميزانية الأكمام بأعلى CAGR داخل العينة بشرط أن يبقى تراجعها داخل العينة تحت الحد، ثم نقيس السنة التالية. الخانة: CAGR / أقصى تراجع خارج العينة. ✅ = التراجع خارج العينة تحت الحد **و** CAGR > SPY؛ ⚠️ = تجاوز الحد خارج العينة.`, '');
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
  L.push('- **الجولة 3 (التفوق على SPY):** عائلات زخم/اتجاه جديدة — زخم مركّز أسبوعي (12-1 خام/معدّل بالتذبذب/مع قمة السنة/مع التسارع)، تدوير الزخم ↔ السلة الأساسية ببوابة SPY، اختراق قمة 6/12 شهرًا بوقف ATR متحرك وسقف قطاع، زخم القطاعات، زخم + شراء تراجع قصير، والسلة الأساسية المتوافقة (أكبر 20/30 سهمًا بقيمة التداول كبديل لصندوق متوافق غير موجود بتاريخ 10 سنوات) و«أساس + قمر» (60/70/80% أساس + أفضل عائلتي زخم داخل العينة). الطبقات خفيفة: استهداف تذبذب 15–25%، فلاتر انهيار، قواطع 15–20%. الاختيار في المرحلة الثانية: أعلى CAGR داخل العينة بتراجع < 25%.');
  L.push('- **المعاملات الحية في «قواعد التداول»:** نفس قاعدة الاختيار مطبّقة على كل البيانات حتى آخر يوم — هي ما نتداول به من الآن، وليست نتيجة اختبار.');
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
// قواعد التداول الآلية (عربي) لمرشح: من قواعد العائلة بالمعاملات الحية + الطبقة/الأوزان + قواعد عامة
const COMMON_RULES = [
  'قبل كل شراء: فحص يقين الشرعي (غير المتوافق أو «غير معروف» لا يُشترى إلا بقرار المالك)، ولا دخول قبل إعلان أرباح خلال مدة الصفقة إن أمكن.',
  'بلا رافعة ولا بيع على المكشوف ولا خيارات؛ النقد غير المستثمر يبقى نقدًا (0%).',
  'التنفيذ بأوامر السوق عند الافتتاح (أو بأمر إغلاق عند تعديل التعرض)، وتسجيل كل أمر في desk/journal.',
];
function familyRules(F, params) {
  if (F && F.fam && typeof F.fam.rules === 'function') return F.fam.rules(params);
  return [`الإشارة: ${F ? F.name : '—'} بالمعاملات \`${JSON.stringify(params)}\` (التفاصيل في lab/research/strategies).`];
}

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
  const live = new Map(fams.map(f => [f.id, { rules: () => familyRules(f, f.liveParams), params: f.liveParams }]));
  const sh = { ok: true, why: ctx.screen };
  const objIdx = Math.max(0, FRONTIER_DD.indexOf(OBJECTIVE_DD));
  const objectives = FRONTIER_DD.map(T => ({ maxDD: T }));
  const frontier = [];
  const multi = optionsFor => wfSelectMulti(ctx.folds, optionsFor, objectives, { start, years: P.years });

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
  // المزيج الحي: نفس قاعدة اختيار الأعضاء على كل البيانات حتى اليوم
  {
    const cand = fams.filter(x => x.universe !== 'etf').map(x => { const isR = Array.prototype.slice.call(x.liveStream.rets, start + 1); return { x, isR, s: returnStats(isR) }; })
      .filter(o => o.s.mar > 0).sort((a, b) => b.s.mar - a.s.mar);
    const picked = [];
    for (const o of cand) { if (picked.length >= 3) break; if (picked.every(q => corr(q.isR, o.isR) < 0.5)) picked.push(o); }
    live.set('ensemble', { params: picked.map(o => ({ family: o.x.id, params: o.x.liveParams })), rules: () => picked.flatMap(o => [
      `كم «${o.x.name}» (${(100 / picked.length).toFixed(0)}% من رأس المال، حساب فرعي):`, ...familyRules(o.x, o.x.liveParams).map(r => '  ' + r)]) });
  }

  // «أساس + قمر صناعي»: السلة الأساسية (60/70/80%) + أفضل عائلتي زخم داخل العينة كقمر؛ الاختيار داخل العينة بأعلى CAGR بتراجع < 25%
  const core = byId.get('core-basket');
  if (core && ctx.folds.length) {
    const sats = j => SAT_FAMILIES.map(i => byId.get(i)).filter(Boolean).filter(x => x.wf.folds[j]).sort((a, b) => b.wf.folds[j].isScore - a.wf.folds[j].isScore).slice(0, 2);
    const csOpts = (coreSt, satList) => CORE_WEIGHTS.flatMap(w => satList.map(([id, st]) => Object.assign(combineStreams([{ stream: coreSt, w }, { stream: st, w: 1 - w }]),
      { label: { core: w, satellite: id } })));
    const wfs = multi((f, j) => csOpts(core.baseFor(j), sats(j).map(x => [x.id, x.baseFor(j)])));
    const wf = wfs[objIdx];
    const res = summarize(P, ctx, { id: 'core-satellite', name: 'أساس متوافق + قمر زخم', universe: 'large', grid: { core: CORE_WEIGHTS, satellite: 'أفضل 2 من ' + SAT_FAMILIES.join('/') },
      combos: CORE_WEIGHTS.length * 2, wf, paramsOf: (f, j) => ({ ...f.label, coreParams: core.paramsFor(j) }), shariah: sh });
    candidates.push(res);
    const chosenOpt = [];
    byId.set('core-satellite', { id: 'core-satellite', name: res.name, universe: 'large',
      baseFor: j => { if (!chosenOpt[j]) { const o = csOpts(core.baseFor(j), sats(j).map(x => [x.id, x.baseFor(j)])); chosenOpt[j] = o[wf.folds[j].chosen]; } return chosenOpt[j]; },
      paramsFor: j => wf.folds[j].label });
    // الحي: أفضل قمرين على كل البيانات
    const liveSats = SAT_FAMILIES.map(i => byId.get(i)).filter(Boolean).map(x => ({ x, s: returnStats(Array.prototype.slice.call(x.liveStream.rets, start + 1)) }))
      .sort((a, b) => b.s.mar - a.s.mar).slice(0, 2).map(o => [o.x.id, o.x.liveStream]);
    const lo = csOpts(core.liveStream, liveSats), lk = pickLive(lo, { start, objective: objectives[objIdx] }), lab = lo[lk].label;
    const satF = byId.get(lab.satellite);
    live.set('core-satellite', { params: lab, liveStream: lo[lk], rules: () => [
      `الأساس (${Math.round(lab.core * 100)}% من رأس المال):`, ...familyRules(core, core.liveParams).map(x => '  ' + x),
      `القمر (${Math.round((1 - lab.core) * 100)}%): ${satF.name}:`, ...familyRules(satF, satF.liveParams).map(x => '  ' + x),
      'الأوزان: كل كم يُدار كحساب فرعي بنسبته؛ إعادة النسب إلى الهدف شهريًا.'] });
    log(`core-satellite: OOS CAGR ${pct(res.oos.cagr)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
  }

  // طبقات المخاطر (الخفيفة) فوق كل أساس → حدود الكفاءة؛ ومرشح «+طبقات» للأسس المستهدفة
  const specs = overlaySpecs(P, OVERLAY_SET);
  for (const [id, b] of byId) {
    const options = (f, j) => { const base = b.baseFor(j); return specs.map(o => Object.assign(applyOverlay(base, o.spec, { regimeFn: o.regimeFn }), { label: o.id })); };
    const wfs = multi(options);
    frontier.push(frontierRow(P, id, b.name, wfs));
    if (OVERLAY_TARGETS.includes(id)) {
      const res = summarize(P, ctx, { id: id + '+overlay', name: b.name + ' + طبقات المخاطر', universe: b.universe, grid: null, combos: specs.length, wf: wfs[objIdx],
        paramsOf: (f, j) => ({ base: b.paramsFor(j), overlay: f.label }), shariah: shariahFor(b.universe, ctx) });
      candidates.push(res);
      const bl = live.get(id), baseLive = b.liveStream || (bl && bl.liveStream);
      if (bl && baseLive) {
        const lo = specs.map(o => applyOverlay(baseLive, o.spec, { regimeFn: o.regimeFn })), sp = specs[pickLive(lo, { start, objective: objectives[objIdx] })];
        live.set(id + '+overlay', { params: { base: bl.params, overlay: sp.id }, rules: () => [...bl.rules(),
          `طبقة المحفظة: ${sp.label}. القرار بعد الإغلاق والتعديل بأمر إغلاق اليوم التالي؛ الجزء غير المستثمر نقد.`] });
      }
      log(`${id}+overlay: OOS CAGR ${pct(res.oos.cagr)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
    }
  }

  // الأكمام بميزانية مخاطر (الجولة 2)
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
    const wfs = multi(optionsFor);
    frontier.push(frontierRow(P, id, name, wfs));
    const res = summarize(P, ctx, { id, name, universe: 'large|small', grid: { budget: SLEEVE_BUDGETS }, combos: SLEEVE_BUDGETS.length, wf: wfs[objIdx],
      paramsOf: f => f.label, shariah: sh });
    candidates.push(res);
    log(`${id}: OOS CAGR ${pct(res.oos.cagr)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
  }

  const marKey = c => (c.oos.mar === 'Infinity' ? 1e9 : Number.isFinite(c.oos.mar) ? c.oos.mar : -1e9);
  candidates.sort((a, b) => marKey(b) - marKey(a));
  const passed = candidates.filter(c => c.criteria.passed);
  for (const c of passed) {
    const l = live.get(c.id);
    c.live = l ? { params: l.params, note: 'المعاملات مختارة بنفس القاعدة على كل البيانات حتى آخر يوم (للتداول من الآن، ليست نتيجة اختبار)' } : null;
    c.tradingRules = [...(l ? l.rules() : [`الإشارة كما في وصف «${c.name}».`]), ...COMMON_RULES];
  }
  const closest = [...candidates].sort((a, b) => b.criteria.score - a.criteria.score || marKey(b) - marKey(a))[0];
  const failedOf = c => c.criteria.checks.filter(k => !k.ok).map(k => k.label).join('، ');
  const spyC = closest && closest.oos.bench ? closest.oos.bench.cagr : null;
  const nums = c => { const o = c.oos, rc = o.recent || {}; return `CAGR ${pct(o.cagr)} مقابل SPY ${pct(o.bench && o.bench.cagr)}، النصف الأحدث ${pct(rc.cagr)} مقابل ${pct(rc.benchCagr)}، أقصى تراجع ${pct(o.maxDD)}، تفوق على SPY في ${o.yearsBeatSpy}/${o.yearsTotal} سنوات، ${o.trades} صفقة`; };
  // المفاضلة الصريحة: من يتفوق على SPY (كامل + النصف الأحدث) وبأي تراجع، وأعلى CAGR بتراجع ≤ 25%
  const stock = candidates.filter(c => c.universe !== 'etf');
  const beatBoth = stock.filter(c => c.criteria.checks[3].ok).sort((a, b) => a.oos.maxDD - b.oos.maxDD)[0];
  const under = stock.filter(c => c.oos.maxDD <= CRITERIA.maxDD).sort((a, b) => b.oos.cagr - a.oos.cagr)[0];
  const tradeoff = `**المفاضلة الصريحة (أسهم متوافقة فقط، خارج العينة):** أقل تراجع بين من تفوق على SPY كاملًا وفي النصف الأحدث = ${beatBoth ? `${pct(beatBoth.oos.maxDD)} (${beatBoth.name}، CAGR ${pct(beatBoth.oos.cagr)})` : 'لا يوجد'}؛ وأعلى CAGR بتراجع ≤ ${CRITERIA.maxDD * 100}% = ${under ? `${pct(under.oos.cagr)} (${under.name}، تراجع ${pct(under.oos.maxDD)})` : 'لا يوجد'} مقابل SPY ${pct(spyC)}.`;
  const verdict = passed.length
    ? `«✅ وصلنا لنتيجة ممتازة: ${passed.map(c => `${c.name} (\`${c.id}\`) — ${nums(c)}`).join('؛ ')}»`
    : `«❌ لا توجد استراتيجية تحقق كل الشروط بعد — الأقرب: ${closest ? `${closest.name} (\`${closest.id}\`) ${closest.criteria.score}/7: ${nums(closest)}؛ تفشل في: ${failedOf(closest)}` : '—'}»`;
  const seconds = (Date.now() - T0) / 1000;
  log(`انتهى: ${candidates.length} مرشحًا، ${configs} تركيبة + ${specs.length} طبقة، ${seconds.toFixed(1)} ث`);
  const fmt = t => new Date(t).toISOString().slice(0, 10);
  return {
    generatedAt: new Date().toISOString(), round: 3, runtimeSec: r4(seconds), configs, overlaySet: OVERLAY_SET, overlays: specs.map(o => ({ id: o.id, label: o.label })),
    data: { source: info.source || 'yahoo', from: P.D ? fmt(P.dates[0]) : null, to: P.D ? fmt(P.dates[P.D - 1]) : null, years: r4(dataYears), days: P.D,
      symbols: P.S, large: P.group.filter(g => g === 'large').length, small: P.group.filter(g => g === 'small').length,
      excluded: info.excluded || 0, screen: ctx.screen, universeRule: info.universeRule || '—', fetchedAt: info.fetchedAt || null,
      sectorsKnown: P.sector.filter(Boolean).length },
    criteriaRules: CRITERIA, verdict, tradeoff, lowestDDBeatingSpy: beatBoth ? { id: beatBoth.id, maxDD: beatBoth.oos.maxDD, cagr: beatBoth.oos.cagr } : null,
    bestUnderMaxDD: under ? { id: under.id, maxDD: under.oos.maxDD, cagr: under.oos.cagr } : null,
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
