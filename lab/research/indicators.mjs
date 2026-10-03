// مؤشرات يومية سريعة على مصفوفات مكتوبة (Float64Array) — قيمة اليوم i تستخدم البيانات حتى i فقط.
// NaN = لا يكفي التاريخ بعد (أو لا توجد بيانات). كل الدوال صافية ومُختبرة على سلاسل صغيرة.

const F = n => new Float64Array(n).fill(NaN);

// متوسط بسيط لـ n يوم (يتجاهل حتى يكتمل n قيمة صالحة متتالية)
export function sma(x, n) {
  const out = F(x.length);
  let sum = 0, cnt = 0;
  for (let i = 0; i < x.length; i++) {
    const v = x[i];
    if (!Number.isFinite(v)) { sum = 0; cnt = 0; continue; }
    sum += v; cnt++;
    if (cnt > n) { sum -= x[i - n]; cnt = n; }
    if (cnt === n) out[i] = sum / n;
  }
  return out;
}

// RSI بتنعيم وايلدر
export function rsi(c, n) {
  const out = F(c.length);
  let ag = 0, al = 0, k = 0;
  for (let i = 1; i < c.length; i++) {
    const a = c[i - 1], b = c[i];
    if (!Number.isFinite(a) || !Number.isFinite(b)) { ag = 0; al = 0; k = 0; continue; }
    const ch = b - a, g = ch > 0 ? ch : 0, l = ch < 0 ? -ch : 0;
    k++;
    if (k <= n) { ag += g / n; al += l / n; if (k < n) continue; }
    else { ag = (ag * (n - 1) + g) / n; al = (al * (n - 1) + l) / n; }
    out[i] = al === 0 ? (ag === 0 ? 50 : 100) : 100 - 100 / (1 + ag / al);
  }
  return out;
}

// ATR (وايلدر) كنسبة من الإغلاق (atrPct) — أسهل للمقارنة بين الأسهم
export function atr(h, l, c, n) {
  const out = F(c.length);
  let a = NaN, k = 0;
  for (let i = 1; i < c.length; i++) {
    if (!Number.isFinite(c[i - 1]) || !Number.isFinite(h[i])) { a = NaN; k = 0; continue; }
    const tr = Math.max(h[i] - l[i], Math.abs(h[i] - c[i - 1]), Math.abs(l[i] - c[i - 1]));
    k++;
    if (k <= n) { a = (k === 1 ? 0 : a) + tr / n; if (k < n) continue; }
    else a = (a * (n - 1) + tr) / n;
    out[i] = a;
  }
  return out;
}

// أعلى قيمة في آخر n يوم (شامل اليوم)
export function rollingMax(x, n) {
  const out = F(x.length);
  const dq = new Int32Array(x.length); let hd = 0, tl = 0, valid = 0;
  for (let i = 0; i < x.length; i++) {
    if (!Number.isFinite(x[i])) { hd = tl = 0; valid = 0; continue; }
    valid++;
    while (tl > hd && x[dq[tl - 1]] <= x[i]) tl--;
    dq[tl++] = i;
    while (dq[hd] <= i - n) hd++;
    if (valid >= n) out[i] = x[dq[hd]];
  }
  return out;
}
export function rollingMin(x, n) {
  const neg = Float64Array.from(x, v => -v);
  return rollingMax(neg, n).map(v => -v);
}

// العائد على k يوم: c[i]/c[i-k]-1
export function ret(c, k) {
  const out = F(c.length);
  for (let i = k; i < c.length; i++) if (c[i - k] > 0 && Number.isFinite(c[i])) out[i] = c[i] / c[i - k] - 1;
  return out;
}

// التذبذب السنوي لعوائد يومية على n يوم
export function realizedVol(c, n) {
  const r = new Float64Array(c.length).fill(NaN);
  for (let i = 1; i < c.length; i++) if (c[i - 1] > 0 && c[i] > 0) r[i] = Math.log(c[i] / c[i - 1]);
  const out = F(c.length);
  let s = 0, s2 = 0, cnt = 0;
  for (let i = 0; i < c.length; i++) {
    const v = r[i];
    if (!Number.isFinite(v)) { s = s2 = 0; cnt = 0; continue; }
    s += v; s2 += v * v; cnt++;
    if (cnt > n) { const o = r[i - n]; s -= o; s2 -= o * o; cnt = n; }
    if (cnt === n) out[i] = Math.sqrt(Math.max(0, (s2 - s * s / n) / (n - 1)) * 252);
  }
  return out;
}

// موقع الإغلاق في مدى اليوم (Internal Bar Strength)
export function ibs(h, l, c) {
  const out = F(c.length);
  for (let i = 0; i < c.length; i++) if (Number.isFinite(c[i])) out[i] = h[i] > l[i] ? (c[i] - l[i]) / (h[i] - l[i]) : 0.5;
  return out;
}

// عدد أيام الهبوط المتتالية حتى i (إغلاق < إغلاق سابق)
export function downStreak(c) {
  const out = new Float64Array(c.length);
  for (let i = 1; i < c.length; i++) out[i] = c[i] < c[i - 1] ? out[i - 1] + 1 : 0;
  return out;
}

// NR7: مدى اليوم أصغر مدى في آخر 7 أيام (1/0)
export function nr7(h, l) {
  const out = new Float64Array(h.length);
  for (let i = 6; i < h.length; i++) {
    const r = h[i] - l[i]; let ok = Number.isFinite(r);
    for (let k = i - 6; ok && k < i; k++) if (!(h[k] - l[k] > r)) ok = false;
    out[i] = ok ? 1 : 0;
  }
  return out;
}
// يوم داخلي: أعلى ≤ أعلى أمس وأدنى ≥ أدنى أمس
export function insideDay(h, l) {
  const out = new Float64Array(h.length);
  for (let i = 1; i < h.length; i++) out[i] = h[i] <= h[i - 1] && l[i] >= l[i - 1] ? 1 : 0;
  return out;
}

// متوسط قيمة التداول بالدولار (سعر غير معدّل للأرباح × الحجم) لـ n يوم
export function avgDollarVol(rc, v, n) {
  const dv = new Float64Array(rc.length);
  for (let i = 0; i < rc.length; i++) dv[i] = Number.isFinite(rc[i]) && Number.isFinite(v[i]) ? rc[i] * v[i] : NaN;
  return sma(dv, n);
}

// وسيط مصفوفة (نسخة)
export function median(arr) {
  const a = Array.from(arr).filter(Number.isFinite).sort((x, y) => x - y);
  if (!a.length) return NaN;
  const m = a.length >> 1;
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}
