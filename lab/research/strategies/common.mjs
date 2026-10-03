// أدوات مشتركة للاستراتيجيات: فلاتر حالة السوق (SPY)، أيام إعادة التوازن، والتقويم.
// التقويم (أي الأيام تداول) معروف مسبقًا من جدول البورصة، لذلك استخدام «اليوم التالي» تقويميًا ليس نظرًا للمستقبل.
// بعد نهاية البيانات نقدّره بأيام العمل (الاثنين–الجمعة).

const DAY = 86400000;
function nextWeekday(t) { do t += DAY; while ([0, 6].includes(new Date(t).getUTCDay())); return t; }
export function nextDate(P, d) { return d + 1 < P.D ? P.dates[d + 1] : nextWeekday(P.dates[d]); }

// آخر يوم تداول في الأسبوع؟
export function lastOfWeek(P, d) {
  const a = P.dates[d], b = nextDate(P, d);
  return new Date(b).getUTCDay() <= new Date(a).getUTCDay() || b - a > 4 * DAY;
}
// آخر يوم تداول في الشهر؟
export const lastOfMonth = (P, d) => new Date(nextDate(P, d)).getUTCMonth() !== new Date(P.dates[d]).getUTCMonth();

// عدد أيام التداول المتبقية في الشهر بعد d (0 = آخر يوم)، ورقم يوم التداول في الشهر (1 = الأول)
export function daysToMonthEnd(P, d) {
  const m = new Date(P.dates[d]).getUTCMonth(); let k = 0, t = P.dates[d], i = d;
  for (;;) { t = i + 1 < P.D ? P.dates[i + 1] : nextWeekday(t); i++; if (new Date(t).getUTCMonth() !== m) return k; k++; }
}
export function dayOfMonth(P, d) {
  let k = 1; while (d - k >= 0 && P.months[d - k] === P.months[d]) k++;
  return k;
}

// فلتر حالة السوق على SPY ببيانات حتى d: 'none' | 'sma200' (فوق متوسط 200) | 'vol' (تذبذب 20 يوم < 25%) | 'both'
export function regimeFn(P, kind = 'none', bench = 'SPY') {
  if (!kind || kind === 'none') return null;
  const s = P.sym(bench); if (s < 0) return () => false;
  const c = P.c[s], m = P.series('sma:200')[s], v = P.series('vol:20')[s];
  const trend = d => c[d] > m[d], calm = d => v[d] < 0.25;
  if (kind === 'strong') { const r21 = P.series('ret:21')[s]; return d => trend(d) && r21[d] > 0; }
  if (kind === 'breadth') { const b = breadth(P); return d => b[d] > 0.5; }
  if (kind === 'spy12m') { const r252 = P.series('ret:252')[s]; return d => r252[d] > 0; }
  return kind === 'sma200' ? trend : kind === 'vol' ? calm : d => trend(d) && calm(d);
}

// اتساع السوق: نسبة أسهم كون «large» (المؤهلة ذلك اليوم) التي تغلق فوق متوسط 50 يومًا — بيانات حتى اليوم نفسه
export function breadth(P) {
  if (P.cache.has('breadth50')) return P.cache.get('breadth50');
  const U = P.universe('large'), m50 = P.series('sma:50'), out = new Float64Array(P.D).fill(NaN);
  for (let d = 0; d < P.D; d++) {
    let n = 0, up = 0;
    for (const s of U.members) if (U.el[s][d] && Number.isFinite(m50[s][d])) { n++; if (P.c[s][d] > m50[s][d]) up++; }
    if (n >= 10) out[d] = up / n;
  }
  P.cache.set('breadth50', out);
  return out;
}

export const sizing = x => (x === 'vol' ? { vol: 0.30 } : 'equal');

// زخم 12-1: العائد من قبل 252 يومًا حتى قبل 21 يومًا (نتجاهل آخر شهر) — لكل سهم، مخزّن
export function mom121(P) {
  if (P.cache.has('mom121')) return P.cache.get('mom121');
  const r252 = P.series('ret:252'), r21 = P.series('ret:21');
  const out = r252.map((a, s) => Float64Array.from(a, (x, d) => (1 + x) / (1 + r21[s][d]) - 1));
  P.cache.set('mom121', out);
  return out;
}

// الترتيب المئوي المقطعي (0..1، 1 = الأعلى) لسلسلة بين أسهم كون «large» المؤهلة في كل يوم — بيانات اليوم نفسه فقط
export function xsRank(P, key, arrs) {
  const ck = 'rank:' + key;
  if (P.cache.has(ck)) return P.cache.get(ck);
  const U = P.universe('large'), out = new Array(P.S).fill(null).map(() => new Float64Array(P.D).fill(NaN));
  const buf = [];
  for (let d = 0; d < P.D; d++) {
    buf.length = 0;
    for (const s of U.members) if (U.el[s][d] && Number.isFinite(arrs[s][d])) buf.push(s);
    if (buf.length < 2) continue;
    buf.sort((a, b) => arrs[a][d] - arrs[b][d]);
    for (let i = 0; i < buf.length; i++) out[buf[i]][d] = i / (buf.length - 1);
  }
  P.cache.set(ck, out);
  return out;
}
