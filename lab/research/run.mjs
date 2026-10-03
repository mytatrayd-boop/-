// تشغيل البحث كاملاً: كل عائلة × شبكتها الصغيرة → اختبار أمامي سنوي (نافذة متوسعة) → مقاييس خارج العينة
// مقابل SPY على نفس الأيام → فحص الشروط السبعة آليًا → lab/results/research.json و RESEARCH_REPORT.md (عربي).
// الاستخدام: node lab/research/run.mjs                 (بيانات lab/data/research من data.mjs)
//            node lab/research/run.mjs --synthetic[=1500x2500] [--out=DIR]   (قياس السرعة/تجربة بلا شبكة)
import { writeFile, mkdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { buildPanel, runStrategy, walkForward, fullMetrics, dailyReturns, returnStats, ENGINE_DEFAULTS } from './engine.mjs';
import { FAMILIES, gridCombos } from './strategies/index.mjs';
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

/* ---------- تقييم عائلة ---------- */
function benchRets(P, days) {
  const s = P.sym('SPY'); if (s < 0) return null;
  return days.map(d => { const a = P.c[s][d - 1], b = P.c[s][d]; return a > 0 && b > 0 ? b / a - 1 : 0; });
}

function sampleEquity(P, days, rets, bench, every = 5) {
  const out = []; let e = 1, b = 1;
  for (let i = 0; i < days.length; i++) {
    e *= 1 + rets[i]; if (bench) b *= 1 + bench[i];
    if (i % every === 0 || i === days.length - 1) out.push([new Date(P.dates[days[i]]).toISOString().slice(0, 10), r4(e), bench ? r4(b) : null]);
  }
  return out;
}

function summarize(P, ctx, { id, name, universe, grid, combos, wf, paramsOf, shariah, extra = {} }) {
  const bench = benchRets(P, wf.days);
  const m = fullMetrics({ rets: wf.rets, years: wf.years, trades: wf.trades, gross: wf.gross, turn: wf.turn, bench });
  const folds = wf.folds.map(f => ({ year: f.year, params: paramsOf(f), isScore: r4(f.isScore), isTrades: f.isTrades }));
  const oos = {
    from: wf.days.length ? new Date(P.dates[wf.days[0]]).toISOString().slice(0, 10) : null,
    to: wf.days.length ? new Date(P.dates[wf.days[wf.days.length - 1]]).toISOString().slice(0, 10) : null,
    ...Object.fromEntries(Object.entries(m).filter(([k]) => !['yearly', 'bench'].includes(k)).map(([k, v]) => [k, typeof v === 'number' ? r4(v) : v])),
    yearly: Object.fromEntries(Object.entries(m.yearly).map(([y, v]) => [y, r4(v)])),
    bench: m.bench ? { ret: r4(m.bench.ret), cagr: r4(m.bench.cagr), sharpe: r4(m.bench.sharpe), maxDD: r4(m.bench.maxDD), mar: r4(m.bench.mar),
      yearly: Object.fromEntries(Object.entries(m.bench.yearly).map(([y, v]) => [y, r4(v)])) } : null,
  };
  const numeric = { ...m, bench: m.bench };
  const criteria = checkCriteria({ dataYears: ctx.dataYears, folds: wf.folds.length, oos: numeric, shariah });
  const lastTrades = wf.trades.slice(-10).map(t => ({ sym: t.sym, entry: new Date(P.dates[t.entryIdx]).toISOString().slice(0, 10),
    exit: new Date(P.dates[t.exitIdx]).toISOString().slice(0, 10), ret: r4(t.ret), how: t.how }));
  return { id, name, universe, grid, combos, folds, oos, criteria, equity: sampleEquity(P, wf.days, wf.rets, bench), lastTrades, ...extra };
}

function shariahFor(universe, ctx) {
  if (universe === 'etf') return { ok: false, why: 'صندوق مؤشر (SPY/QQQ) يحوي شركات غير متوافقة؛ البديل المتوافق (SPUS/HLAL) تاريخه أقصر من 10 سنوات' };
  return { ok: true, why: ctx.screen };
}

export function evaluateFamily(P, fam, ctx, log = () => {}) {
  const combos = gridCombos(fam.grid);
  const runs = combos.map(p => { const r = runStrategy(P, fam.make(p)); r.params = p; return r; });
  const start = runs[0].start;
  const wf = walkForward(runs, P.dates, { start });
  const res = summarize(P, ctx, { id: fam.family, name: fam.name, universe: fam.universe, grid: fam.grid, combos: combos.length, wf,
    paramsOf: f => combos[f.chosen], shariah: shariahFor(fam.universe, ctx) });
  // للمعلومة فقط (داخل العينة بالكامل، متفائل): أفضل تركيبة على كل الفترة
  const full = runs.map((r, k) => ({ k, st: returnStats(dailyReturns(r.equity, start + 1, P.D - 1)), n: r.trades.length })).sort((a, b) => b.st.mar - a.st.mar)[0];
  res.bestFullPeriod = { params: combos[full.k], cagr: r4(full.st.cagr), maxDD: r4(full.st.maxDD), mar: r4(full.st.mar), trades: full.n, note: 'داخل العينة — للمقارنة فقط' };
  log(`${fam.family}: ${combos.length} تركيبة، OOS ${pct(res.oos.ret)} MAR ${num(res.oos.mar)} DD ${pct(res.oos.maxDD)} صفقات ${res.oos.trades} — ${res.criteria.score}/7`);
  return { res, runs, wf, start };
}

/* ---------- مزيج بسيط (ensemble) داخل الاختبار الأمامي ---------- */
// لكل سنة خارج العينة: نرتب عائلات الأسهم بدرجة MAR داخل العينة لتركيبتها المختارة، ونأخذ حتى 3 موجبة
// غير مترابطة (ارتباط عوائد يومية داخل العينة < 0.5)، ونقسم رأس المال بينها بالتساوي (توازن يومي).
export function ensembleWalkForward(fams, P, { maxMembers = 3, maxCorr = 0.5 } = {}) {
  const base = fams.filter(f => f.res.universe !== 'etf');
  if (!base.length) return null;
  const nF = base[0].wf.folds.length;
  const yearOf = d => P.years[d];
  const rets = [], years = [], gross = [], turn = [], trades = [], days = [], folds = [];
  const corr = (a, b) => { const n = a.length; let ma = 0, mb = 0; for (let i = 0; i < n; i++) { ma += a[i]; mb += b[i]; } ma /= n; mb /= n;
    let sab = 0, sa = 0, sb = 0; for (let i = 0; i < n; i++) { const x = a[i] - ma, y = b[i] - mb; sab += x * y; sa += x * x; sb += y * y; } return sa > 0 && sb > 0 ? sab / Math.sqrt(sa * sb) : 0; };
  for (let j = 0; j < nF; j++) {
    const f0 = base[0].wf.folds[j];
    const cand = base.map(f => ({ f, fold: f.wf.folds[j] })).filter(x => x.fold && x.fold.isScore > 0).sort((a, b) => b.fold.isScore - a.fold.isScore);
    const picked = [];
    for (const x of cand) {
      if (picked.length >= maxMembers) break;
      const isR = dailyReturns(x.f.runs[x.fold.chosen].equity, x.f.start + 1, f0.from - 1);
      if (picked.every(p => corr(p.isR, isR) < maxCorr)) picked.push({ ...x, isR });
    }
    folds.push({ year: f0.year, from: f0.from, to: f0.to, members: picked.map(p => ({ family: p.f.res.id, params: gridCombos(FAMILIES.find(F => F.family === p.f.res.id).grid)[p.fold.chosen], isScore: r4(p.fold.isScore) })) });
    const k = picked.length;
    for (let d = f0.from; d <= f0.to; d++) {
      let r = 0, g = 0, t = 0;
      for (const p of picked) { const e = p.f.runs[p.fold.chosen]; const a = e.equity[d - 1], b = e.equity[d]; r += a > 0 ? b / a - 1 : 0; g += e.gross[d]; t += e.turn[d]; }
      rets.push(k ? r / k : 0); gross.push(k ? g / k : 0); turn.push(k ? t / k : 0); years.push(yearOf(d)); days.push(d);
    }
    for (const p of picked) for (const t of p.f.runs[p.fold.chosen].trades) if (t.entryIdx >= f0.from && t.entryIdx <= f0.to) trades.push({ ...t, contrib: t.contrib / k, w: t.w / k, fold: f0.year });
  }
  return { folds, rets, years, gross, turn, trades, days };
}

/* ---------- التقرير العربي ---------- */
export function buildReport(out) {
  const L = [];
  const cands = out.candidates;
  L.push('# تقرير البحث — استراتيجيات مضاربة (شراء فقط) على الأسهم الأمريكية', '');
  L.push(`> أُنشئ: ${out.generatedAt} — المصدر: ${out.data.source} — البيانات من ${out.data.from} إلى ${out.data.to} (${num(out.data.years, 1)} سنة)، ${out.data.symbols} سهمًا (large ${out.data.large}، small ${out.data.small}) + SPY/QQQ/IWM.`, '');
  L.push('## الحكم', '', out.verdict, '');
  L.push('## ملخص كل المرشحين (مرتبة بـ MAR خارج العينة)', '');
  L.push('| # | الاستراتيجية | خارج العينة | العائد | CAGR | SPY CAGR | شارب | أقصى تراجع | MAR | صفقات | سنوات رابحة | بعد حذف أفضل صفقتين | الشروط |');
  L.push('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  cands.forEach((c, i) => {
    const o = c.oos;
    L.push(`| ${i + 1} | ${c.name} (\`${c.id}\`) | ${o.from ?? '—'} → ${o.to ?? '—'} | ${pct(o.ret)} | ${pct(o.cagr)} | ${pct(o.bench && o.bench.cagr)} | ${num(o.sharpe)} | ${pct(o.maxDD)} | ${num(o.mar)} | ${o.trades} | ${o.yearsProfitable}/${o.yearsTotal} | ${pct(o.best2Removed)} | ${c.criteria.score}/7${c.criteria.passed ? ' ✅' : ''} |`);
  });
  L.push('');
  L.push('## تفاصيل أفضل 3', '');
  for (const c of cands.slice(0, 3)) {
    const o = c.oos;
    L.push(`### ${c.name} (\`${c.id}\`) — ${c.criteria.score}/7`, '');
    L.push(`- الشبكة: ${c.combos} تركيبة \`${JSON.stringify(c.grid || {})}\``);
    L.push(`- خارج العينة ${o.from} → ${o.to}: عائد ${pct(o.ret)}، CAGR ${pct(o.cagr)}، تذبذب ${pct(o.vol)}، شارب ${num(o.sharpe)}، أقصى تراجع ${pct(o.maxDD)}، MAR ${num(o.mar)}`);
    if (o.bench) L.push(`- SPY على نفس الأيام: عائد ${pct(o.bench.ret)}، CAGR ${pct(o.bench.cagr)}، شارب ${num(o.bench.sharpe)}، أقصى تراجع ${pct(o.bench.maxDD)}، MAR ${num(o.bench.mar)}`);
    L.push(`- الصفقات: ${o.trades}، نسبة الربح ${pct(o.winRate)}، متوسط ${pct(o.avgTrade, 2)}، وسيط ${pct(o.medianTrade, 2)}، معامل الربح ${num(o.profitFactor)}، متوسط الاحتفاظ ${num(o.avgHold, 1)} يوم`);
    L.push(`- التعرض المتوسط ${pct(o.exposure, 0)}، الدوران السنوي ${num(o.turnover, 1)}×، الارتباط مع SPY ${num(o.corrBench)}`);
    L.push('- الاختيار الأمامي (التركيبة المختارة لكل سنة من السنوات السابقة فقط): ' + (c.folds || []).map(f => `${f.year}: \`${JSON.stringify(f.params || f.members)}\``).join('، '));
    L.push('', '| السنة | الاستراتيجية | SPY |', '|---|---|---|');
    for (const y of Object.keys(o.yearly || {})) L.push(`| ${y} | ${pct(o.yearly[y])} | ${pct(o.bench && o.bench.yearly[y])} |`);
    L.push('', 'الشروط:', '');
    for (const k of c.criteria.checks) L.push(`- ${k.ok ? '✅' : '❌'} ${k.id}) ${k.label}: ${k.why}`);
    L.push('');
  }
  L.push('## المنهجية', '');
  L.push('- **الاختبار الأمامي:** لكل سنة تقويمية Y (بعد سنتين تدريب على الأقل) نختار تركيبة المعاملات بأعلى MAR (ثم شارب) على كل الأيام قبل Y فقط (نافذة متوسعة، بحد أدنى 20 صفقة داخل العينة)، ثم نأخذ أداءها في Y. السنوات الخارجية تُوصل ببعضها. سنوات الاختبار لا تدخل أبدًا في الاختيار.');
  L.push('- **التنفيذ:** القرار بعد إغلاق يوم الإشارة والتنفيذ بافتتاح اليوم التالي. استثناءات موثقة: أثر بداية الشهر والاحتفاظ الليلي يشتريان بالإغلاق بقرار تقويمي/ببيانات الأمس (يُعرف قبل الإغلاق). أمر إيقاف الشراء (الاختراق) يُنفّذ عند max(الافتتاح، سعر التفعيل).');
  L.push('- **الوقف:** يُفحص على أدنى اليوم؛ فجوة تحته → التنفيذ بالافتتاح؛ لو لُمس الوقف والهدف بنفس اليوم نفترض الوقف أولاً (تحفّظ). في يوم الدخول بأمر إيقاف (الاختراق) لو لمس أدنى اليوم الوقف نفترض أنه حدث بعد الدخول — تحفّظ يضر عائلة الاختراق عمدًا لأن الشمعة اليومية لا تكشف الترتيب.');
  L.push('- **التكاليف لكل جانب:** 0.05% أساس + حسب متوسط قيمة التداول 20 يومًا (≥100M$: +0، ≥20M$: +0.05%، ≥5M$: +0.15%، ≥1M$: +0.35%، أقل: +0.60%) + للسعر (<5$: +0.20%، <10$: +0.05%).');
  L.push('- **رأس المال:** شراء فقط بالنقد المتاح (بلا رافعة ⇒ تعرض ≤ 100%)، حد أقصى للمراكز لكل استراتيجية، حجم متساوٍ (أو مخفّض حسب التذبذب)، أسهم كسرية مسموحة.');
  L.push(`- **الكون:** ${out.data.universeRule}. داخل الاختبار، «large» في كل يوم = أعلى ${ENGINE_DEFAULTS.largeN} سهم بمتوسط قيمة التداول 60 يومًا حتى ذلك اليوم وسعر ≥ 5$ وتاريخ ≥ 200 يوم.`);
  L.push(`- **الفلتر الشرعي في الاختبار:** ${out.data.screen}. المستبعَد: ${out.data.excluded} سهمًا.`);
  L.push('- **المزيج:** لكل سنة نأخذ حتى 3 عائلات أسهم بأعلى MAR داخل العينة وارتباط < 0.5، بالتساوي.');
  L.push('');
  L.push('## تحفّظات مهمة', '');
  L.push('- **انحياز البقاء:** قائمة NASDAQ Trader وYahoo فيها الأسهم المدرجة حاليًا فقط؛ الشركات التي أفلست أو شُطبت خلال السنوات العشر غائبة، واختيار الكون بسيولة اليوم يستخدم معلومة من المستقبل. هذا يرفع النتائج (خصوصًا للأسهم الصغيرة واستراتيجيات الارتداد). الفلتر اليومي بالسيولة يخفف ولا يلغي.');
  L.push('- **التكاليف:** تقديرية؛ الانزلاق الحقيقي في أيام الذعر أو للأسهم الصغيرة قد يكون أكبر. لا ضرائب ولا فائدة على النقد.');
  L.push('- **مصدر البيانات:** Yahoo Finance بلا مفتاح (أسعار معدّلة للتوزيعات والتقسيمات)؛ قد تحوي أخطاء أو فجوات. القطاعات من Yahoo إن توفرت.');
  L.push('- **الأداء الماضي لا يضمن المستقبل.** هذا بحث تعليمي وليس نصيحة مالية؛ أي استراتيجية ناجحة تمر أولاً على الحساب التجريبي وفق PLAYBOOK.md وبموافقة المالك.');
  L.push('');
  return L.join('\n');
}

/* ---------- التشغيل ---------- */
export async function runResearch({ barsBySym, groups, info = {}, log = console.log, families = FAMILIES, panelOpt = {} }) {
  const T0 = Date.now();
  const P = buildPanel(barsBySym, groups, panelOpt);
  const dataYears = P.D > 1 ? (P.dates[P.D - 1] - P.dates[0]) / (365.25 * 86400000) : 0;
  const ctx = { dataYears, screen: info.screen || 'استبعاد بالاسم فقط' };
  log(`اللوحة: ${P.S} رمزًا × ${P.D} يومًا (${(Date.now() - T0) / 1000} ث)`);
  const fams = [];
  let configs = 0;
  for (const fam of families) {
    const t = Date.now();
    const f = evaluateFamily(P, fam, ctx, log);
    configs += f.res.combos; f.res.seconds = (Date.now() - t) / 1000;
    fams.push(f);
  }
  const candidates = fams.map(f => f.res);
  const ens = ensembleWalkForward(fams, P);
  if (ens && ens.folds.length) {
    const res = summarize(P, ctx, { id: 'ensemble', name: 'مزيج أفضل العائلات غير المترابطة', universe: 'large|small', grid: null, combos: 0,
      wf: ens, paramsOf: f => null, shariah: { ok: true, why: ctx.screen } });
    res.folds = ens.folds.map(f => ({ year: f.year, members: f.members }));
    candidates.push(res);
    log(`ensemble: OOS ${pct(res.oos.ret)} MAR ${num(res.oos.mar)} DD ${pct(res.oos.maxDD)} — ${res.criteria.score}/7`);
  }
  const marKey = c => (c.oos.mar === 'Infinity' ? 1e9 : Number.isFinite(c.oos.mar) ? c.oos.mar : -1e9);
  candidates.sort((a, b) => marKey(b) - marKey(a));
  const passed = candidates.filter(c => c.criteria.passed);
  const closest = [...candidates].sort((a, b) => b.criteria.score - a.criteria.score || marKey(b) - marKey(a))[0];
  const failedOf = c => c.criteria.checks.filter(k => !k.ok).map(k => k.label).join('، ');
  const verdict = passed.length
    ? `«✅ وصلنا لنتيجة ممتازة: ${passed.map(c => `${c.name} (\`${c.id}\`) — CAGR خارج العينة ${pct(c.oos.cagr)} مقابل SPY ${pct(c.oos.bench && c.oos.bench.cagr)}، أقصى تراجع ${pct(c.oos.maxDD)}، ${c.oos.trades} صفقة`).join('؛ ')}»`
    : `«❌ لا توجد استراتيجية تحقق كل الشروط بعد — الأقرب: ${closest ? `${closest.name} (\`${closest.id}\`) ${closest.criteria.score}/7، تفشل في: ${failedOf(closest)}` : '—'}»`;
  const seconds = (Date.now() - T0) / 1000;
  log(`انتهى: ${candidates.length} مرشحًا، ${configs} تركيبة، ${seconds.toFixed(1)} ث`);
  const fmt = t => new Date(t).toISOString().slice(0, 10);
  return {
    generatedAt: new Date().toISOString(), runtimeSec: r4(seconds), configs,
    data: { source: info.source || 'yahoo', from: P.D ? fmt(P.dates[0]) : null, to: P.D ? fmt(P.dates[P.D - 1]) : null, years: r4(dataYears), days: P.D,
      symbols: P.S, large: P.group.filter(g => g === 'large').length, small: P.group.filter(g => g === 'small').length,
      excluded: info.excluded || 0, screen: ctx.screen, universeRule: info.universeRule || '—', fetchedAt: info.fetchedAt || null },
    criteriaRules: CRITERIA, verdict, passed: passed.map(c => c.id), closest: closest ? closest.id : null, candidates,
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
    input = { ...u, info: { source: 'synthetic', screen: 'بيانات اصطناعية', universeRule: 'اصطناعي' } };
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
    input = { barsBySym: d.barsBySym, groups: d.groups,
      info: { source: 'yahoo', screen, excluded: Object.keys(d.excluded).length, universeRule: d.selection.rule, fetchedAt: d.meta.fetchedAt } };
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
