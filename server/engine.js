// محرك راصد — منقول من النموذج الأولي (scoreTicker وملحقاته) بنفس المنطق المُختبر.
// لا يعتمد على أي مكتبة، ويعمل في Node والمتصفح.

export const MIN_BARS = 25;

/* ---------- Alpha Vantage payload -> bars (JSON أو CSV خام — الاثنين يرجعون فعليًا) ---------- */
export function barsFromAlphaVantage(payload) {
  const series = payload && typeof payload === 'object' && payload['Time Series (Daily)'];
  if (series) {
    const dates = Object.keys(series).sort();
    const t = [], o = [], h = [], l = [], c = [], v = [];
    for (const d of dates) {
      const row = series[d];
      t.push(new Date(d + 'T00:00:00Z').getTime());
      o.push(parseFloat(row['1. open'])); h.push(parseFloat(row['2. high']));
      l.push(parseFloat(row['3. low'])); c.push(parseFloat(row['4. close']));
      v.push(parseFloat(row['5. volume'] || 0));
    }
    if (t.length < MIN_BARS) throw new Error('بيانات قليلة جدًا من المزوّد.');
    return { t, o, h, l, c, v };
  }
  let text = null;
  if (typeof payload === 'string') text = payload;
  else if (payload && Array.isArray(payload.content)) {
    const block = payload.content.find(b => b.type === 'text');
    if (block) text = block.text;
  }
  if (text && text.trim().toLowerCase().startsWith('timestamp')) {
    const lines = text.trim().split(/\r?\n/);
    const rows = [];
    for (let i = 1; i < lines.length; i++) {
      const parts = lines[i].split(',');
      if (parts.length < 6) continue;
      const d = Date.parse(parts[0]);
      if (isNaN(d)) continue;
      rows.push([d, +parts[1], +parts[2], +parts[3], +parts[4], +parts[5]]);
    }
    rows.sort((a, b) => a[0] - b[0]); // CSV يجي من الأحدث للأقدم
    const out = { t: [], o: [], h: [], l: [], c: [], v: [] };
    for (const r of rows) { out.t.push(r[0]); out.o.push(r[1]); out.h.push(r[2]); out.l.push(r[3]); out.c.push(r[4]); out.v.push(r[5]); }
    if (out.t.length < MIN_BARS) throw new Error('بيانات قليلة جدًا من المزوّد.');
    return out;
  }
  throw new Error('شكل رد غير متوقع من المزوّد. بداية الرد: ' + JSON.stringify(payload).slice(0, 200));
}

/* ---------- indicators ---------- */
export function atrArr(h, l, c, n) {
  const len = h.length, tr = new Array(len).fill(0);
  for (let i = 0; i < len; i++) {
    if (i === 0) { tr[i] = h[i] - l[i]; continue; }
    tr[i] = Math.max(h[i] - l[i], Math.abs(h[i] - c[i - 1]), Math.abs(l[i] - c[i - 1]));
  }
  const out = new Array(len).fill(NaN); const alpha = 1 / n; let y = null;
  for (let i = 0; i < len; i++) { y = y === null ? tr[i] : alpha * tr[i] + (1 - alpha) * y; if (i >= n - 1) out[i] = y; }
  return out;
}

export function smaArr(arr, n) {
  const out = new Array(arr.length).fill(NaN); let sum = 0;
  for (let i = 0; i < arr.length; i++) { sum += arr[i]; if (i >= n) sum -= arr[i - n]; if (i >= n - 1) out[i] = sum / n; }
  return out;
}

export function rsiArr(closes, n) {
  const len = closes.length, out = new Array(len).fill(NaN);
  let avgGain = null, avgLoss = null; const alpha = 1 / n;
  for (let i = 1; i < len; i++) {
    const chg = closes[i] - closes[i - 1];
    const gain = Math.max(chg, 0), loss = Math.max(-chg, 0);
    if (avgGain === null) { avgGain = gain; avgLoss = loss; }
    else { avgGain = alpha * gain + (1 - alpha) * avgGain; avgLoss = alpha * loss + (1 - alpha) * avgLoss; }
    if (i >= n) { const rs = avgLoss > 0 ? avgGain / avgLoss : 100; out[i] = 100 - 100 / (1 + rs); }
  }
  return out;
}

/* ---------- يقين (قائمة يدوية) ---------- */
export const VERDICTS = ['شرعي', 'محل نظر', 'غير شرعي'];

export function parseYaqeenList(text) {
  const map = {};
  for (const raw of String(text || '').split('\n')) {
    const line = raw.trim(); if (!line) continue;
    const idx = line.indexOf(',');
    if (idx < 0) continue;
    map[line.slice(0, idx).trim().toUpperCase()] = line.slice(idx + 1).trim();
  }
  return map;
}

// يرجع {kept, excluded}. سهم بلا حكم = "غير معروف" ولا يُستبعد (نتجنب استبعاد بلا دليل).
export function applyYaqeen(tickers, yaqeen, { excludeHaram = true, excludeMashbooh = false } = {}) {
  const kept = [], excluded = {};
  for (const sym of tickers) {
    const v = yaqeen[sym];
    if (v === 'غير شرعي' && excludeHaram) { excluded[sym] = v; continue; }
    if (v === 'محل نظر' && excludeMashbooh) { excluded[sym] = v; continue; }
    kept.push(sym);
  }
  return { kept, excluded };
}

/* ---------- التسجيل: بوابة سيولة (إلزامية) × زخم RSI (ترتيب + اتجاه) ---------- */
export function scoreTicker(bars, p) {
  const n = bars.c.length;
  const i = n - 1; // آخر يوم مغلق
  const volAvg = smaArr(bars.v, p.volAvgDays);
  const rsi = rsiArr(bars.c, 14);
  const atr = atrArr(bars.h, bars.l, bars.c, 14);
  const liqRatio = volAvg[i - 1] > 0 ? bars.v[i] / volAvg[i - 1] : 0; // متوسط باستثناء اليوم نفسه
  const passesGate = liqRatio >= p.volMult;
  const rsiVal = rsi[i];
  const direction = rsiVal >= 50 ? 1 : -1;
  const momentumStrength = isNaN(rsiVal) ? 0 : Math.abs(rsiVal - 50) / 50; // 0..1
  const score = passesGate ? liqRatio * momentumStrength : 0;
  return { passesGate, liqRatio, rsiVal, direction, momentumStrength, score, atr: atr[i], lastClose: bars.c[i], lastDate: bars.t[i] };
}

// الدخول = آخر إغلاق، الوقف = الدخول ∓ slAtr×ATR، الهدف = الدخول ± rr×مسافة الوقف.
export function buildTrade(s, { slAtr, rr }) {
  const entry = s.lastClose;
  const risk = slAtr * s.atr;
  return { entry, stop: entry - s.direction * risk, target: entry + s.direction * rr * risk };
}

export function rankResults(perTicker, top = 2) {
  const entries = Object.entries(perTicker);
  const passed = entries.filter(([, v]) => v.ok && v.passesGate).sort((a, b) => b[1].score - a[1].score);
  return {
    top: passed.slice(0, top),
    passed,
    gateRejected: entries.filter(([, v]) => v.ok && !v.passesGate),
    failed: entries.filter(([, v]) => !v.ok),
  };
}
