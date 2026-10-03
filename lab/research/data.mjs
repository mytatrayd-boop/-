// بيانات البحث: ~10 سنوات شموع يومية من Yahoo (بدون مفتاح) لكون واسع من الأسهم الأمريكية العادية + SPY/QQQ/IWM.
// الأسعار معدّلة بالكامل (تقسيمات + توزيعات) عبر adjclose: نسبة adjclose/close تُطبّق على O/H/L/C،
// ونحفظ أيضًا rc = إغلاق Yahoo (معدّل للتقسيم فقط) لحساب قيمة التداول بالدولار وفلاتر السعر.
//
// الخطوات (كلها مخزّنة في lab/data/research/ — مستثناة من git — وتُستأنف لو انقطعت):
//  1) قائمة الرموز من NASDAQ Trader (نفس محلل spike-fetch.mjs) + استبعاد مبدئي بالاسم لقطاعات غير متوافقة.
//  2) ترتيب السيولة: 3 أشهر لكل سهم → وسيط قيمة التداول 60 يومًا (يُعاد كل 28 يومًا).
//  3) الاختيار: أعلى 1500 سهم (سعر ≥ 5$) = «large»، والـ 600 التالية (وسيط ≥ 1M$، سعر ≥ 3$) = «small».
//  4) الشموع: range=10y كاملة أول مرة، ثم تحديث تدريجي range=1mo مع إعادة قياس التعديل (أو تنزيل كامل لو تغيّر داخل النافذة).
//  5) القطاع والصناعة (اختياري): Yahoo quoteSummary assetProfile مرة لكل سهم، إن أمكن الوصول (يحتاج crumb).
// الاستخدام: node lab/research/data.mjs [--limit=N] [--force-rank] [--no-profiles]
// يخرج دائمًا بـ 0؛ الفشل الجزئي يُسجّل. حد زمني داخلي RESEARCH_BUDGET_MIN (افتراضي 280 دقيقة) يحفظ ما نزل ويتوقف.
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseYahooDaily, YAHOO_UA } from '../../server/yahoo.js';
import { etParts } from '../../server/trend.js';
import { buildUniverse, NASDAQ_URLS, getText, getYahooChart, makePacer, runPool, FETCH_DEFAULTS } from '../spike-fetch.mjs';
import { median } from './indicators.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const RESEARCH_DIR = process.env.RASED_RESEARCH_DIR || path.join(HERE, '..', 'data', 'research');
const DAY = 86400000;
export const BENCH = ['SPY', 'QQQ', 'IWM'];
export const DATA_DEFAULTS = {
  largeN: 1500, smallN: 600, largeMinPx: 5, smallMinPx: 3, smallMinMdv: 1e6, mdvDays: 60,
  rankRange: '3mo', rankMaxAgeDays: 28, fullRange: '10y', incRange: '1mo',
  incMaxAgeDays: 20, skipFresherH: 12, keepDays: 11 * 366, profileRetryDays: 30,
  budgetMin: Number(process.env.RESEARCH_BUDGET_MIN) || 280,
};

/* ---------- تحليل صافٍ (مُختبر) ---------- */

// رد Yahoo اليومي → شموع معدّلة بالكامل { t, o, h, l, c, v, rc }
export function parseYahooAdjusted(payload, nowMs = Date.now()) {
  const raw = parseYahooDaily(payload, nowMs);
  const r = payload.chart.result[0];
  const ts = r.timestamp || [], q = (r.indicators.quote || [])[0] || {};
  const adj = ((r.indicators.adjclose || [])[0] || {}).adjclose || [];
  const ratio = new Map();
  for (let i = 0; i < ts.length; i++) {
    const a = adj[i], c = (q.close || [])[i];
    if (a > 0 && c > 0) ratio.set(Date.parse(etParts(ts[i] * 1000).date + 'T00:00:00Z'), a / c);
  }
  const out = { t: [], o: [], h: [], l: [], c: [], v: [], rc: [] };
  let k = 1;
  for (let i = 0; i < raw.t.length; i++) {
    if (ratio.has(raw.t[i])) k = ratio.get(raw.t[i]);
    out.t.push(raw.t[i]); out.o.push(raw.o[i] * k); out.h.push(raw.h[i] * k); out.l.push(raw.l[i] * k); out.c.push(raw.c[i] * k);
    out.v.push(raw.v[i]); out.rc.push(raw.c[i]);
  }
  return out;
}

// دمج تحديث تدريجي مع الكاش: نقيس نسبة التعديل الجديدة على الأيام المشتركة ونعيد قياس الكاش بها.
// لو النسبة غير ثابتة داخل النافذة (توزيع/تقسيم وسطها) أو لا تداخل كافٍ → null (يلزم تنزيل كامل).
export function mergeAdjusted(cached, fresh, tol = 5e-4) {
  if (!cached || !cached.t || !cached.t.length || !fresh || !fresh.t.length) return null;
  const idx = new Map(cached.t.map((t, i) => [t, i]));
  const k = [], kr = [];
  for (let i = 0; i < fresh.t.length; i++) {
    const j = idx.get(fresh.t[i]);
    if (j === undefined || !(cached.c[j] > 0) || !(cached.rc[j] > 0)) continue;
    k.push(fresh.c[i] / cached.c[j]); kr.push(fresh.rc[i] / cached.rc[j]);
  }
  if (k.length < 3) return null;
  const km = median(k), krm = median(kr);
  if (k.some(x => Math.abs(x / km - 1) > tol) || kr.some(x => Math.abs(x / krm - 1) > tol)) return null;
  const out = { t: [], o: [], h: [], l: [], c: [], v: [], rc: [] };
  const first = fresh.t[0];
  for (let j = 0; j < cached.t.length && cached.t[j] < first; j++) {
    out.t.push(cached.t[j]); out.o.push(cached.o[j] * km); out.h.push(cached.h[j] * km); out.l.push(cached.l[j] * km);
    out.c.push(cached.c[j] * km); out.rc.push(cached.rc[j] * krm); out.v.push(cached.v[j] / krm);
  }
  for (const key of Object.keys(out)) out[key].push(...fresh[key]);
  return out;
}

// وسيط قيمة التداول بالدولار لآخر n يوم (إغلاق غير معدّل للتوزيعات × الحجم)
export function medianDollarVolume(bars, n = DATA_DEFAULTS.mdvDays) {
  const rc = bars.rc || bars.c, k = Math.max(0, bars.t.length - n);
  const dv = [];
  for (let i = k; i < bars.t.length; i++) dv.push(rc[i] * bars.v[i]);
  return median(dv);
}

// rows: { sym: { mdv, px } } → { large: [...], small: [...] } بترتيب السيولة
export function selectUniverse(rows, opt = DATA_DEFAULTS) {
  const list = Object.entries(rows).filter(([s, r]) => r && Number.isFinite(r.mdv) && !BENCH.includes(s)).sort((a, b) => b[1].mdv - a[1].mdv || (a[0] < b[0] ? -1 : 1));
  const large = list.filter(([, r]) => r.px >= opt.largeMinPx).slice(0, opt.largeN).map(([s]) => s);
  const inLarge = new Set(large);
  const small = list.filter(([s, r]) => !inLarge.has(s) && r.px >= opt.smallMinPx && r.mdv >= opt.smallMinMdv).slice(0, opt.smallN).map(([s]) => s);
  return { large, small };
}

// استبعاد شرعي مبدئي (للاختبار التاريخي فقط؛ الفحص الحقيقي حيًّا عبر يقين):
// بنوك، تأمين، خمور، قمار، تبغ، رهن عقاري/REIT رهن، وإقراض استهلاكي. بالصناعة إن توفرت، وإلا بالاسم.
const BAD_INDUSTRY = /bank|insurance|brewer|winer|distiller|alcohol|gambling|casino|tobacco|mortgage|credit services/i;
const BAD_NAME = /\b(banc(orp|shares|orporation)?|bank|bankshares|insurance|assurance|reinsurance|casinos?|gaming|tobacco|brewing|brewery|distillery|distilling|winery|wines?|spirits|mortgage)\b/i;
export function shariahExcluded({ name, sector, industry } = {}) {
  if (industry && BAD_INDUSTRY.test(industry)) return 'industry: ' + industry;
  if (sector && /financial/i.test(sector) && industry && /bank|insurance|mortgage|credit/i.test(industry)) return 'sector: ' + sector;
  if (name && BAD_NAME.test(name)) return 'name: ' + name;
  return null;
}

export function parseAssetProfile(payload) {
  const qs = payload && payload.quoteSummary;
  if (!qs) throw new Error('رد quoteSummary غير متوقع');
  if (qs.error) throw new Error('quoteSummary: ' + (qs.error.description || qs.error.code));
  const a = qs.result && qs.result[0] && qs.result[0].assetProfile;
  if (!a) throw new Error('بدون assetProfile');
  return { sector: a.sector || null, industry: a.industry || null };
}

/* ---------- التخزين ---------- */
const barsDir = (dir = RESEARCH_DIR) => path.join(dir, 'bars');
async function readJson(file) { try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; } }
const fileOf = (sym, dir) => path.join(barsDir(dir), sym.replace(/[^A-Z0-9.-]/gi, '_') + '.json');

// تحميل ما في الكاش لـ run.mjs: { barsBySym: Map, groups, names, profiles, excluded, selection, meta }
export async function loadResearchData(dir = RESEARCH_DIR) {
  const selection = await readJson(path.join(dir, '_selection.json'));
  const meta = (await readJson(path.join(dir, '_meta.json'))) || {};
  const profiles = (await readJson(path.join(dir, '_profiles.json'))) || {};
  const uni = (await readJson(path.join(dir, '_universe.json'))) || {};
  const barsBySym = new Map(), groups = {}, names = {}, excluded = {};
  if (!selection) return { barsBySym, groups, names, profiles, excluded, selection: null, meta };
  const want = [...BENCH.map(s => [s, 'bench']), ...selection.large.map(s => [s, 'large']), ...selection.small.map(s => [s, 'small'])];
  for (const [sym, g] of want) {
    const name = (uni.info && uni.info[sym] && uni.info[sym].name) || null;
    const pr = profiles[sym] && !profiles[sym].err ? profiles[sym] : {};
    if (g !== 'bench') { const why = shariahExcluded({ name, sector: pr.sector, industry: pr.industry }); if (why) { excluded[sym] = why; continue; } }
    const b = await readJson(fileOf(sym, dir));
    if (!b || !Array.isArray(b.t) || b.t.length < 30) continue;
    barsBySym.set(sym, b); groups[sym] = g; if (name) names[sym] = name;
  }
  return { barsBySym, groups, names, profiles, excluded, selection, meta };
}

/* ---------- الشبكة ---------- */

async function yahooSession() {
  const r1 = await fetch('https://fc.yahoo.com/', { headers: { 'User-Agent': YAHOO_UA }, redirect: 'manual', signal: AbortSignal.timeout(20000) });
  const sc = typeof r1.headers.getSetCookie === 'function' ? r1.headers.getSetCookie() : [r1.headers.get('set-cookie')].filter(Boolean);
  const cookie = sc.map(x => String(x).split(';')[0]).join('; ');
  const r2 = await fetch('https://query2.finance.yahoo.com/v1/test/getcrumb', { headers: { 'User-Agent': YAHOO_UA, Cookie: cookie }, signal: AbortSignal.timeout(20000) });
  const crumb = (await r2.text()).trim();
  if (!r2.ok || !crumb || crumb.length > 64 || /[<{\s]/.test(crumb)) throw new Error('تعذّر الحصول على crumb (HTTP ' + r2.status + ')');
  return { cookie, crumb };
}

async function fetchProfile(sym, sess, pace) {
  for (let a = 0; a < 3; a++) {
    await pace();
    try {
      const url = `https://query2.finance.yahoo.com/v10/finance/quoteSummary/${encodeURIComponent(sym.replace(/\./g, '-'))}?modules=assetProfile&crumb=${encodeURIComponent(sess.crumb)}`;
      const res = await fetch(url, { headers: { 'User-Agent': YAHOO_UA, Cookie: sess.cookie, Accept: 'application/json' }, signal: AbortSignal.timeout(30000) });
      if (res.status === 429 || res.status >= 500) { await new Promise(r => setTimeout(r, 3000 * 2 ** a)); continue; }
      return parseAssetProfile(await res.json());
    } catch (e) { if (a === 2) throw e; }
  }
  throw new Error('rate limited');
}

export async function main(args) {
  const T0 = Date.now(), opt = DATA_DEFAULTS;
  const overBudget = () => Date.now() - T0 > opt.budgetMin * 60000;
  const limit = Number((args.find(a => a.startsWith('--limit=')) || '').slice(8)) || 0;
  await mkdir(barsDir(), { recursive: true });
  const pace = makePacer(FETCH_DEFAULTS.gapMs), net = { pace };
  const conc = FETCH_DEFAULTS.concurrency;

  // 1) قائمة الرموز
  const uniFile = path.join(RESEARCH_DIR, '_universe.json');
  let uni;
  try {
    const [a, b] = await Promise.all([getText(NASDAQ_URLS.nasdaq), getText(NASDAQ_URLS.other)]);
    uni = buildUniverse(a, b);
    if (uni.symbols.length < 2000) throw new Error(`قائمة ناقصة (${uni.symbols.length})`);
    await writeFile(uniFile, JSON.stringify({ at: new Date().toISOString(), ...uni }));
  } catch (e) {
    uni = await readJson(uniFile);
    if (!uni) { console.log('تعذّر تنزيل قائمة الرموز ولا توجد نسخة محفوظة: ' + e.message); return; }
    console.log('نستخدم قائمة الرموز المحفوظة: ' + e.message);
  }
  let symbols = uni.symbols.filter(s => !shariahExcluded({ name: (uni.info[s] || {}).name }));
  if (limit) symbols = symbols.slice(0, limit);
  console.log(`قائمة NASDAQ Trader: ${uni.symbols.length} سهم عادي، بعد الاستبعاد بالاسم ${symbols.length}`);

  // 2) ترتيب السيولة
  const rankFile = path.join(RESEARCH_DIR, '_rank.json');
  let rank = await readJson(rankFile);
  if (args.includes('--force-rank') || !rank || Date.now() - rank.at > opt.rankMaxAgeDays * DAY || (rank.partial && !limit)) {
    const rows = (rank && rank.partial && rank.rows) || {};
    const todo = symbols.filter(s => !rows[s]);
    let done = 0, failed = 0;
    console.log(`ترتيب السيولة: ${todo.length} سهم (range=${opt.rankRange})`);
    await runPool(todo, async sym => {
      if (overBudget()) return;
      try {
        const b = parseYahooAdjusted(await getYahooChart(sym, `interval=1d&range=${opt.rankRange}&includePrePost=false`, net));
        if (b.t.length >= 20) rows[sym] = { mdv: medianDollarVolume(b), px: b.rc[b.rc.length - 1], n: b.t.length };
      } catch { failed++; }
      if (++done % 500 === 0) console.log(`  ${done}/${todo.length} (فشل ${failed})`);
    }, conc);
    rank = { at: Date.now(), partial: overBudget(), rows };
    await writeFile(rankFile, JSON.stringify(rank));
    console.log(`ترتيب السيولة: ${Object.keys(rows).length} سهم مقاس، فشل ${failed}`);
  }

  // 3) الاختيار
  const sel = selectUniverse(rank.rows, opt);
  await writeFile(path.join(RESEARCH_DIR, '_selection.json'), JSON.stringify({ at: new Date().toISOString(), rankAt: new Date(rank.at).toISOString(), ...sel,
    rule: `large = أعلى ${opt.largeN} بوسيط قيمة التداول ${opt.mdvDays} يومًا (سعر ≥ ${opt.largeMinPx}$)، small = التالية حتى ${opt.smallN} (وسيط ≥ ${opt.smallMinMdv / 1e6}M$، سعر ≥ ${opt.smallMinPx}$)` }));
  console.log(`الاختيار: large ${sel.large.length}، small ${sel.small.length}`);

  // 4) الشموع (10 سنوات)
  const metaFile = path.join(RESEARCH_DIR, '_meta.json');
  const meta = (await readJson(metaFile)) || { symbols: {} };
  const all = [...BENCH, ...sel.large, ...sel.small];
  const stats = { full: 0, incremental: 0, skip: 0, failed: 0, notReached: 0 }, failures = {};
  let n = 0;
  await runPool(all, async sym => {
    if (overBudget()) { stats.notReached++; return; }
    const e = meta.symbols[sym], age = e ? Date.now() - e.at : Infinity;
    try {
      if (age < opt.skipFresherH * 3600e3) { stats.skip++; return; }
      const file = fileOf(sym);
      let bars = null, mode = 'full';
      if (age < opt.incMaxAgeDays * DAY) {
        const cached = await readJson(file);
        const inc = parseYahooAdjusted(await getYahooChart(sym, `interval=1d&range=${opt.incRange}&includePrePost=false`, net));
        bars = mergeAdjusted(cached, inc);
        if (bars) mode = 'incremental';
      }
      if (!bars) bars = parseYahooAdjusted(await getYahooChart(sym, `interval=1d&range=${opt.fullRange}&includePrePost=false`, net));
      const cut = Date.now() - opt.keepDays * DAY, i0 = bars.t.findIndex(t => t >= cut);
      if (i0 > 0) for (const k of Object.keys(bars)) bars[k] = bars[k].slice(i0);
      if (!bars.t.length) throw new Error('بدون شموع');
      await writeFile(file, JSON.stringify(bars));
      meta.symbols[sym] = { at: Date.now(), bars: bars.t.length, first: new Date(bars.t[0]).toISOString().slice(0, 10), last: new Date(bars.t[bars.t.length - 1]).toISOString().slice(0, 10) };
      stats[mode]++;
    } catch (err) { stats.failed++; failures[sym] = String(err.message).slice(0, 120); }
    if (++n % 250 === 0) { console.log(`  شموع ${n}/${all.length} — ${JSON.stringify(stats)}`); await writeFile(metaFile, JSON.stringify(meta)); }
  }, conc);
  Object.assign(meta, { fetchedAt: new Date().toISOString(), source: 'yahoo', stats, failures });
  await writeFile(metaFile, JSON.stringify(meta));
  console.log(`الشموع: ${JSON.stringify(stats)}`);

  // 5) القطاع والصناعة (اختياري)
  if (args.includes('--no-profiles') || process.env.RESEARCH_PROFILES === '0') return;
  const profFile = path.join(RESEARCH_DIR, '_profiles.json');
  const profiles = (await readJson(profFile)) || {};
  const need = all.filter(s => !BENCH.includes(s) && (!profiles[s] || (profiles[s].err && Date.now() - profiles[s].at > opt.profileRetryDays * DAY)));
  if (!need.length || overBudget()) return;
  let sess;
  try { sess = await yahooSession(); } catch (e) { console.log('القطاعات غير متاحة: ' + e.message + ' — نكتفي بالاستبعاد بالاسم.'); return; }
  let ok = 0, bad = 0, k = 0;
  console.log(`القطاعات: ${need.length} سهم`);
  await runPool(need, async sym => {
    if (overBudget() || (bad >= 25 && ok === 0)) return;
    try { profiles[sym] = { ...(await fetchProfile(sym, sess, pace)), at: Date.now() }; ok++; }
    catch (e) { profiles[sym] = { err: String(e.message).slice(0, 80), at: Date.now() }; bad++; }
    if (++k % 250 === 0) await writeFile(profFile, JSON.stringify(profiles));
  }, conc);
  await writeFile(profFile, JSON.stringify(profiles));
  console.log(`القطاعات: نجح ${ok}، فشل ${bad}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(e => { console.error('تعذّر تنزيل بيانات البحث: ' + e.message); process.exit(0); });
}
