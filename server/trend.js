// صيغة الاتجاهات — كسر خط ترند هابط (مقاومة) على شموع 5 دقائق، دخول يوم الاثنين فقط، خروج بالوقف/الهدف/إغلاق الجمعة.
// نقيّة: بدون Node (تعمل في WebView الأندرويد). لا نظر للمستقبل: قرار الشمعة i يستخدم الشموع 0..i فقط، والتنفيذ بافتتاح i+1.
// الشرح الكامل بالأرقام: lab/STRATEGY.md
import { atrArr } from './engine.js';

export const TREND_DEFAULTS = {
  pivotK: 3,            // قمة/قاع فركتال: الأعلى/الأدنى ضمن ±3 شموع (15 دقيقة كل جهة) — تُعرف بعد 3 شموع فقط
  lookbackBars: 156,    // نبحث عن القمم في آخر 156 شمعة (= يومَا تداول) — الخط قد يبدأ الأسبوع الماضي
  maxPivots: 8,         // نجرّب الأزواج بين آخر 8 قمم معروفة فقط
  minSpanBars: 12,      // أقل مسافة بين نقطتي الخط = 12 شمعة (ساعة)
  touchTolAtr: 0.25,    // قمة تُعدّ "لمسة" إذا بعدت عن الخط ≤ 0.25 × ATR
  breachTolAtr: 0.25,   // لا يُقبل الخط إذا أغلقت أي شمعة بعد بدايته فوقه بأكثر من 0.25 × ATR
  atrN: 14,             // ATR(14) على شموع 5 دقائق
  breakBufAtr: 0.1,     // الكسر: إغلاق > قيمة الخط + 0.1 × ATR
  volN: 20,             // متوسط الحجم لآخر 20 شمعة (قبل شمعة الكسر)
  volMult: 1.2,         // تأكيد الحجم: حجم شمعة الكسر ≥ 1.2 × المتوسط (0 = بدون شرط حجم)
  skipOpenMin: 15,      // نتجاهل أول 15 دقيقة بعد الافتتاح (أول 3 شموع) كشموع كسر — ضجيج الافتتاح
  noEntryLastMin: 30,   // لا دخول في آخر 30 دقيقة من الاثنين: شمعة الدخول يجب أن تبدأ قبل 15:30
  stopBufAtr: 0.1,      // الوقف تحت آخر قاع فركتال بـ 0.1 × ATR
  minStopAtr: 0.5,      // مسافة الوقف لا تقل عن 0.5 × ATR (حتى لا يضربه الضجيج)
  maxStopAtr: 3,        // ولا تزيد عن 3 × ATR (إذا كان القاع بعيدًا أو لا يوجد قاع)
  rr: 2,                // الهدف = الدخول + 2 × المخاطرة (عائد/مخاطرة 2)
};

// شبكة صغيرة للمختبر (تعمّدنا قلّة القيم لتقليل الإفراط في الملاءمة)
export const TREND_GRID = {
  pivotK: [2, 3, 5],
  breakBufAtr: [0.05, 0.1, 0.25],
  volMult: [0, 1.2, 1.8],
  rr: [1.5, 2, 3],
};

/* ---------- التوقيت: أجزاء نيويورك (يراعي التوقيت الصيفي) ---------- */
const DAY = 86400000, HOUR = 3600000;
const WD = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
let fmt = null;
const offCache = new Map(); // فرق التوقيت لكل ساعة UTC (التحويل الصيفي يحدث على رأس الساعة)
function nyOffsetMin(ms) {
  const key = Math.floor(ms / HOUR);
  let off = offCache.get(key);
  if (off !== undefined) return off;
  if (!fmt) fmt = new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  const at = key * HOUR, q = {};
  for (const x of fmt.formatToParts(new Date(at))) q[x.type] = x.value;
  const local = Date.UTC(+q.year, +q.month - 1, +q.day, +q.hour % 24, +q.minute);
  off = Math.round((local - at) / 60000);
  if (offCache.size > 50000) offCache.clear();
  offCache.set(key, off);
  return off;
}
const pad = n => String(n).padStart(2, '0');
const ymd = d => `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;

export function etParts(ms) {
  const d = new Date(ms + nyOffsetMin(ms) * 60000);
  const wd = d.getUTCDay();
  return { date: ymd(d), weekday: wd === 0 ? 7 : wd, minutes: d.getUTCHours() * 60 + d.getUTCMinutes() };
}

// تاريخ اثنين الأسبوع (حتى لو كان عطلة)
function mondayOf(date, weekday) {
  const [y, m, d] = date.split('-').map(Number);
  return ymd(new Date(Date.UTC(y, m - 1, d) - (weekday - 1) * DAY));
}

/* ---------- تقسيم الأسابيع ---------- */
export function splitWeeks(bars) {
  const out = [];
  const n = bars && bars.t ? bars.t.length : 0;
  let cur = null;
  for (let i = 0; i < n; i++) {
    const e = etParts(bars.t[i]);
    const key = mondayOf(e.date, e.weekday);
    if (!cur || cur.weekKey !== key) { cur = { weekKey: key, start: i, end: i, firstDay: e.date, lastDay: e.date }; out.push(cur); }
    cur.end = i; cur.lastDay = e.date;
  }
  return out;
}

/* ---------- القمم والقيعان (فركتال) ---------- */
function pivotsArr(arr, k, high) {
  const n = arr.length, out = new Array(n).fill(false);
  for (let j = k; j < n - k; j++) {
    let ok = true;
    for (let m = 1; m <= k && ok; m++) {
      // يسار: أكبر بصرامة، يمين: أكبر أو يساوي (حتى لا تتكرر القمة عند التساوي)
      if (high) ok = arr[j] > arr[j - m] && arr[j] >= arr[j + m];
      else ok = arr[j] < arr[j - m] && arr[j] <= arr[j + m];
    }
    out[j] = ok;
  }
  return out;
}

// حساب مسبق مرة واحدة لكل مصفوفة (كله سببي: ATR أُسّي، والقمة j تُستخدم فقط إذا j+k ≤ endIdx)
function prep(bars, p) {
  return { atr: atrArr(bars.h, bars.l, bars.c, p.atrN), ph: pivotsArr(bars.h, p.pivotK, true), pl: pivotsArr(bars.l, p.pivotK, false) };
}

const lineAt = (L, i) => L.p1 + L.slope * (i - L.i1);

// أفضل خط عبر قمتين (مقاومة هابطة) أو قاعين (دعم صاعد)
function bestLine(bars, endIdx, p, P, high) {
  const k = p.pivotK, from = Math.max(0, endIdx - p.lookbackBars);
  const piv = high ? P.ph : P.pl, px = high ? bars.h : bars.l, c = bars.c;
  const known = [];
  for (let j = from; j <= endIdx - k; j++) if (piv[j]) known.push(j);
  const cand = known.slice(-p.maxPivots);
  let best = null, bestScore = -Infinity;
  for (let a = 0; a < cand.length; a++) {
    for (let b = a + 1; b < cand.length; b++) {
      const i1 = cand[a], i2 = cand[b];
      if (i2 - i1 < p.minSpanBars) continue;
      const p1 = px[i1], p2 = px[i2];
      if (high ? !(p2 < p1) : !(p2 > p1)) continue;
      const L = { i1, p1, i2, p2, slope: (p2 - p1) / (i2 - i1) };
      // صلاحية: لا إغلاق يخترق الخط بشكل معتبر من بدايته حتى الشمعة السابقة لـ endIdx
      let ok = true;
      for (let m = i1 + 1; m < endIdx && ok; m++) {
        const tol = p.breachTolAtr * (P.atr[m] || 0);
        ok = high ? c[m] <= lineAt(L, m) + tol : c[m] >= lineAt(L, m) - tol;
      }
      if (!ok || !(lineAt(L, endIdx) > 0)) continue;
      let touches = 0;
      for (const j of known) {
        if (j < i1) continue;
        if (Math.abs(px[j] - lineAt(L, j)) <= p.touchTolAtr * (P.atr[j] || 0) || j === i1 || j === i2) touches++;
      }
      // اللمسات أولًا، ثم الامتداد (كسر < 1)، والتعادل يذهب للأحدث
      const score = touches + (i2 - i1) / (p.lookbackBars + 1);
      if (score > bestScore || (score === bestScore && best && i2 > best.i2)) { bestScore = score; best = { ...L, touches }; }
    }
  }
  return best;
}

function linesWith(bars, endIdx, p, P) {
  return { resistance: bestLine(bars, endIdx, p, P, true), support: bestLine(bars, endIdx, p, P, false) };
}

// ننسخ حتى endIdx فقط: ضمان أن لا شيء بعدها يدخل الحساب
function sliceBars(bars, n) {
  return { t: bars.t.slice(0, n), o: bars.o.slice(0, n), h: bars.h.slice(0, n), l: bars.l.slice(0, n), c: bars.c.slice(0, n), v: bars.v.slice(0, n) };
}

export function findTrendlines(bars, endIdx, p = TREND_DEFAULTS) {
  p = { ...TREND_DEFAULTS, ...p };
  if (!bars || !bars.t || endIdx < 0 || endIdx >= bars.t.length) return { resistance: null, support: null };
  const b = sliceBars(bars, endIdx + 1);
  return linesWith(b, endIdx, p, prep(b, p));
}

/* ---------- الكسر والدخول ---------- */
const SESSION_OPEN = 570, SESSION_CLOSE = 960; // 09:30 و 16:00 بتوقيت نيويورك

// هل الشمعة i شمعة كسر صالحة؟ (يستخدم 0..i فقط)
function breakAt(bars, i, p, P) {
  const L = bestLine(bars, i, p, P, true);
  if (!L) return null;
  const atr = P.atr[i];
  if (!(atr > 0)) return null;
  const lv = lineAt(L, i);
  if (!(bars.c[i] > lv + p.breakBufAtr * atr)) return null;
  let volRatio = null;
  if (p.volMult > 0) {
    if (i < p.volN) return null;
    let s = 0; for (let m = i - p.volN; m < i; m++) s += bars.v[m];
    const avg = s / p.volN;
    volRatio = avg > 0 ? bars.v[i] / avg : Infinity;
    if (volRatio < p.volMult) return null;
  }
  return { line: L, lineValue: lv, atr, volRatio };
}

// آخر قاع فركتال معروف عند الشمعة i
function lastSwingLow(bars, i, p, P) {
  const from = Math.max(0, i - p.lookbackBars);
  for (let j = i - p.pivotK; j >= from; j--) if (P.pl[j]) return { idx: j, price: bars.l[j] };
  return null;
}

function inWindow(e, firstDay, p) {
  return e.date === firstDay && e.minutes >= SESSION_OPEN + p.skipOpenMin;
}

function makeSignal(bars, i, br, p, P) {
  const entryIdx = i + 1, entry = bars.o[entryIdx], atr = br.atr;
  const sw = lastSwingLow(bars, i, p, P);
  let stop = sw ? sw.price - p.stopBufAtr * atr : -Infinity;
  if (!(entry - stop <= p.maxStopAtr * atr)) stop = entry - p.maxStopAtr * atr;  // بعيد جدًا أو لا قاع (أو القاع فوق الدخول)
  if (entry - stop < p.minStopAtr * atr) stop = entry - p.minStopAtr * atr;       // قريب جدًا
  const target = entry + p.rr * (entry - stop);
  const vol = br.volRatio == null ? '' : ` + حجم ${br.volRatio.toFixed(2)}×`;
  const reason = `كسر خط هابط (${br.line.touches} لمسات) بإغلاق ${bars.c[i].toFixed(2)} > ${br.lineValue.toFixed(2)} + ${p.breakBufAtr}×ATR${vol}؛ الوقف ${sw && stop === sw.price - p.stopBufAtr * atr ? 'تحت آخر قاع' : `${((entry - stop) / atr).toFixed(2)}×ATR`}`;
  return { idx: i, t: bars.t[i], entryIdx, entryT: bars.t[entryIdx], entry, stop, target, line: br.line, reason };
}

// المحاكاة الأساسية. complete=false: الأسبوع لم ينتهِ بعد (لا خروج "جمعة").
function simulate(bars, week, p, complete) {
  const P = prep(sliceBars(bars, week.end + 1), p);
  const res = { weekKey: week.weekKey, signal: null, exit: null, r: null, pct: null };
  for (let i = week.start; i < week.end; i++) {
    const e = etParts(bars.t[i]);
    if (e.date !== week.firstDay) break;
    if (!inWindow(e, week.firstDay, p)) continue;
    const e2 = etParts(bars.t[i + 1]);
    if (e2.date !== week.firstDay || e2.minutes >= SESSION_CLOSE - p.noEntryLastMin) break;
    const br = breakAt(bars, i, p, P);
    if (br) { res.signal = makeSignal(bars, i, br, p, P); break; }
  }
  const s = res.signal;
  if (!s) return res;
  for (let j = s.entryIdx; j <= week.end; j++) {
    const o = bars.o[j];
    // الوقف أولًا (تحفّظ)، والفجوة تُنفّذ بالافتتاح
    if (bars.l[j] <= s.stop) { res.exit = { idx: j, t: bars.t[j], price: o <= s.stop ? o : s.stop, how: 'stop' }; break; }
    if (bars.h[j] >= s.target) { res.exit = { idx: j, t: bars.t[j], price: o >= s.target ? o : s.target, how: 'target' }; break; }
  }
  if (!res.exit && complete) res.exit = { idx: week.end, t: bars.t[week.end], price: bars.c[week.end], how: 'friday' };
  if (res.exit) {
    res.r = (res.exit.price - s.entry) / (s.entry - s.stop);
    res.pct = res.exit.price / s.entry - 1;
  }
  return res;
}

// الأسبوع منتهٍ إذا جاءت بعده شموع، أو آخر شمعة هي شمعة 15:55 يوم جمعة، أو week.complete === true
function weekComplete(bars, week) {
  if (week.complete === true) return true;
  if (week.complete === false) return false;
  if (week.end < bars.t.length - 1) return true;
  const e = etParts(bars.t[week.end]);
  return e.weekday === 5 && e.minutes >= SESSION_CLOSE - 5;
}

export function weeklyTrade(bars, week, p = TREND_DEFAULTS) {
  p = { ...TREND_DEFAULTS, ...p };
  return simulate(bars, week, p, weekComplete(bars, week));
}

/* ---------- الحالة الحية للتطبيق ---------- */
export function liveSignal(bars, p = TREND_DEFAULTS, nowMs = Date.now()) {
  p = { ...TREND_DEFAULTS, ...p };
  const n = bars && bars.t ? bars.t.length : 0;
  const now = etParts(nowMs), nowKey = mondayOf(now.date, now.weekday);
  if (!n) return { state: 'no-data', weekKey: nowKey, line: null, last: null };
  const lastIdx = n - 1, last = { t: bars.t[lastIdx], price: bars.c[lastIdx] };
  const weeks = splitWeeks(bars), week = weeks[weeks.length - 1];
  const nowLine = () => findTrendlines(bars, lastIdx, p).resistance;
  const beforeCutoff = now.minutes < SESSION_CLOSE - p.noEntryLastMin;

  // أسبوع جديد بدأ (اثنين) ولا بيانات له بعد: نراقب الخط الممتد من آخر شموع متاحة
  if (nowKey > week.weekKey && now.weekday === 1 && beforeCutoff) return { state: 'waiting', weekKey: nowKey, line: nowLine(), last };

  const complete = nowKey > week.weekKey || now.weekday >= 6 || (now.weekday === 5 && now.minutes >= SESSION_CLOSE) || weekComplete(bars, week);
  const res = simulate(bars, week, p, complete);
  const base = { weekKey: week.weekKey, last };
  if (res.signal) {
    const out = { ...base, line: res.signal.line, signal: res.signal, exit: res.exit, r: res.r, pct: res.pct };
    if (!res.exit) return { state: 'entered', ...out };
    return { state: res.exit.how === 'friday' ? 'week-over' : 'closed', ...out };
  }
  if (complete) return { state: 'week-over', ...base, line: nowLine() };
  // لا إشارة بعد: هل نافذة الاثنين ما زالت مفتوحة؟
  const eLast = etParts(bars.t[lastIdx]);
  const mondayOpen = eLast.date === week.firstDay && now.date === week.firstDay && beforeCutoff;
  if (mondayOpen) {
    const out = { state: 'waiting', ...base, line: nowLine() };
    // كسر على آخر شمعة: الدخول بافتتاح الشمعة التالية
    if (inWindow(eLast, week.firstDay, p)) {
      const P = prep(sliceBars(bars, n), p), br = breakAt(bars, lastIdx, p, P);
      if (br) out.pendingBreak = { idx: lastIdx, t: bars.t[lastIdx], close: bars.c[lastIdx], lineValue: br.lineValue };
    }
    return out;
  }
  return { state: 'no-signal', ...base, line: nowLine() };
}
