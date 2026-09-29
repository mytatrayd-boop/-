// بيانات مصطنعة للوضع التجريبي فقط (بدون مفتاح). الواجهة توسمها بوضوح "تجريبي".
// ثابتة لكل (سهم، يوم) حتى يكون العرض قابلاً للتكرار.

function seedFrom(str) {
  let h = 2166136261;
  for (const ch of str) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function rng(seed) {
  let a = seed;
  return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

export function demoBars(symbol, days = 100) {
  const today = new Date().toISOString().slice(0, 10);
  const r = rng(seedFrom(symbol + today));
  const drift = (r() - 0.5) * 0.006;
  let price = 40 + r() * 400;
  const baseVol = 5e6 + r() * 5e7;
  const spike = r() < 0.5 ? 1.6 + r() * 1.8 : 0.7 + r() * 0.6; // نصف الأسهم تقريبًا فيها سيولة غير طبيعية
  const out = { t: [], o: [], h: [], l: [], c: [], v: [] };
  const end = Date.UTC(...today.split('-').map((x, i) => i === 1 ? x - 1 : +x));
  for (let i = 0; i < days; i++) {
    const open = price;
    const close = open * (1 + drift + (r() - 0.5) * 0.04);
    const hi = Math.max(open, close) * (1 + r() * 0.015);
    const lo = Math.min(open, close) * (1 - r() * 0.015);
    out.t.push(end - (days - 1 - i) * 86400000);
    out.o.push(open); out.h.push(hi); out.l.push(lo); out.c.push(close);
    out.v.push(Math.round(baseVol * (0.7 + r() * 0.6) * (i === days - 1 ? spike : 1)));
    price = close;
  }
  return out;
}
