// بيانات اصطناعية للاختبارات وقياس السرعة (لا شبكة). مولّد عشوائي ببذرة ثابتة → نتائج قابلة للتكرار.

export function rng(seed = 1) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
const gauss = r => Math.sqrt(-2 * Math.log(r() + 1e-12)) * Math.cos(2 * Math.PI * r());

// أيام العمل (الاثنين–الجمعة) بدءًا من تاريخ، منتصف ليل UTC (نفس صيغة parseYahooDaily)
export function weekdays(n, from = Date.UTC(2016, 9, 3)) {
  const out = []; let t = from;
  while (out.length < n) { const wd = new Date(t).getUTCDay(); if (wd !== 0 && wd !== 6) out.push(t); t += 86400000; }
  return out;
}

// سهم واحد: حركة عشوائية هندسية (+ اختياريًا ارتداد قصير الأجل) → { t, o, h, l, c, v, rc }
export function synthBars(n, { seed = 1, start = 50, drift = 0.0003, vol = 0.018, volume = 2e6, revert = 0, t = null } = {}) {
  const r = rng(seed), ts = t || weekdays(n);
  const o = [], h = [], l = [], c = [], v = [];
  let px = start, prevRet = 0;
  for (let i = 0; i < n; i++) {
    const gapR = gauss(r) * vol * 0.3;
    const op = px * Math.exp(gapR);
    const dayR = drift - revert * prevRet + gauss(r) * vol * 0.9;
    const cl = op * Math.exp(dayR);
    const hi = Math.max(op, cl) * (1 + Math.abs(gauss(r)) * vol * 0.5);
    const lo = Math.min(op, cl) * (1 - Math.abs(gauss(r)) * vol * 0.5);
    o.push(op); h.push(hi); l.push(lo); c.push(cl); v.push(Math.round(volume * Math.exp(gauss(r) * 0.4)));
    prevRet = Math.log(cl / px); px = cl;
  }
  return { t: ts.slice(0, n), o, h, l, c, v, rc: c.slice() };
}

// كون كامل: SPY/QQQ/IWM + nLarge + nSmall أسهم → { barsBySym: Map, groups }
export function synthUniverse({ nLarge = 50, nSmall = 10, days = 800, seed = 7 } = {}) {
  const t = weekdays(days), barsBySym = new Map(), groups = {};
  const r = rng(seed);
  for (const [k, sym] of ['SPY', 'QQQ', 'IWM'].entries()) { barsBySym.set(sym, synthBars(days, { seed: seed * 100 + k, start: 200 + 50 * k, vol: 0.011, drift: 0.0004, volume: 8e7, t })); groups[sym] = 'bench'; }
  for (let i = 0; i < nLarge + nSmall; i++) {
    const small = i >= nLarge, sym = (small ? 'S' : 'L') + String(i).padStart(4, '0');
    const b = synthBars(days, { seed: seed * 1000 + i, start: 10 + r() * 190, vol: small ? 0.035 : 0.015 + r() * 0.015,
      drift: (r() - 0.4) * 0.0012, volume: small ? 4e5 + r() * 1e6 : 1e6 + r() * 2e7, revert: 0.08, t });
    // بعض الأسهم تبدأ متأخرة (إدراج جديد)
    if (i % 17 === 5) for (const k of Object.keys(b)) b[k] = b[k].slice(Math.floor(days / 3));
    barsBySym.set(sym, b); groups[sym] = small ? 'small' : 'large';
  }
  return { barsBySym, groups };
}
