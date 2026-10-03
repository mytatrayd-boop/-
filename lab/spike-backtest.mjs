// انفجار السيولة — الاختبار التاريخي على الشموع اليومية في lab/data/daily (من spike-fetch.mjs).
// 1) كل تركيبات SPIKE_GRID (24): إحصاء الصفقات لكل تركيبة.  2) حساب وهمي بالصيغة الافتراضية.
// 3) اختبار أمامي: نختار التركيبة على الأشهر الأقدم ونقيسها على الأحدث.  4) آخر 10 إشارات وكيف انتهت.
// يكتب lab/results/spike.json و lab/results/SPIKE_REPORT.md (عربي). نفس spikeSignal/spikeTrade اللي يستخدمها التطبيق.
// اصطلاح الأرقام: ret/avgRet/medianRet/worst/best كسور (0.05 = 5%)، و returnPct/maxDrawdownPct نقاط مئوية.
import { readFile, writeFile, readdir, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { SPIKE_DEFAULTS, SPIKE_GRID, spikeSignal, spikeTrade, spikeLookback, marketDays, isoDay } from '../server/spike.js';
import { gridCombos, walkForwardSplit } from './backtest.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const RESULTS = path.join(HERE, 'results');
export const DAILY_DIR = path.join(HERE, 'data', 'daily');
export const SPIKE_ACCOUNT = { start: 10000, maxPositions: 5, positionPct: 0.10, slippage: 0.003 };
export const WF_MIN_TRADES = 20;      // أقل عدد صفقات داخل العينة حتى تُعتبر التركيبة
export const MIN_MARKET_DAYS = 60;    // أقل من كذا يوم سوق = بيانات غير كافية

const round = (x, d = 4) => (x === null || x === undefined || !Number.isFinite(x) ? null : Math.round(x * 10 ** d) / 10 ** d);
export const comboKey = c => `${c.entry}-h${c.hold}-${c.stop ? 'stop' : 'nostop'}-v${c.volMult}`;
export const defaultCombo = (p = SPIKE_DEFAULTS) => ({ entry: p.entry, hold: p.hold, stop: p.stop, volMult: p.volMult });

/* ---------- البيانات ---------- */

async function readJson(file) { try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; } }

// { meta, universe, barsBySym: Map, names: {sym: name} } — الملفات التي تبدأ بـ _ بيانات وصفية
export async function loadDaily(dir = DAILY_DIR) {
  const meta = (await readJson(path.join(dir, '_meta.json'))) || {};
  const universe = await readJson(path.join(dir, '_universe.json'));
  let files = [];
  try { files = (await readdir(dir)).filter(f => f.endsWith('.json') && !f.startsWith('_')); } catch { /* لا بيانات */ }
  const barsBySym = new Map(), names = {};
  for (const f of files.sort()) {
    const sym = f.slice(0, -5);
    const b = await readJson(path.join(dir, f));
    if (b && Array.isArray(b.t) && b.t.length) barsBySym.set(sym, b);
    const n = (meta.symbols && meta.symbols[sym] && meta.symbols[sym].name) || (universe && universe.info && universe.info[sym] && universe.info[sym].name);
    if (n) names[sym] = n;
  }
  return { meta, universe, barsBySym, names };
}

/* ---------- الإشارات والصفقات ---------- */

// كل إشارات كل الأيام بأقل مضاعف حجم في الشبكة (التركيبات الأعلى تفلتر منها)
export function collectSignals(barsBySym, { volMult = Math.min(...SPIKE_GRID.volMult), p = SPIKE_DEFAULTS, commonStocks = null } = {}) {
  const pp = { ...p, volMult }, out = [];
  for (const [sym, b] of barsBySym) {
    if (commonStocks && !commonStocks.has(sym)) continue;
    for (let i = spikeLookback(pp); i < b.c.length; i++) {
      const s = spikeSignal(b, i, pp);
      if (s) out.push({ sym, ...s });
    }
  }
  return out.sort((a, b) => a.t - b.t || b.volRatio - a.volRatio);
}

// صفقات تركيبة واحدة (بدون انزلاق — الانزلاق في الحساب الوهمي فقط)
export function tradesFor(barsBySym, signals, combo, p = SPIKE_DEFAULTS) {
  const pp = { ...p, ...combo }, out = [];
  for (const s of signals) {
    if (s.volRatio < combo.volMult) continue;
    const b = barsBySym.get(s.sym), tr = spikeTrade(b, s.i, pp);
    if (!tr) continue;
    out.push({ sym: s.sym, date: s.date, month: s.date.slice(0, 7), volRatio: s.volRatio, change: s.change,
      entryT: b.t[tr.entryIdx], exitT: b.t[tr.exitIdx], entry: tr.entry, exit: tr.exit, how: tr.how, ret: tr.ret });
  }
  return out;
}

export function median(xs) {
  if (!xs.length) return null;
  const a = [...xs].sort((x, y) => x - y), m = a.length >> 1;
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}

// ملخص قائمة عوائد: صفقات، نسبة الربح، متوسط/وسيط العائد، الأسوأ/الأفضل، نسبة الصفقات الأسوأ من −20%
export function summarize(rets) {
  const n = rets.length;
  if (!n) return { trades: 0, winRate: null, avgRet: null, medianRet: null, worst: null, best: null, below20: null };
  return {
    trades: n, winRate: round(rets.filter(r => r > 0).length / n),
    avgRet: round(rets.reduce((s, r) => s + r, 0) / n, 5), medianRet: round(median(rets), 5),
    worst: round(Math.min(...rets), 5), best: round(Math.max(...rets), 5),
    below20: round(rets.filter(r => r < -0.2).length / n),
  };
}

export function runGrid(barsBySym, signals, grid = SPIKE_GRID, p = SPIKE_DEFAULTS) {
  const rows = [], tradesByKey = {};
  for (const combo of gridCombos(grid)) {
    const key = comboKey(combo), tr = tradesFor(barsBySym, signals, combo, p);
    tradesByKey[key] = tr;
    rows.push({ key, ...combo, ...summarize(tr.map(t => t.ret)) });
  }
  return { rows, tradesByKey };
}

/* ---------- الاختبار الأمامي ---------- */

// أشهر السوق (YYYY-MM) من التقويم بعد فترة الإحماء → الأقدم نصف / الأحدث نصف
export function marketMonths(barsBySym, p = SPIKE_DEFAULTS) {
  const days = marketDays(barsBySym).slice(spikeLookback(p));
  return [...new Set(days.map(t => isoDay(t).slice(0, 7)))];
}

export function walkForward(tradesByKey, months, { minTrades = WF_MIN_TRADES, defaultKey } = {}) {
  const { inSample, outSample } = walkForwardSplit(months);
  const inSet = new Set(inSample), outSet = new Set(outSample);
  const part = (tr, set) => summarize(tr.filter(t => set.has(t.month)).map(t => t.ret));
  const rows = Object.entries(tradesByKey).map(([key, tr]) => ({ key, inS: part(tr, inSet), outS: part(tr, outSet) }));
  const eligible = rows.filter(r => r.inS.trades >= minTrades);
  const pool = eligible.length ? eligible : rows.filter(r => r.inS.trades > 0);
  const best = pool.sort((a, b) => b.inS.avgRet - a.inS.avgRet || b.inS.trades - a.inS.trades || (a.key < b.key ? -1 : 1))[0] || null;
  const def = rows.find(r => r.key === defaultKey) || null;
  const range = m => ({ from: m[0] || null, to: m[m.length - 1] || null, months: m.length });
  return {
    method: `اختيار أعلى متوسط عائد على الأشهر الأقدم بين التركيبات ذات ≥ ${minTrades} صفقة، ثم قياسها على الأشهر الأحدث فقط`,
    minTrades, inSample: range(inSample), outSample: range(outSample), enoughTrades: eligible.length > 0,
    chosen: best ? { key: best.key, inSample: best.inS, outSample: best.outS } : null,
    defaults: def ? { key: def.key, inSample: def.inS, outSample: def.outS } : null,
  };
}

/* ---------- الحساب الوهمي ---------- */

// $10,000، حتى 5 مراكز، كل مركز 10% من الرصيد (المحقق + تكلفة المفتوح)، انزلاق 0.3% لكل جهة، أسهم كاملة.
// إشارات اليوم نفسه بالترتيب: الأعلى مضاعف حجم أولاً. سهم مفتوح لا يُضاف له. الخانة تتحرر بعد إغلاق يوم الخروج.
export function runSpikeAccount(trades, account = {}) {
  const acc = { ...SPIKE_ACCOUNT, ...account };
  const sorted = [...trades].sort((a, b) => a.entryT - b.entryT || b.volRatio - a.volRatio || (a.sym < b.sym ? -1 : 1));
  let cash = acc.start, peak = acc.start, maxDD = 0, skipped = 0;
  const open = [], taken = [], curve = [];
  const equity = () => cash + open.reduce((s, x) => s + x.cost, 0);
  const closeUpTo = t => {
    open.sort((a, b) => a.exitT - b.exitT);
    while (open.length && open[0].exitT < t) {
      const x = open.shift();
      cash += x.proceeds;
      const eq = equity(); peak = Math.max(peak, eq); maxDD = Math.max(maxDD, (peak - eq) / peak);
      curve.push({ date: isoDay(x.exitT), equity: round(eq, 2) });
    }
  };
  for (const tr of sorted) {
    closeUpTo(tr.entryT);
    if (open.length >= acc.maxPositions || open.some(x => x.sym === tr.sym)) { skipped++; continue; }
    const fill = tr.entry * (1 + acc.slippage);
    const shares = Math.floor(Math.min(equity() * acc.positionPct, cash) / fill + 1e-9);
    if (shares < 1) { skipped++; continue; }
    const cost = shares * fill, proceeds = shares * tr.exit * (1 - acc.slippage);
    cash -= cost;
    open.push({ sym: tr.sym, exitT: tr.exitT, cost, proceeds });
    taken.push({ ...tr, shares, pnl: round(proceeds - cost, 2), netRet: round(proceeds / cost - 1, 5) });
  }
  closeUpTo(Infinity);
  const end = cash, wins = taken.filter(t => t.pnl > 0).length;
  return {
    summary: { start: acc.start, end: round(end, 2), returnPct: round((end / acc.start - 1) * 100, 2), maxDrawdownPct: round(maxDD * 100, 2),
      trades: taken.length, winRate: taken.length ? round(wins / taken.length) : null,
      avgNetRet: taken.length ? round(taken.reduce((s, t) => s + t.netRet, 0) / taken.length, 5) : null, skipped,
      maxPositions: acc.maxPositions, positionPct: acc.positionPct, slippage: acc.slippage },
    trades: taken, curve,
  };
}

/* ---------- آخر الإشارات وكيف انتهت ---------- */

export function recentSignals(barsBySym, signals, p = SPIKE_DEFAULTS, n = 10) {
  return signals.filter(s => s.volRatio >= p.volMult).sort((a, b) => b.t - a.t || b.volRatio - a.volRatio).slice(0, n).map(s => {
    const b = barsBySym.get(s.sym), tr = spikeTrade(b, s.i, p);
    const base = { sym: s.sym, date: s.date, close: s.close, change: round(s.change, 4), volRatio: round(s.volRatio, 1), high: s.high, low: s.low };
    if (tr) return { ...base, status: 'done', entry: tr.entry, exit: tr.exit, exitDate: isoDay(b.t[tr.exitIdx]), how: tr.how, ret: round(tr.ret, 5) };
    const noFill = p.entry === 'breakout' && b.c.length > s.i + 1 && b.h[s.i + 1] < s.high;
    return { ...base, status: noFill ? 'no-fill' : 'open', daysSeen: b.c.length - 1 - s.i };
  });
}

/* ---------- التقرير ---------- */

const pc = (x, d = 1) => (x === null || x === undefined ? '—' : `${x > 0 ? '+' : ''}${(x * 100).toFixed(d)}%`);
const rate = x => (x === null || x === undefined ? '—' : `${Math.round(x * 100)}%`);
const ENTRY_AR = { open: 'افتتاح', breakout: 'اختراق' };
const comboAr = r => `${ENTRY_AR[r.entry]} · ${r.hold} أيام · ${r.stop ? 'بوقف' : 'بلا وقف'} · ×${r.volMult}`;
const keyAr = k => { const m = /^(\w+)-h(\d+)-(stop|nostop)-v(\d+)$/.exec(k || ''); return m ? comboAr({ entry: m[1], hold: m[2], stop: m[3] === 'stop', volMult: m[4] }) : k; };
const sumLine = s => s ? `${s.trades} صفقة · ربح ${rate(s.winRate)} · متوسط ${pc(s.avgRet, 2)} · وسيط ${pc(s.medianRet, 2)}` : '—';

export function buildReport(r) {
  const a = r.account, wf = r.walkForward;
  const L = [];
  L.push('# انفجار السيولة — تقرير الاختبار التاريخي', '');
  L.push(`> تاريخ التقرير: ${r.generatedAt.slice(0, 10)} · المصدر: **${r.source || '؟'}** · البيانات ${r.dataFrom || '؟'} → ${r.dataTo || '؟'} · ${r.symbols} سهم · ${r.marketDays} يوم سوق · ${r.signals} إشارة (مضاعف ≥ ×${Math.min(...SPIKE_GRID.volMult)})`, '');
  L.push('**القاعدة:** سهم عادي سعره 0.5–20$، حجم اليوم ≥ 20× متوسط 30 يوم و ≥ 3 ملايين سهم و ≥ 3 ملايين $، ارتفع ≥ 20%، أغلق فوق أعلى إغلاق 40 يوم، وفي أعلى ربع مدى اليوم. شراء فقط، والخروج بالوقت.', '');
  L.push(`## الصيغة الافتراضية (${keyAr(r.defaultKey)})`, '');
  L.push(`- ${sumLine(r.default)} · الأسوأ ${pc(r.default && r.default.worst)} · الأفضل ${pc(r.default && r.default.best)} · أسوأ من −20%: ${rate(r.default && r.default.below20)}`);
  L.push(`- **الحساب الوهمي:** $${a.start.toLocaleString('en-US')} → **$${(a.end ?? 0).toLocaleString('en-US')}** (${a.returnPct ?? '—'}%) · أقصى تراجع ${a.maxDrawdownPct ?? '—'}% · ${a.trades} صفقة · ربح ${rate(a.winRate)} · تُخطّيت ${a.skipped} إشارة (الخانات ممتلئة)`);
  L.push(`  حتى ${a.maxPositions} مراكز، كل مركز ${Math.round(a.positionPct * 100)}% من الرصيد، انزلاق ${(a.slippage * 100).toFixed(1)}% لكل جهة، بدون عمولات.`, '');
  L.push('## كل التركيبات', '');
  L.push('| الدخول | أيام | وقف | مضاعف | صفقات | ربح | متوسط | وسيط | الأسوأ | الأفضل | < −20% |');
  L.push('|---|---|---|---|---|---|---|---|---|---|---|');
  for (const x of r.grid) L.push(`| ${ENTRY_AR[x.entry]} | ${x.hold} | ${x.stop ? 'نعم' : 'لا'} | ×${x.volMult} | ${x.trades} | ${rate(x.winRate)} | ${pc(x.avgRet, 2)} | ${pc(x.medianRet, 2)} | ${pc(x.worst)} | ${pc(x.best)} | ${rate(x.below20)} |`);
  L.push('', '## الاختبار الأمامي (خارج العينة)', '');
  L.push(`- داخل العينة (الأقدم): ${wf.inSample.from || '—'} → ${wf.inSample.to || '—'} (${wf.inSample.months} شهر) · خارجها (الأحدث): ${wf.outSample.from || '—'} → ${wf.outSample.to || '—'} (${wf.outSample.months} شهر)`);
  if (wf.chosen) {
    L.push(`- المختارة على الأقدم: **${keyAr(wf.chosen.key)}** — داخل: ${sumLine(wf.chosen.inSample)}`);
    L.push(`- **نفس التركيبة على الأحدث: ${sumLine(wf.chosen.outSample)}**`);
  } else L.push('- ما فيه صفقات كافية للاختيار.');
  if (wf.defaults) L.push(`- الافتراضية على الأحدث: ${sumLine(wf.defaults.outSample)}`);
  if (!wf.enoughTrades) L.push(`- ⚠️ ولا تركيبة وصلت ${wf.minTrades} صفقة داخل العينة — النتيجة ضعيفة إحصائيًا.`);
  L.push('', '## آخر 10 إشارات وكيف انتهت (الصيغة الافتراضية)', '');
  if (!r.recent.length) L.push('ما فيه إشارات.');
  else {
    L.push('| السهم | يوم الإشارة | التغير | مضاعف الحجم | الإغلاق | النتيجة |', '|---|---|---|---|---|---|');
    for (const s of r.recent) {
      const res = s.status === 'done' ? `${pc(s.ret)} (${s.how === 'stop' ? 'الوقف' : 'الوقت'} ${s.exitDate})` : s.status === 'no-fill' ? 'ما تفعّل الدخول' : `جارية (${s.daysSeen} يوم بعد الإشارة)`;
      L.push(`| ${s.sym} | ${s.date} | ${pc(s.change)} | ×${s.volRatio} | ${s.close} | ${res} |`);
    }
  }
  L.push('', '## تنبيهات بصراحة', '');
  L.push('- **انحياز البقاء:** الأسهم اللي انشطبت من السوق (إفلاس، دمج، شطب) غير موجودة في البيانات — وهي غالبًا من أسوأ الحالات في الأسهم الصغيرة. النتائج الحقيقية على الأغلب أسوأ.');
  L.push('- **الانزلاق:** افترضنا 0.3% لكل جهة. في الأسهم الصغيرة يوم الانفجار وبعده الفارق بين العرض والطلب قد يكون أوسع بكثير، وأمر السوق عند الافتتاح قد يتنفذ بسعر أسوأ بوضوح.');
  L.push('- **الإيقاف عن التداول (halt):** هذي الأسهم تتوقف كثيرًا أثناء اليوم؛ الوقف قد لا يتنفذ عند سعره، والشموع اليومية ما تبين هذا.');
  L.push('- **الطرح والتخفيف:** بعد الانفجار تطرح شركات صغيرة كثيرة أسهمًا جديدة (offering) فينهار السعر فجأة — وهذا يظهر كخسائر كبيرة في الجدول (عمود < −20%).');
  L.push('- **جودة البيانات:** شموع Yahoo اليومية المجانية فيها أحيانًا أخطاء أو أيام ناقصة، وعدّ أيام الاحتفاظ يتم على شموع السهم نفسه.');
  L.push('- العينة ما تضمن المستقبل، والتركيبة المختارة قد تكون محظوظة. **هذا مو نصيحة مالية** — القرار والمخاطرة عليك.');
  return L.join('\n') + '\n';
}

/* ---------- التشغيل الكامل ---------- */

export function runSpikeBacktest({ barsBySym, meta = {}, commonStocks = null, p = SPIKE_DEFAULTS }) {
  const signals = collectSignals(barsBySym, { p, commonStocks });
  const { rows, tradesByKey } = runGrid(barsBySym, signals, SPIKE_GRID, p);
  const defaultKey = comboKey(defaultCombo(p));
  const defTrades = tradesByKey[defaultKey] || tradesFor(barsBySym, signals, defaultCombo(p), p);
  const acc = runSpikeAccount(defTrades);
  const days = marketDays(barsBySym);
  const curve = acc.curve.filter((x, i, a) => i === a.length - 1 || x.date.slice(0, 7) !== a[i + 1].date.slice(0, 7)); // آخر نقطة كل شهر
  return {
    generatedAt: new Date().toISOString(), source: meta.source || null,
    dataFrom: days.length ? isoDay(days[0]) : null, dataTo: days.length ? isoDay(days[days.length - 1]) : null,
    symbols: barsBySym.size, marketDays: days.length, signals: signals.length,
    params: p, gridSpec: SPIKE_GRID, defaultKey,
    grid: rows, default: rows.find(r => r.key === defaultKey) || { key: defaultKey, ...summarize(defTrades.map(t => t.ret)) },
    account: { ...acc.summary, curve },
    walkForward: walkForward(tradesByKey, marketMonths(barsBySym, p), { defaultKey }),
    recent: recentSignals(barsBySym, signals, p, 10),
    trades: acc.trades.map(t => ({ sym: t.sym, date: t.date, entryDate: isoDay(t.entryT), exitDate: isoDay(t.exitT), entry: t.entry, exit: t.exit, how: t.how, ret: round(t.ret, 5), shares: t.shares, pnl: t.pnl })),
  };
}

async function main() {
  const { meta, universe, barsBySym } = await loadDaily();
  const days = marketDays(barsBySym).length;
  if (!barsBySym.size || days < MIN_MARKET_DAYS) {
    console.log(`بيانات يومية غير كافية (${barsBySym.size} سهم، ${days} يوم) — شغّل node lab/spike-fetch.mjs أولًا. تخطّي.`);
    return;
  }
  const commonStocks = universe && Array.isArray(universe.symbols) && meta.source === 'yahoo' ? new Set(universe.symbols) : null;
  const t0 = Date.now();
  const r = runSpikeBacktest({ barsBySym, meta, commonStocks });
  await mkdir(RESULTS, { recursive: true });
  await writeFile(path.join(RESULTS, 'spike.json'), JSON.stringify(r) + '\n');
  await writeFile(path.join(RESULTS, 'SPIKE_REPORT.md'), buildReport(r));
  const d = r.default, a = r.account;
  console.log(`${r.symbols} سهم، ${r.marketDays} يوم، ${r.signals} إشارة، ${Math.round((Date.now() - t0) / 1000)} ث`);
  console.log(`الافتراضية ${r.defaultKey}: ${d.trades} صفقة، ربح ${d.winRate}، متوسط ${d.avgRet}`);
  console.log(`الحساب: ${a.start} → ${a.end} (${a.returnPct}%)، أقصى تراجع ${a.maxDrawdownPct}%`);
  console.log('→ lab/results/spike.json + SPIKE_REPORT.md');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(e => { console.error(e); process.exit(1); });
}
