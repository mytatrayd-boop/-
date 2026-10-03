// تقرير أسبوعي بالعربية: يقرأ backtest.json و top5.json و sweep.json (إن وُجد) ويكتب lab/results/REPORT.md
// الأرقام بالأرقام الغربية دائمًا (0-9).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const isNum = (x) => typeof x === 'number' && Number.isFinite(x);
const DASH = '—';

// أدوات تنسيق — كلها تعيد «—» عند غياب القيمة، فلا يظهر undefined ولا NaN
export function num(x, d = 2) {
  return isNum(x) ? x.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d }) : DASH;
}
export const int = (x) => (isNum(x) ? Math.round(x).toLocaleString('en-US') : DASH);
export const usd = (x) => (isNum(x) ? (x < 0 ? '-$' : '$') + num(Math.abs(x), 2) : DASH);
export const signed = (x, d = 2) => (isNum(x) ? (x > 0 ? '+' : '') + num(x, d) : DASH);
export const rr = (x) => (isNum(x) ? signed(x) + 'R' : DASH);
// قيمة بالنسبة المئوية أصلًا (returnPct …)
export const pct = (x) => (isNum(x) ? num(x, 2) + '%' : DASH);
// نسبة ربح: قد تكون كسرًا 0..1 أو نسبة مئوية
export const rate = (x) => (isNum(x) ? num(x <= 1 ? x * 100 : x, 1) + '%' : DASH);
const txt = (s) => (s === undefined || s === null || s === '' ? DASH : String(s).replace(/\|/g, '/'));
const day = (s) => (s ? String(s).slice(0, 10) : DASH);

function table(head, rows) {
  return [`| ${head.join(' | ')} |`, `|${head.map(() => '---').join('|')}|`, ...rows.map((r) => `| ${r.join(' | ')} |`)].join('\n');
}

// ملخص walk-forward من sweep.json (مخططه غير ثابت في العقد، فنقرأه بمرونة)
export function sweepLines(sweep) {
  if (!sweep || typeof sweep !== 'object') return [];
  const out = [];
  const wf = sweep.walkForward ?? sweep.walkforward ?? sweep.wf ?? sweep.oos ?? null;
  if (typeof sweep.summary === 'string') out.push(sweep.summary);
  if (wf && typeof wf === 'object') {
    if (typeof wf.note === 'string') out.push(wf.note);
    const parts = Object.entries(wf)
      .filter(([, v]) => isNum(v) || typeof v === 'boolean' || (typeof v === 'string' && v.length < 40))
      .filter(([k]) => k !== 'note')
      .slice(0, 8)
      .map(([k, v]) => `${k}: ${isNum(v) ? num(v, Number.isInteger(v) ? 0 : 2) : v}`);
    if (parts.length) out.push(parts.join('، '));
  } else if (typeof wf === 'string') out.push(wf);
  const best = sweep.best?.params ?? sweep.bestParams ?? null;
  if (best && typeof best === 'object') out.push('أفضل إعدادات: `' + JSON.stringify(best) + '`');
  return out.slice(0, 2);
}

export function renderReport({ backtest: bt = {}, top5 = {}, sweep = null } = {}) {
  const a = bt.account || {};
  const L = [];
  L.push('# تقرير راصد — اختراق خط الاتجاه الهابط (أسبوعي)', '');
  L.push(`تاريخ التوليد: ${day(bt.generatedAt || top5.generatedAt)}`, '');

  // 1) ملخص الحساب
  L.push('## ملخص الحساب الوهمي', '');
  L.push(table(['البند', 'القيمة'], [
    ['رأس المال: البداية ← النهاية', `${usd(a.start)} ← ${usd(a.end)}`],
    ['العائد', pct(a.returnPct)],
    ['أقصى تراجع', pct(a.maxDrawdownPct)],
    ['عدد الصفقات', int(a.trades)],
    ['نسبة الربح', rate(a.winRate)],
    ['متوسط R', rr(a.avgR)],
    ['معامل الربح', num(a.profitFactor)],
    ['مصدر البيانات', txt(bt.source)],
    ['الفترة', `${day(bt.dataFrom)} ← ${day(bt.dataTo)}`],
  ]), '');

  // 2) الجدول الأسبوعي
  const weeks = [...(bt.weeks || [])].sort((x, y) => String(x.weekKey).localeCompare(String(y.weekKey)));
  L.push('## الأسابيع', '');
  if (weeks.length) {
    L.push(table(['الأسبوع', 'الصفقات', 'الرابحة', 'الربح/الخسارة', 'الرصيد في النهاية'],
      weeks.map((w) => [day(w.weekKey), int(w.trades), int(w.wins), usd(w.pnl), usd(w.equityEnd)])), '');
  } else L.push('لا توجد أسابيع في النتائج.', '');

  // 3) أفضل 5
  const top = top5.top || [];
  L.push('## أفضل الأسهم استجابةً لهذا الإعداد', '');
  if (top.length) {
    L.push(table(['#', 'السهم', 'الدرجة', 'الصفقات', 'نسبة الربح', 'متوسط R', 'مجموع R', 'السبب'],
      top.map((t, i) => [String(i + 1), txt(t.sym), num(t.score, 1), int(t.trades), rate(t.winRate), rr(t.avgR), rr(t.totalR), txt(t.why)])), '');
  } else L.push('لا يوجد سهم بلغ الحد الأدنى من الصفقات.', '');
  if (isNum(top5.minTrades) && top.length < 5) {
    L.push(`> المؤهَّل ${int(top.length)} سهم فقط (الحد الأدنى ${int(top5.minTrades)} صفقات).`, '');
  }

  // 4) خارج العينة
  const o = top5.oosSummary || {};
  L.push('## فحص خارج العينة', '');
  if (o.available && (o.picks || []).length) {
    const verdict = o.heldUp === true ? 'نعم، صمدت'
      : o.beatUniverse === true ? 'جزئيًا — تفوّقت على الكون لكنها بقيت خاسرة'
        : o.heldUp === false ? 'لا، لم تصمد' : 'غير محسوم';
    L.push(`هل صمدت اختيارات النصف الأقدم (${day(o.olderFrom)} ← ${day(o.olderTo)}) في النصف الأحدث (${day(o.newerFrom)} ← ${day(o.newerTo)})؟ `
      + `**${verdict}**: ${int(o.picksNewer?.trades)} صفقة بمتوسط ${rr(o.picksNewer?.avgR)} ونسبة ربح ${rate(o.picksNewer?.winRate)}، `
      + `مقابل ${rr(o.universeNewer?.avgR)} و${rate(o.universeNewer?.winRate)} لكل الأسهم.`, '');
    L.push(table(['السهم', 'ترتيبه في الأقدم', 'صفقات الأحدث', 'متوسط R الأحدث', 'نسبة الربح الأحدث'],
      o.picks.map((p) => [txt(p.sym), int(p.olderRank), int(p.trades), rr(p.avgR), rate(p.winRate)])), '');
  } else L.push(txt(o.note || 'لا تتوفر بيانات كافية لفحص خارج العينة.'), '');

  // 5) sweep
  const sw = sweepLines(sweep);
  if (sw.length) L.push('## اختبار walk-forward للإعدادات', '', ...sw.map((s) => `- ${s}`), '');

  // 6) تنبيهات
  const n = isNum(a.trades) ? a.trades : (bt.trades || []).length;
  L.push('## تنبيهات', '');
  L.push(`- **حجم العينة:** ${int(n)} صفقة على ${int(weeks.length)} أسبوع — عدد صغير، والنتائج قد تتغير كثيرًا مع أسابيع جديدة.`);
  L.push('- **مصدر البيانات:** Yahoo يعطي آخر 60 يومًا فقط من شموع 5 دقائق (نحو 12 أسبوعًا)، أما Massive فيعطي سنتين — النتائج على Yahoo أضعف إحصائيًا.');
  L.push('- **الانزلاق:** افترضنا 0.02% لكل جهة؛ التنفيذ الحقيقي قد يكون أسوأ خصوصًا عند الافتتاح.');
  L.push('- **العمولات:** لم تُحسب أي عمولة أو رسوم.');
  L.push('- **الأداء الماضي لا يضمن المستقبل. هذا ليس نصيحة مالية.**', '');
  return L.join('\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const dir = join(dirname(fileURLToPath(import.meta.url)), 'results');
  const read = (f) => JSON.parse(readFileSync(join(dir, f), 'utf8'));
  const sweep = existsSync(join(dir, 'sweep.json')) ? read('sweep.json') : null;
  const md = renderReport({ backtest: read('backtest.json'), top5: read('top5.json'), sweep });
  writeFileSync(join(dir, 'REPORT.md'), md);
  console.log(`REPORT.md: ${md.split('\n').length} سطر`);
}
