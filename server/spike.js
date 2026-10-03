// انفجار السيولة — سهم صغير رخيص ينفجر حجمه فجأة ويكسر قاعدته. شراء فقط، احتفاظ قصير (2–3 أيام تداول)،
// والخروج بالوقت مهما صار بعده. الإشارة تُقرر بعد إغلاق يوم D من شموع يومية حتى D فقط (بدون نظر للمستقبل).
// بدون أي اعتماد على Node: نفس الكود في الخادم وتطبيق الأندرويد والمختبر.
// الشموع بصيغة buildBars: { t, o, h, l, c, v } — لكل سهم فهارسه الخاصة، و t يحاذي الأيام بين الأسهم.

export const SPIKE_DEFAULTS = {
  minPrice: 0.5,          // أقل إغلاق يوم الإشارة ($)
  maxPrice: 20,           // أعلى إغلاق ($) — أسهم صغيرة ورخيصة
  volAvgDays: 30,         // متوسط الحجم: 30 يوم تداول قبل D (بدون D)
  volMult: 20,            // حجم D ≥ 20 × المتوسط
  minVolume: 3e6,         // حجم D ≥ 3 ملايين سهم
  minDollarVol: 3e6,      // الإغلاق × الحجم ≥ 3 ملايين $
  minChange: 0.20,        // إغلاق D ÷ إغلاق D-1 − 1 ≥ +20%
  baseDays: 40,           // الإغلاق فوق أعلى إغلاق في 40 يوم تداول قبل D (كسر قاعدة)
  closeInRange: 0.75,     // الإغلاق في أعلى ربع مدى اليوم: c ≥ l + 0.75 × (h − l)
  entry: 'open',          // 'open' = افتتاح D+1 | 'breakout' = عند أعلى D إذا تجاوزه D+1
  hold: 3,                // الخروج بإغلاق D+hold (يوم الدخول D+1 محسوب)، أيام تداول فقط
  stop: true,             // وقف كارثي تحت أدنى D
};

// شبكة المختبر (2 × 2 × 2 × 3 = 24 تركيبة)
export const SPIKE_GRID = { entry: ['open', 'breakout'], hold: [2, 3], stop: [true, false], volMult: [10, 20, 40] };

// أقل عدد شموع قبل D حتى تُحسب الإشارة
export const spikeLookback = (p = SPIKE_DEFAULTS) => Math.max(p.volAvgDays, p.baseDays);

const DAY_MS = 86400000;
export const isoDay = t => new Date(t).toISOString().slice(0, 10);

// كل شرط على حدة (للاختبارات والشرح) — null لو ما فيه تاريخ كافٍ
export function spikeChecks(bars, i, p = SPIKE_DEFAULTS) {
  p = { ...SPIKE_DEFAULTS, ...p };
  if (!bars || !bars.c || i < spikeLookback(p) || i >= bars.c.length) return null;
  const o = bars.o[i], h = bars.h[i], l = bars.l[i], c = bars.c[i], v = bars.v[i], prev = bars.c[i - 1];
  let sv = 0;
  for (let k = i - p.volAvgDays; k < i; k++) sv += bars.v[k];
  const avgVol = sv / p.volAvgDays;
  let baseHigh = -Infinity;
  for (let k = i - p.baseDays; k < i; k++) if (bars.c[k] > baseHigh) baseHigh = bars.c[k];
  const volRatio = avgVol > 0 ? v / avgVol : 0; // متوسط صفر = ما نقدر نقيس → يفشل
  const change = prev > 0 ? c / prev - 1 : 0;
  const closePos = h > l ? (c - l) / (h - l) : 1;
  const dollarVol = c * v;
  return {
    values: { t: bars.t[i], open: o, high: h, low: l, close: c, prevClose: prev, volume: v, avgVol, volRatio, change, baseHigh, closePos, dollarVol },
    checks: {
      price: c >= p.minPrice && c <= p.maxPrice,
      volMult: volRatio >= p.volMult,
      volume: v >= p.minVolume,
      dollarVol: dollarVol >= p.minDollarVol,
      change: change >= p.minChange - 1e-12,
      breakout: c > baseHigh,
      closeInRange: c >= l + p.closeInRange * (h - l) - 1e-12,
    },
  };
}

// إشارة يوم i أو null. فلتر سريع أولاً (السوق كامل ≈ 10 آلاف سهم × مئات الأيام في المختبر)
export function spikeSignal(bars, i, p = SPIKE_DEFAULTS) {
  p = { ...SPIKE_DEFAULTS, ...p };
  if (!bars || !bars.c || i < spikeLookback(p) || i >= bars.c.length) return null;
  const c = bars.c[i], v = bars.v[i];
  if (!(c >= p.minPrice && c <= p.maxPrice) || v < p.minVolume || c * v < p.minDollarVol) return null;
  if (!(bars.c[i - 1] > 0) || c / bars.c[i - 1] - 1 < p.minChange - 1e-12) return null;
  const r = spikeChecks(bars, i, p);
  if (!Object.values(r.checks).every(Boolean)) return null;
  const x = r.values;
  return { i, t: x.t, date: isoDay(x.t), open: x.open, high: x.high, low: x.low, close: x.close, prevClose: x.prevClose,
    volume: x.volume, avgVol: x.avgVol, volRatio: x.volRatio, change: x.change, baseHigh: x.baseHigh, closePos: x.closePos, dollarVol: x.dollarVol };
}

// الصفقة بعد إشارة يوم i: { entryIdx, entry, exitIdx, exit, how: 'time'|'stop', ret } أو null (لا تعبئة أو لا شموع كافية)
// الوقف = أدنى D. ملامسته → خروج عند الوقف، أو عند الافتتاح لو فتح تحته (فجوة).
// يوم الدخول: الشمعة اليومية ما تقول هل القاع قبل الدخول أو بعده، فنطبّق الوقف يومها فقط لو الدخول كان بالافتتاح.
export function spikeTrade(bars, i, p = SPIKE_DEFAULTS) {
  p = { ...SPIKE_DEFAULTS, ...p };
  const e = i + 1, x = i + p.hold;
  if (!bars || !bars.c || i < 0 || !(p.hold >= 1) || x >= bars.c.length) return null;
  const trigger = bars.h[i], stop = bars.l[i];
  let entry, atOpen;
  if (p.entry === 'breakout') {
    if (bars.o[e] >= trigger) { entry = bars.o[e]; atOpen = true; }
    else if (bars.h[e] >= trigger) { entry = trigger; atOpen = false; }
    else return null; // ما وصل أعلى D → لا صفقة
  } else { entry = bars.o[e]; atOpen = true; }
  if (!(entry > 0)) return null;
  if (p.stop) {
    for (let k = atOpen ? e : e + 1; k <= x; k++) {
      if (bars.l[k] <= stop) {
        const px = bars.o[k] < stop ? bars.o[k] : stop;
        return { entryIdx: e, entry, exitIdx: k, exit: px, how: 'stop', ret: px / entry - 1 };
      }
    }
  }
  return { entryIdx: e, entry, exitIdx: x, exit: bars.c[x], how: 'time', ret: bars.c[x] / entry - 1 };
}

// تقويم السوق: كل أيام t الموجودة في أي سهم، تصاعديًا
export function marketDays(barsBySym) {
  const set = new Set();
  for (const b of symValues(barsBySym)) for (const t of b.t) set.add(t);
  return [...set].sort((a, b) => a - b);
}
function* symEntries(m) { if (m instanceof Map) yield* m.entries(); else yield* Object.entries(m || {}); }
function* symValues(m) { for (const [, b] of symEntries(m)) yield b; }

// فهرس يوم t داخل شموع سهم (بحث ثنائي) أو -1
export function indexOfT(bars, t) {
  let lo = 0, hi = bars.t.length - 1;
  while (lo <= hi) { const m = (lo + hi) >> 1; if (bars.t[m] === t) return m; if (bars.t[m] < t) lo = m + 1; else hi = m - 1; }
  return -1;
}

// إشارات يوم واحد للسوق كامل. dayIdx فهرس في تقويم السوق (marketDays)؛ سالب = من الآخر (-1 = آخر يوم).
// opts.commonStocks: Set لأسهم type=CS (إن توفرت) — غيرها يُستبعد. الترتيب: الأعلى مضاعف حجم أولاً.
export function scanSpikes(barsBySym, dayIdx = -1, p = SPIKE_DEFAULTS, opts = {}) {
  const days = opts.days || marketDays(barsBySym);
  const di = dayIdx < 0 ? days.length + dayIdx : dayIdx;
  const t = days[di];
  if (t === undefined) return [];
  const out = [];
  for (const [sym, b] of symEntries(barsBySym)) {
    if (opts.commonStocks && !opts.commonStocks.has(sym)) continue;
    if (!b || !b.t || !b.t.length || b.t[b.t.length - 1] < t) continue;
    const i = b.t[b.t.length - 1] === t ? b.t.length - 1 : indexOfT(b, t);
    if (i < 0) continue;
    const s = spikeSignal(b, i, p);
    if (s) out.push({ sym, ...s });
  }
  return out.sort((a, b) => b.volRatio - a.volRatio || (a.sym < b.sym ? -1 : 1));
}

/* ---------- أيام التداول القادمة (لخطة الدخول/الخروج في التطبيق) ---------- */
// عطل بورصة نيويورك الكاملة — تُحدّث سنويًا. يوم خارج القائمة = يوم عمل عادي.
export const NYSE_HOLIDAYS = new Set([
  '2025-01-01', '2025-01-09', '2025-01-20', '2025-02-17', '2025-04-18', '2025-05-26', '2025-06-19', '2025-07-04', '2025-09-01', '2025-11-27', '2025-12-25',
  '2026-01-01', '2026-01-19', '2026-02-16', '2026-04-03', '2026-05-25', '2026-06-19', '2026-07-03', '2026-09-07', '2026-11-26', '2026-12-25',
  '2027-01-01', '2027-01-18', '2027-02-15', '2027-03-26', '2027-05-31', '2027-06-18', '2027-07-05', '2027-09-06', '2027-11-25', '2027-12-24',
]);
export function nextTradingDays(dateStr, n) {
  const out = [];
  let t = Date.parse(dateStr + 'T00:00:00Z');
  while (out.length < n) {
    t += DAY_MS;
    const wd = new Date(t).getUTCDay(), d = isoDay(t);
    if (wd !== 0 && wd !== 6 && !NYSE_HOLIDAYS.has(d)) out.push(d);
  }
  return out;
}

// الخطة بالعربي لإشارة على آخر يوم مخزّن: دخول D+1، خروج بإغلاق D+hold، حماية تحت أدنى D
export function spikePlan(sig, p = SPIKE_DEFAULTS) {
  p = { ...SPIKE_DEFAULTS, ...p };
  const days = nextTradingDays(sig.date, p.hold);
  return { entryDate: days[0], exitDate: days[p.hold - 1], entry: p.entry, trigger: p.entry === 'breakout' ? sig.high : null, stop: p.stop ? sig.low : null, hold: p.hold };
}

// بطاقة إشارة بالشكل المشترك (spikes-today.json من المسح الليلي، والحساب المحلي في التطبيق/الخادم):
// { sym, name, day, close, chgPct, volMult, volume, dollarVol, highD, lowD, entryDate, exitDate, bars40: {t,o,h,l,c,v} }
// bars40 = آخر 40 يوم تداول حتى يوم الإشارة (يوم الإشارة آخرها).
export const SPIKE_CHART_DAYS = 40;
export function spikeCard(sym, bars, sig, { name = null, exchange = null, p = SPIKE_DEFAULTS } = {}) {
  const plan = spikePlan(sig, p);
  const from = Math.max(0, sig.i - SPIKE_CHART_DAYS + 1), cut = k => bars[k].slice(from, sig.i + 1);
  const r = (x, d = 4) => Math.round(x * 10 ** d) / 10 ** d;
  return {
    sym, name, exchange, day: sig.date, close: sig.close, chgPct: r(sig.change * 100, 2), volMult: r(sig.volRatio, 1),
    volume: sig.volume, dollarVol: Math.round(sig.dollarVol), highD: sig.high, lowD: sig.low,
    entryDate: plan.entryDate, exitDate: plan.exitDate, hold: plan.hold,
    bars40: { t: cut('t'), o: cut('o'), h: cut('h'), l: cut('l'), c: cut('c'), v: cut('v') },
  };
}

// يوم السوق الأخير «المكتمل»: آخر يوم فيه ≥ نصف عدد الأسهم المعتاد (يوم تتوفر فيه رموز قليلة فقط = بيانات ناقصة)
export function latestMarketDayIdx(barsBySym, days = marketDays(barsBySym)) {
  if (!days.length) return -1;
  const counts = new Map(days.slice(-6).map(t => [t, 0]));
  for (const b of symValues(barsBySym)) for (let k = b.t.length - 1; k >= 0 && counts.has(b.t[k]); k--) counts.set(b.t[k], counts.get(b.t[k]) + 1);
  const max = Math.max(...counts.values());
  for (let k = days.length - 1; k >= Math.max(0, days.length - 6); k--) if (counts.get(days[k]) >= max * 0.5) return k;
  return days.length - 1;
}
