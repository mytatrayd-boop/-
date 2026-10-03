// محرك اختبار تاريخي يومي على مستوى المحفظة (حدثي): مراكز، نقد، حد أقصى للمراكز، تحجيم، تكاليف،
// دخول/خروج بالافتتاح أو الإغلاق، وقف وهدف يُفحصان على مدى اليوم بتحفّظ، وخروج بالوقت.
// شراء فقط، بلا رافعة: لا يُشترى إلا بالنقد المتاح ⇒ التعرض الإجمالي ≤ 100% من رأس المال دائمًا.
//
// ترتيب اليوم d (لا نظر للمستقبل):
//  1) الافتتاح: تُنفّذ أوامر قرارات إغلاق d-1 — الخروج أولاً ثم الدخول (بسعر الافتتاح، أو بأمر إيقاف شراء trigger).
//  2) أثناء اليوم: الوقف/الهدف على أدنى/أعلى اليوم. فجوة تحت الوقف → التنفيذ بالافتتاح. لو لُمس الاثنان → الوقف أولاً.
//  3) الإغلاق: خروج بالوقت (exitAt='close')، خروج إجباري عند آخر شمعة للسهم، ثم دخول بالإغلاق (entryAt='close')
//     بقرار يستخدم بيانات حتى d-1 فقط + التقويم (score(d-1, s, d)). ثم تقييم المحفظة بإغلاق d.
//  4) بعد الإغلاق: قرارات الغد — إشارات خروج، وإشارات دخول score(d, s) ببيانات حتى d.
import { sma, rsi, atr, rollingMax, rollingMin, ret, realizedVol, ibs, downStreak, nr7, insideDay, avgDollarVol } from './indicators.mjs';

export const ENGINE_DEFAULTS = {
  start: 100000,        // رأس مال افتراضي (النتائج نسبية؛ الأسهم الكسرية مسموحة)
  warmup: 252,          // أول يوم تداول = بعد سنة من بداية البيانات (المؤشرات تحتاج تاريخًا)
  largeN: 500,          // كون «large»: أعلى 500 سهم بمتوسط قيمة التداول 60 يوم في ذلك اليوم (لا يستخدم المستقبل)
  largeMinPrice: 5,
  smallMinPrice: 3, smallMinAdv: 1e6,
  minHistory: 200,      // أقل عدد أيام تاريخ للسهم قبل أن يدخل الكون
};

/* ---------- التكاليف ---------- */
// تكلفة الجانب الواحد (كسر): 0.05% أساس (عمولة+نصف فارق سعر لأسهم شديدة السيولة)،
// + حسب السيولة (متوسط قيمة التداول 20 يوم حتى يوم القرار)، + للأسعار المنخفضة.
export function costRate(price, adv) {
  let bps = 5;
  if (!(adv >= 1e8)) bps += adv >= 2e7 ? 5 : adv >= 5e6 ? 15 : adv >= 1e6 ? 35 : 60;
  if (price < 5) bps += 20; else if (price < 10) bps += 5;
  return bps / 1e4;
}

/* ---------- اللوحة (panel): كل الأسهم على تقويم واحد ---------- */
const nanArr = n => new Float64Array(n).fill(NaN);

// barsBySym: Map|obj sym → {t,o,h,l,c,v,rc?}. groups: sym → 'large'|'small'|'bench'.
// التقويم الرئيسي = أيام SPY (أو اتحاد كل الأيام لو SPY غير موجود). الفجوات الداخلية تُملأ بإغلاق الأمس وحجم 0.
export function buildPanel(barsBySym, groups = {}, opt = {}) {
  const entries = barsBySym instanceof Map ? [...barsBySym] : Object.entries(barsBySym);
  const cal = opt.calendarSym || 'SPY';
  let tset;
  const spy = entries.find(([s]) => s === cal);
  if (spy) tset = spy[1].t.slice();
  else { const u = new Set(); for (const [, b] of entries) for (const t of b.t) u.add(t); tset = [...u].sort((a, b) => a - b); }
  const D = tset.length, pos = new Map(tset.map((t, i) => [t, i]));
  const dates = Float64Array.from(tset);
  const years = new Int16Array(D), months = new Int8Array(D), wdays = new Int8Array(D);
  for (let i = 0; i < D; i++) { const dt = new Date(tset[i]); years[i] = dt.getUTCFullYear(); months[i] = dt.getUTCMonth(); wdays[i] = dt.getUTCDay(); }
  const P = { D, dates, years, months, wdays, syms: [], group: [], o: [], h: [], l: [], c: [], v: [], rc: [], first: [], last: [], sector: [],
    cache: new Map(), opt: { ...ENGINE_DEFAULTS, ...opt }, index: new Map() };
  for (const [sym, b] of entries) {
    const o = nanArr(D), h = nanArr(D), l = nanArr(D), c = nanArr(D), v = nanArr(D), rc = nanArr(D);
    let first = -1, last = -1;
    for (let i = 0; i < b.t.length; i++) {
      const k = pos.get(b.t[i]);
      if (k === undefined) continue;
      o[k] = b.o[i]; h[k] = b.h[i]; l[k] = b.l[i]; c[k] = b.c[i]; v[k] = b.v[i] || 0;
      rc[k] = b.rc ? b.rc[i] : b.c[i];
      if (first < 0 || k < first) first = k;
      if (k > last) last = k;
    }
    if (first < 0) continue;
    for (let k = first + 1; k <= last; k++) if (!Number.isFinite(c[k])) { o[k] = h[k] = l[k] = c[k] = c[k - 1]; rc[k] = rc[k - 1]; v[k] = 0; }
    const s = P.syms.length;
    P.syms.push(sym); P.group.push(groups[sym] || 'large');
    P.o.push(o); P.h.push(h); P.l.push(l); P.c.push(c); P.v.push(v); P.rc.push(rc); P.first.push(first); P.last.push(last);
    P.index.set(sym, s);
    P.sector.push((opt.sectors && opt.sectors[sym]) || null);
  }
  P.S = P.syms.length;
  P.series = key => series(P, key);
  P.universe = name => universe(P, name);
  P.sym = name => P.index.has(name) ? P.index.get(name) : -1;
  return P;
}

// مؤشر لكل الأسهم مرة واحدة (مخزّن). المفتاح 'اسم:معامل' مثل 'sma:200' و 'rsi:2' و 'ret:5'.
function series(P, key) {
  if (P.cache.has(key)) return P.cache.get(key);
  const [name, a] = key.split(':'); const n = Number(a);
  const out = new Array(P.S);
  for (let s = 0; s < P.S; s++) {
    const o = P.o[s], h = P.h[s], l = P.l[s], c = P.c[s], v = P.v[s];
    switch (name) {
      case 'sma': out[s] = sma(c, n); break;
      case 'rsi': out[s] = rsi(c, n); break;
      case 'atr': out[s] = atr(h, l, c, n); break;
      case 'ret': out[s] = ret(c, n); break;
      case 'hi': out[s] = rollingMax(c, n); break;       // أعلى إغلاق n يوم
      case 'hh': out[s] = rollingMax(h, n); break;       // أعلى سعر n يوم
      case 'll': out[s] = rollingMin(l, n); break;       // أدنى سعر n يوم
      case 'vol': out[s] = realizedVol(c, n); break;
      case 'adv': out[s] = avgDollarVol(P.rc[s], v, n); break;
      case 'vavg': out[s] = sma(v, n); break;
      case 'ibs': out[s] = ibs(h, l, c); break;
      case 'down': out[s] = downStreak(c); break;
      case 'nr7': out[s] = nr7(h, l); break;
      case 'inside': out[s] = insideDay(h, l); break;
      case 'gap': { const g = nanArr(P.D); for (let i = 1; i < P.D; i++) if (c[i - 1] > 0) g[i] = o[i] / c[i - 1] - 1; out[s] = g; break; }
      default: throw new Error('مؤشر غير معروف: ' + key);
    }
  }
  P.cache.set(key, out);
  return out;
}

// أهلية كل سهم كل يوم (Uint8Array لكل سهم) + قائمة الأسهم المرشحة. تُبنى من بيانات حتى اليوم نفسه فقط.
function universe(P, name) {
  const key = 'U:' + (Array.isArray(name) ? name.join(',') : name);
  if (P.cache.has(key)) return P.cache.get(key);
  const o = P.opt, el = new Array(P.S).fill(null), members = [];
  if (Array.isArray(name)) {
    for (const sym of name) {
      const s = P.sym(sym); if (s < 0) continue;
      const e = new Uint8Array(P.D); for (let d = P.first[s]; d <= P.last[s]; d++) e[d] = 1;
      el[s] = e; members.push(s);
    }
  } else if (name === 'large') {
    const adv = P.series('adv:60'), cand = [];
    for (let s = 0; s < P.S; s++) if (P.group[s] === 'large') { cand.push(s); el[s] = new Uint8Array(P.D); }
    const buf = new Float64Array(cand.length);
    for (let d = 0; d < P.D; d++) {
      let k = 0;
      for (const s of cand) {
        const a = adv[s][d];
        if (Number.isFinite(a) && P.rc[s][d] >= o.largeMinPrice && d - P.first[s] >= o.minHistory) buf[k++] = a;
      }
      if (!k) continue;
      let thr = -Infinity;
      if (k > o.largeN) { const arr = buf.subarray(0, k).slice().sort(); thr = arr[k - o.largeN]; }
      for (const s of cand) {
        const a = adv[s][d];
        if (Number.isFinite(a) && a >= thr && P.rc[s][d] >= o.largeMinPrice && d - P.first[s] >= o.minHistory) el[s][d] = 1;
      }
    }
    members.push(...cand);
  } else if (name === 'small') {
    const adv = P.series('adv:20');
    for (let s = 0; s < P.S; s++) if (P.group[s] === 'small') {
      const e = new Uint8Array(P.D);
      for (let d = P.first[s]; d <= P.last[s]; d++) if (adv[s][d] >= o.smallMinAdv && P.rc[s][d] >= o.smallMinPrice && d - P.first[s] >= o.minHistory) e[d] = 1;
      el[s] = e; members.push(s);
    }
  } else throw new Error('كون غير معروف: ' + name);
  const u = { el, members };
  P.cache.set(key, u);
  return u;
}

/* ---------- المحاكاة ---------- */
// cfg: { universe, maxPositions, sizing: 'equal' | {vol: هدف التذبذب السنوي لكل مركز}, entryAt: 'open'|'close'|'stop',
//        exitAt: 'open'|'close', hold, stopPct, stopAtr, targetPct, regime(d) → bool, rebalance(d) → bool,
//        score(d, s, dFill) → رقم|{score, stop, target, trigger}|null, exitSignal(d, s, pos) → bool, init(P) }
export function runStrategy(P, cfg, opt = {}) {
  const o0 = { ...P.opt, ...opt };
  const D = P.D, start = Math.min(o0.warmup, D - 1);
  if (cfg.init) cfg.init(P);
  const U = P.universe(cfg.universe), members = U.members, el = U.el;
  const maxPos = cfg.maxPositions || 5, entryAt = cfg.entryAt || 'open', exitAt = cfg.exitAt || 'open';
  const hold = Number.isFinite(cfg.hold) ? cfg.hold : null;
  const adv20 = P.series('adv:20'), atr14 = cfg.stopAtr || cfg.trailAtr ? P.series('atr:14') : null, vol20 = cfg.sizing && cfg.sizing.vol ? P.series('vol:20') : null;
  const equity = nanArr(D), gross = new Float64Array(D), turn = new Float64Array(D);
  const trades = [], positions = new Map(); // s → pos
  let cash = o0.start, eqPrev = o0.start, pendingExits = [], pendingEntries = [];
  // السعر والسيولة من يوم القرار (d-1) — لا نستخدم إغلاق يوم التنفيذ. opt.flatCost (للاختبارات) يثبّت التكلفة.
  const costAt = Number.isFinite(o0.flatCost) ? () => o0.flatCost : (s, d) => costRate(P.rc[s][Math.max(0, d - 1)], adv20[s][Math.max(0, d - 1)]);

  const sell = (pos, d, px, how) => {
    const s = pos.s, r = costAt(s, d);
    const proceeds = pos.shares * px * (1 - r);
    cash += proceeds; turn[d] += pos.shares * px;
    const pnl = proceeds - pos.cost;
    trades.push({ s, sym: P.syms[s], entryIdx: pos.entryIdx, exitIdx: d, entry: pos.entry, exit: px, shares: pos.shares,
      cost: pos.cost, pnl, ret: pnl / pos.cost, w: pos.cost / pos.eqAtEntry, contrib: pnl / pos.eqAtEntry, how });
    positions.delete(s);
  };
  const buy = (s, d, px, sig, eqRef) => {
    // الوزن: من الإشارة (sig.w — مثل سلة أساسية بأوزان مختلفة) وإلا 1 ÷ الحد الأقصى للمراكز
    let w = sig && Number.isFinite(sig.w) ? sig.w : 1 / maxPos;
    if (vol20) { const sv = vol20[s][d - 1]; if (sv > 0) w *= Math.min(1, cfg.sizing.vol / sv); }
    const r = costAt(s, d);
    let value = Math.min(eqRef * w, cash);
    // سقف القطاع: قيمة مراكز نفس القطاع (بآخر سعر) + الجديد ≤ sectorCap × رأس المال. قطاع مجهول = بلا سقف.
    if (cfg.sectorCap && P.sector[s]) {
      let inSec = 0;
      for (const q of positions.values()) if (P.sector[q.s] === P.sector[s]) inSec += q.shares * q.last;
      value = Math.min(value, cfg.sectorCap * eqRef - inSec);
    }
    if (!(value > eqRef * 1e-4) || !(px > 0)) return false;
    const shares = value / (px * (1 + r));
    cash -= value; turn[d] += shares * px;
    let stop = sig && Number.isFinite(sig.stop) ? sig.stop : null;
    if (stop === null && cfg.stopPct) stop = px * (1 - cfg.stopPct);
    if (stop === null && atr14 && cfg.stopAtr) { const a = atr14[s][sig && sig.d >= 0 ? sig.d : d - 1]; if (a > 0) stop = px - cfg.stopAtr * a; }
    let target = sig && Number.isFinite(sig.target) ? sig.target : null;
    if (target === null && cfg.targetPct) target = px * (1 + cfg.targetPct);
    positions.set(s, { s, shares, entry: px, cost: value, entryIdx: d, eqAtEntry: eqRef, stop, target, last: px, at: entryAt, hiClose: px });
    return true;
  };
  const norm = (r, d) => r === null || r === undefined || r === false ? null
    : typeof r === 'number' ? (Number.isFinite(r) ? { score: r, d } : null) : { ...r, d };

  for (let d = start; d < D; d++) {
    // 1) الافتتاح
    if (pendingExits.length) {
      for (const pos of pendingExits) if (positions.get(pos.s) === pos) {
        const px = P.o[pos.s][d];
        sell(pos, d, Number.isFinite(px) ? px : pos.last, pos.exitHow || 'signal');
      }
      pendingExits = [];
    }
    if (pendingEntries.length) {
      for (const sig of pendingEntries) {
        if (positions.size >= maxPos) break;
        const s = sig.s;
        if (positions.has(s) || !(d <= P.last[s])) continue;
        const op = P.o[s][d];
        if (!Number.isFinite(op)) continue;
        let px = op;
        if (entryAt === 'stop') { if (!(P.h[s][d] >= sig.trigger)) continue; px = Math.max(op, sig.trigger); }
        buy(s, d, px, sig, eqPrev);
      }
      pendingEntries = [];
    }
    // 2) أثناء اليوم: الوقف ثم الهدف
    for (const pos of [...positions.values()]) {
      const s = pos.s;
      if (pos.entryIdx === d && pos.at === 'close') continue;
      const op = P.o[s][d], lo = P.l[s][d], hi = P.h[s][d];
      if (!Number.isFinite(lo)) continue;
      const fresh = pos.entryIdx === d; // دخل اليوم: الافتتاح هو سعر الدخول فلا فجوة
      if (pos.stop !== null && lo <= pos.stop) { sell(pos, d, !fresh && op <= pos.stop ? op : pos.stop, 'stop'); continue; }
      if (pos.target !== null && hi >= pos.target) sell(pos, d, !fresh && op >= pos.target ? op : pos.target, 'target');
    }
    // 3) الإغلاق
    for (const pos of [...positions.values()]) {
      const s = pos.s, c = P.c[s][d];
      if (exitAt === 'close' && hold !== null && d >= pos.entryIdx + hold && !(pos.at === 'close' && pos.entryIdx === d && hold > 0)) sell(pos, d, c, 'time');
      else if (d >= P.last[s]) sell(pos, d, Number.isFinite(c) ? c : pos.last, 'end');
    }
    if (entryAt === 'close' && d > start && (!cfg.regime || cfg.regime(d - 1))) {
      const cands = [];
      for (const s of members) {
        if (!el[s][d] || !el[s][d - 1] || positions.has(s)) continue;
        const sig = norm(cfg.score(d - 1, s, d), d - 1);
        if (sig) { sig.s = s; cands.push(sig); }
      }
      cands.sort((a, b) => b.score - a.score);
      for (const sig of cands) { if (positions.size >= maxPos) break; buy(sig.s, d, P.c[sig.s][d], sig, eqPrev); }
    }
    // التقييم
    let mv = 0;
    for (const pos of positions.values()) { const c = P.c[pos.s][d]; if (Number.isFinite(c)) pos.last = c; mv += pos.shares * pos.last; }
    // وقف متحرك بـ ATR: بعد الإغلاق (بيانات حتى d) يُرفع الوقف إلى أعلى إغلاق منذ الدخول − k×ATR، ولا ينزل أبدًا؛ يُفحص من الغد
    if (cfg.trailAtr) for (const pos of positions.values()) {
      if (pos.last > pos.hiClose) pos.hiClose = pos.last;
      const a = atr14[pos.s][d];
      if (a > 0) { const st = pos.hiClose - cfg.trailAtr * a; if (pos.stop === null || st > pos.stop) pos.stop = st; }
    }
    const eq = cash + mv;
    equity[d] = eq; gross[d] = eq > 0 ? mv / eq : 0; turn[d] = eqPrev > 0 ? turn[d] / eqPrev : 0;
    eqPrev = eq;
    if (d === D - 1) break;
    // 4) قرارات الغد
    const exiting = new Set();
    if (exitAt === 'open') for (const pos of positions.values()) {
      const timeUp = hold !== null && d + 1 >= pos.entryIdx + hold;
      if (timeUp || (cfg.exitSignal && cfg.exitSignal(d, pos.s, pos))) { pos.exitHow = timeUp ? 'time' : 'signal'; pendingExits.push(pos); exiting.add(pos.s); }
    }
    const regimeOk = !cfg.regime || cfg.regime(d);
    if (cfg.rebalance) {
      if (!cfg.rebalance(d)) continue;
      const cands = [];
      if (regimeOk) for (const s of members) {
        if (!el[s][d]) continue;
        const sig = norm(cfg.score(d, s), d);
        if (sig) { sig.s = s; cands.push(sig); }
      }
      cands.sort((a, b) => b.score - a.score);
      // مع سقف القطاع: نختار الهدف بحد أقصى floor(سقف × عدد المراكز) سهمًا لكل قطاع معروف
      let top = cands.slice(0, maxPos);
      if (cfg.select) top = cfg.select(d, cands).slice(0, maxPos); // اختيار مخصّص (عدد/أوزان/قطاعات) من المرشحين المرتبين
      else if (cfg.sectorCap) {
        const per = Math.max(1, Math.floor(cfg.sectorCap * maxPos + 1e-9)), cnt = new Map(); top = [];
        for (const x of cands) {
          if (top.length >= maxPos) break;
          const sec = P.sector[x.s];
          if (sec) { const k = cnt.get(sec) || 0; if (k >= per) continue; cnt.set(sec, k + 1); }
          top.push(x);
        }
      }
      const target = new Set(top.map(x => x.s));
      for (const pos of positions.values()) if (!target.has(pos.s) && !exiting.has(pos.s)) { pos.exitHow = 'rebalance'; pendingExits.push(pos); exiting.add(pos.s); }
      pendingEntries = top.filter(x => !positions.has(x.s));
      continue;
    }
    if (entryAt === 'close' || !regimeOk) continue;
    const free = maxPos - (positions.size - exiting.size);
    if (free <= 0) continue;
    const cands = [];
    for (const s of members) {
      if (!el[s][d] || (positions.has(s) && !exiting.has(s))) continue;
      const sig = norm(cfg.score(d, s), d);
      if (!sig) continue;
      if (entryAt === 'stop' && !Number.isFinite(sig.trigger)) continue;
      sig.s = s; cands.push(sig);
    }
    if (cands.length > 1) cands.sort((a, b) => b.score - a.score || a.s - b.s);
    // نحتفظ بالمرشحين الزائدين (أمر الإيقاف قد لا يُنفّذ، أو سقف القطاع يرفض)، والمركز الخارج غدًا لا يُعاد شراؤه بنفس الافتتاح
    pendingEntries = cands.filter(x => !exiting.has(x.s)).slice(0, entryAt === 'stop' || cfg.sectorCap ? maxPos * 4 : free);
  }
  return { equity, gross, turn, trades, start };
}

/* ---------- المقاييس ---------- */
const mean = a => a.reduce((x, y) => x + y, 0) / (a.length || 1);
function std(a) { if (a.length < 2) return 0; const m = mean(a); return Math.sqrt(a.reduce((x, y) => x + (y - m) ** 2, 0) / (a.length - 1)); }

// من عوائد يومية (مصفوفة) → عائد، CAGR، تذبذب، شارب (بدون فائدة خالية من المخاطرة)، أقصى تراجع، MAR
export function returnStats(rets) {
  let eq = 1, peak = 1, mdd = 0;
  for (const r of rets) { eq *= 1 + r; if (eq > peak) peak = eq; const dd = 1 - eq / peak; if (dd > mdd) mdd = dd; }
  const n = rets.length, yrs = n / 252;
  const cagr = n ? eq ** (1 / Math.max(yrs, 1e-9)) - 1 : 0;
  const sd = std(rets), m = mean(rets);
  return { ret: eq - 1, cagr, vol: sd * Math.sqrt(252), sharpe: sd > 0 ? (m / sd) * Math.sqrt(252) : 0, maxDD: mdd,
    mar: mdd > 0 ? cagr / mdd : (cagr > 0 ? Infinity : 0), days: n, years: yrs };
}

export function dailyReturns(equity, from, to) {
  const out = [];
  for (let d = Math.max(from, 1); d <= to; d++) {
    const a = equity[d - 1], b = equity[d];
    out.push(Number.isFinite(a) && a > 0 && Number.isFinite(b) ? b / a - 1 : 0);
  }
  return out;
}

// عوائد شراء واحتفاظ لسهم/صندوق (إغلاق لإغلاق) من اليوم from حتى to
export function holdReturns(P, sym, from, to) {
  const s = P.sym(sym); if (s < 0) return null;
  return dailyReturns(P.c[s], from, to);
}

// إحصاءات الصفقات: contrib = ربح الصفقة ÷ رأس المال عند الدخول (يُستخدم لحذف أفضل صفقتين)
export function tradeStats(trades) {
  const n = trades.length;
  const rets = trades.map(t => t.ret).sort((a, b) => a - b);
  const wins = trades.filter(t => t.pnl > 0);
  const gp = trades.reduce((x, t) => x + (t.contrib > 0 ? t.contrib : 0), 0), gl = trades.reduce((x, t) => x + (t.contrib < 0 ? -t.contrib : 0), 0);
  return { trades: n, winRate: n ? wins.length / n : 0, avgTrade: n ? mean(rets) : 0,
    medianTrade: n ? (n % 2 ? rets[n >> 1] : (rets[n / 2 - 1] + rets[n / 2]) / 2) : 0,
    profitFactor: gl > 0 ? gp / gl : (gp > 0 ? Infinity : 0), avgHold: n ? mean(trades.map(t => t.exitIdx - t.entryIdx)) : 0 };
}

// النتيجة بعد حذف أفضل صفقتين: نقسم معامل النمو على (1 + مساهمة كل منهما)
export function best2Removed(totalRet, trades) {
  const top = trades.map(t => t.contrib).sort((a, b) => b - a).slice(0, 2).filter(x => x > 0);
  return top.reduce((g, c) => g / (1 + c), 1 + totalRet) - 1;
}

export function yearlyReturns(rets, yearsOfDays) {
  const out = {};
  for (let i = 0; i < rets.length; i++) { const y = yearsOfDays[i]; out[y] = (out[y] ?? 1) * (1 + rets[i]); }
  for (const y of Object.keys(out)) out[y] -= 1;
  return out;
}

function corr(a, b) {
  const ma = mean(a), mb = mean(b); let sab = 0, sa = 0, sb = 0;
  for (let i = 0; i < a.length; i++) { const x = a[i] - ma, y = b[i] - mb; sab += x * y; sa += x * x; sb += y * y; }
  return sa > 0 && sb > 0 ? sab / Math.sqrt(sa * sb) : 0;
}

// تقرير كامل لسلسلة عوائد يومية + صفقات + مقارنة بالمؤشر على نفس الأيام
export function fullMetrics({ rets, years, trades, gross = null, turn = null, bench = null }) {
  const st = returnStats(rets), ts = tradeStats(trades);
  const yr = yearlyReturns(rets, years);
  const yrVals = Object.values(yr);
  const out = { ...st, ...ts, best2Removed: best2Removed(st.ret, trades), yearly: yr,
    yearsProfitable: yrVals.filter(x => x > 0).length, yearsTotal: yrVals.length,
    exposure: gross ? mean(gross) : null, turnover: turn && st.years > 0 ? turn.reduce((x, y) => x + y, 0) / 2 / st.years : null,
    maxGross: gross ? Math.max(0, ...gross) : null };
  if (bench) { const b = returnStats(bench); out.bench = { ...b, yearly: yearlyReturns(bench, years) }; out.corrBench = corr(rets, bench); }
  return out;
}

/* ---------- سلاسل العوائد (streams) ---------- */
// stream = { rets, gross, turn: Float64Array(D) لكل يوم من التقويم (0 قبل البداية)، trades: [...] }.
// كل التشغيلات والطبقات والمزائج تتحول لهذه الصيغة، فالاختبار الأمامي واحد للجميع.
export function streamFromRun(r) {
  const D = r.equity.length, rets = new Float64Array(D);
  for (let d = r.start + 1; d < D; d++) { const a = r.equity[d - 1], b = r.equity[d]; rets[d] = a > 0 && Number.isFinite(b) ? b / a - 1 : 0; }
  return { rets, gross: Float64Array.from(r.gross), turn: Float64Array.from(r.turn), trades: r.trades, start: r.start };
}

// مزيج بأوزان ثابتة (الباقي نقد بعائد 0%) — توازن يومي للأوزان (تقريب بلا تكلفة إضافية)
export function combineStreams(parts) {
  const D = parts[0].stream.rets.length, rets = new Float64Array(D), gross = new Float64Array(D), turn = new Float64Array(D), trades = [];
  for (const { stream: st, w } of parts) {
    for (let d = 0; d < D; d++) { rets[d] += w * st.rets[d]; gross[d] += w * st.gross[d]; turn[d] += w * st.turn[d]; }
    for (const t of st.trades) trades.push({ ...t, contrib: t.contrib * w, w: t.w * w });
  }
  return { rets, gross, turn, trades, start: Math.min(...parts.map(p => p.stream.start)) };
}

/* ---------- طبقات المخاطر على مستوى المحفظة (overlays) ---------- */
// تضرب تعرض الاستراتيجية كلها في وزن w ∈ [0, 1] (الباقي نقد بعائد 0% — بديل «النقد» المتوافق شرعيًا).
// لا نظر للمستقبل: الإشارة تُحسب بعد إغلاق يوم e-1 (بيانات حتى e-1)، والتنفيذ بأمر إغلاق يوم e،
// فعائد يوم e يكون بالوزن القديم ويبدأ الجديد من يوم e+1. تكلفة التعديل: |Δw| × تعرض الأساس × cost.
// spec: { vt: {target, lookback}, regime: d → bool, dd: {x, days|null, untilRegime: bool}, cost = 0.001, band = 0.1 }
export function applyOverlay(base, spec = {}, { regimeFn = null } = {}) {
  const D = base.rets.length, start = base.start || 0, cost = spec.cost ?? 0.001, band = spec.band ?? 0.1;
  const rets = new Float64Array(D), gross = new Float64Array(D), turn = new Float64Array(D), w = new Float64Array(D);
  const regime = spec.regime || null, reg = regime || regimeFn;
  let cur = 1, eq = 1, peak = 1, outUntil = -1, waitRegime = false;
  const eqAt = new Float64Array(D).fill(1);
  // تذبذب سنوي لعوائد الأساس على [e-L+1, e]
  const vol = (e, L) => {
    if (e - L < start) return NaN;
    let s1 = 0, s2 = 0; for (let k = e - L + 1; k <= e; k++) { s1 += base.rets[k]; s2 += base.rets[k] ** 2; }
    return Math.sqrt(Math.max(0, (s2 - s1 * s1 / L) / (L - 1)) * 252);
  };
  for (let d = start; d < D; d++) {
    w[d] = cur;
    if (d > start) { rets[d] = cur * base.rets[d]; gross[d] = cur * base.gross[d]; turn[d] = cur * base.turn[d]; }
    // قرار بعد إغلاق d-1 (بيانات حتى d-1) → تنفيذ بإغلاق d
    const e = d - 1;
    let tgt = 1;
    if (e >= start) {
      if (spec.vt) { const v = vol(e, spec.vt.lookback); tgt = Number.isFinite(v) && v > 0 ? Math.min(1, spec.vt.target / v) : 1; }
      if (regime && !regime(e)) tgt = 0;
      if (spec.dd) {
        const eqE = eqAt[e];
        if (outUntil >= 0 || waitRegime) {
          const doneTime = outUntil >= 0 && e >= outUntil;
          const doneReg = waitRegime && e >= outUntil && reg && reg(e);
          if ((spec.dd.untilRegime ? doneReg : doneTime)) { outUntil = -1; waitRegime = false; peak = eqE; }
          else tgt = 0;
        } else {
          if (eqE > peak) peak = eqE;
          if (1 - eqE / peak >= spec.dd.x) { tgt = 0; outUntil = e + (spec.dd.days || 5); waitRegime = !!spec.dd.untilRegime; }
        }
      }
    }
    const change = Math.abs(tgt - cur);
    if (d > start && change > 0 && (change >= band || tgt === 0 || tgt === 1)) {
      const c = change * base.gross[d] * cost;
      rets[d] -= c; turn[d] += change * base.gross[d]; cur = tgt;
    }
    eq *= 1 + rets[d]; eqAt[d] = eq;
  }
  // الصفقات: مساهمتها × متوسط الوزن أثناء الاحتفاظ؛ ما دخل بوزن ~0 لا يُعد صفقة
  const trades = [];
  for (const t of base.trades) {
    let s = 0, n = 0; for (let d = Math.max(t.entryIdx, start); d <= Math.min(t.exitIdx, D - 1); d++) { s += w[d]; n++; }
    const k = n ? s / n : 0;
    if (k >= 0.01) trades.push({ ...t, contrib: t.contrib * k, w: t.w * k });
  }
  return { rets, gross, turn, trades, start, weight: w };
}

/* ---------- الاختبار الأمامي (walk-forward) ---------- */
// السنوات: كل سنة تقويمية Y بعد minTrainDays يوم تداول من البداية تصبح «خارج العينة»، والتدريب = كل ما قبلها.
export function makeFolds(dates, { start = 0, minTrainDays = 2 * 252 - 10 } = {}) {
  const D = dates.length, yearOf = i => new Date(dates[i]).getUTCFullYear();
  const ys = [];
  for (let d = start; d < D; d++) { const y = yearOf(d); if (!ys.length || ys[ys.length - 1][0] !== y) ys.push([y, d]); }
  const folds = [];
  ys.forEach(([y, y0], i) => { if (y0 - start >= minTrainDays) folds.push({ year: y, from: y0, to: i + 1 < ys.length ? ys[i + 1][1] - 1 : D - 1, trainFrom: start, trainTo: y0 - 1 }); });
  return folds;
}

// أهداف الاختيار داخل العينة: 'mar' (ثم شارب)، أو { maxDD: T } = أعلى CAGR بشرط تراجع < T (وإلا الأقل تراجعًا)
function isStats(st, from, to) { return returnStats(Array.prototype.slice.call(st.rets, from, to + 1)); }
function pickIndex(options, f, objective, minTradesIS, start) {
  const scored = options.map((st, k) => {
    const s = isStats(st, start + 1, f.from - 1);
    const n = st.trades.reduce((x, t) => x + (t.exitIdx < f.from ? 1 : 0), 0);
    const mar = Number.isFinite(s.mar) ? s.mar : (s.mar > 0 ? 1e9 : -1e9);
    return { k, n, s, mar };
  });
  const pool0 = scored.filter(x => x.n >= minTradesIS), pool = pool0.length ? pool0 : scored;
  let pick;
  if (objective && objective.maxDD) {
    const ok = pool.filter(x => x.s.maxDD < objective.maxDD);
    pick = ok.length ? ok.sort((a, b) => b.s.cagr - a.s.cagr || a.k - b.k)[0]
      : pool.sort((a, b) => a.s.maxDD - b.s.maxDD || b.s.cagr - a.s.cagr || a.k - b.k)[0];
  } else pick = pool.sort((a, b) => b.mar - a.mar || b.s.sharpe - a.s.sharpe || a.k - b.k)[0];
  return { k: pick.k, n: pick.n, isScore: objective && objective.maxDD ? pick.s.cagr : pick.mar, isDD: pick.s.maxDD, isCagr: pick.s.cagr };
}

// optionsFor(fold, j) → [stream] (قد تختلف لكل سنة، مثل طبقة فوق التركيبة المختارة لتلك السنة).
// الاختيار يرى فقط الأيام قبل fold.from؛ ثم تُوصل عوائد الخيار المختار في أيام السنة.
// wfSelectMulti: نفس الخيارات لكل سنة تُقيَّم بعدة أهداف دفعة واحدة (مثل حدود تراجع 10/15/20%).
export function wfSelectMulti(folds, optionsFor, objectives, { start = 0, minTradesIS = 20, years } = {}) {
  const outs = objectives.map(() => ({ folds: [], rets: [], years: [], gross: [], turn: [], trades: [], days: [] }));
  folds.forEach((f, j) => {
    const options = optionsFor(f, j);
    if (!options.length) return;
    objectives.forEach((objective, q) => {
      const out = outs[q], p = pickIndex(options, f, objective, minTradesIS, start), st = options[p.k];
      out.folds.push({ ...f, chosen: p.k, isScore: p.isScore, isTrades: p.n, isDD: p.isDD, isCagr: p.isCagr, label: st.label ?? null, meta: st.meta ?? null });
      for (let d = f.from; d <= f.to; d++) { out.rets.push(st.rets[d]); out.gross.push(st.gross[d]); out.turn.push(st.turn[d]); out.days.push(d); out.years.push(years ? years[d] : null); }
      for (const t of st.trades) if (t.entryIdx >= f.from && t.entryIdx <= f.to) out.trades.push({ ...t, fold: f.year });
    });
  });
  return outs;
}
// الاختيار «الحي»: نفس قاعدة الاختيار على كل البيانات حتى آخر يوم (للتداول من اليوم فصاعدًا — ليس نتيجة اختبار)
export function pickLive(options, { start = 0, objective = 'mar', minTradesIS = 20 } = {}) {
  const D = options[0].rets.length;
  return pickIndex(options, { from: D }, objective, minTradesIS, start).k;
}
export const wfSelect = (folds, optionsFor, { objective = 'mar', ...o } = {}) => wfSelectMulti(folds, optionsFor, [objective], o)[0];

// runs: [{ equity, gross, turn, trades }] — نفس الواجهة القديمة: كل السنوات تختار من نفس التركيبات بأعلى MAR داخل العينة.
// تشغيل سببي ⇒ مقطع البداية من تشغيل كامل = تشغيل مقطوع عند نهاية العينة (لا يرى المستقبل).
export function walkForward(runs, dates, { start = 0, minTrainDays = 2 * 252 - 10, minTradesIS = 20, objective = 'mar' } = {}) {
  const streams = runs.map(r => streamFromRun({ ...r, start: r.start ?? start }));
  const years = Int16Array.from(dates, t => new Date(t).getUTCFullYear());
  return wfSelect(makeFolds(dates, { start, minTrainDays }), () => streams, { start, minTradesIS, objective, years });
}

// فترات التراجع: { start (القمة), trough, recovery|null, depth } مرتبة بالعمق
export function drawdownEpisodes(rets, days, minDepth = 0.03) {
  const eps = []; let eq = 1, peak = 1, peakI = 0, cur = null;
  for (let i = 0; i < rets.length; i++) {
    eq *= 1 + rets[i];
    if (eq >= peak) {
      if (cur) { cur.recovery = days[i]; if (cur.depth >= minDepth) eps.push(cur); cur = null; }
      peak = eq; peakI = i;
    } else {
      const dd = 1 - eq / peak;
      if (!cur) cur = { start: days[peakI], trough: days[i], recovery: null, depth: dd };
      else if (dd > cur.depth) { cur.depth = dd; cur.trough = days[i]; }
    }
  }
  if (cur && cur.depth >= minDepth) eps.push(cur);
  return eps.sort((a, b) => b.depth - a.depth);
}
