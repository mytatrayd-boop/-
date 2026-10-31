// حساب معايير نجاح اختبار الجدوى (SPEC). دوال نقية بلا شبكة.
export const TARGETS = {
  expertDiffPoints: 10, expertDiffShare: 0.7,
  stabilityPoints: 5, stabilityShare: 0.9,
  notesShare: 0.7,
  latencySeconds: 10, latencyShare: 0.9,
  // معايير مبدئية للبيانات المفتوحة (لا ينص عليها SPEC)
  roastAccuracy: 0.7, defectAccuracy: 0.7,
};

const share = (arr, pred) => (arr.length ? arr.filter(pred).length / arr.length : null);
const mean = (a) => a.reduce((s, v) => s + v, 0) / a.length;
export function percentile(sorted, p) {
  if (!sorted.length) return null;
  return sorted[Math.min(sorted.length - 1, Math.ceil(p * sorted.length) - 1)];
}

/**
 * row: {image, type, expert, expertClass: 'poor'|'mid'|'excellent', notesCorrect?: 0..3,
 *       runs: [{score, ms, cost}, {score, ms, cost}]}
 * الصفوف التي فشلت تشغيلاتها (score غير رقم) تُستبعد وتُعدّ في skipped.
 */
export function computeMetrics(rows, t = TARGETS) {
  const valid = rows.filter((r) => r.runs.length >= 2 && r.runs.slice(0, 2).every((x) => Number.isFinite(x.score)));
  const avg = valid.map((r) => mean(r.runs.slice(0, 2).map((x) => x.score)));
  // فرق الخبير: فقط الصفوف التي لها تقييم خبير (expert رقم)
  const diffs = valid.map((r, i) => (Number.isFinite(r.expert) ? Math.abs(avg[i] - r.expert) : NaN)).filter(Number.isFinite);
  const stab = valid.map((r) => Math.abs(r.runs[0].score - r.runs[1].score));

  const expertShare = share(diffs, (d) => d <= t.expertDiffPoints);
  const stabilityShare = share(stab, (d) => d <= t.stabilityPoints);

  // التفريق: كل درجات «ضعيفة» (كل التشغيلات) أقل من كل درجات «ممتازة»
  // الفئة: expertClass (خبير) أو clearClass (فئة واضحة من مصدر مفتوح)؛ الأولى تتقدم
  const clsOf = (r) => r.expertClass ?? r.clearClass;
  const scoresOf = (cls) => valid.filter((r) => clsOf(r) === cls).flatMap((r) => r.runs.slice(0, 2).map((x) => x.score));
  const poor = scoresOf('poor'), exc = scoresOf('excellent');
  const sepTestable = poor.length > 0 && exc.length > 0;
  const separation = sepTestable ? Math.max(...poor) < Math.min(...exc) : null;

  const rated = valid.filter((r) => Number.isFinite(r.notesCorrect));
  const notesShare = rated.length ? rated.reduce((s, r) => s + r.notesCorrect, 0) / (3 * rated.length) : null;

  const labels = labelMetrics(valid, t);
  const allRuns = valid.flatMap((r) => r.runs.slice(0, 2));
  const lat = allRuns.map((x) => x.ms / 1000).filter(Number.isFinite).sort((a, b) => a - b);
  const costs = allRuns.map((x) => x.cost).filter(Number.isFinite);

  const pass = (v, target) => (v === null ? null : v >= target);
  const c = {
    expertDiff: { value: expertShare, target: t.expertDiffShare, pass: pass(expertShare, t.expertDiffShare) },
    stability: { value: stabilityShare, target: t.stabilityShare, pass: pass(stabilityShare, t.stabilityShare) },
    separation: { value: separation, pass: separation },
    roast: labels.roast,
    defect: labels.defect,
    notes: { value: notesShare, target: t.notesShare, pass: pass(notesShare, t.notesShare) },
    latency: {
      p50: percentile(lat, 0.5), p90: percentile(lat, 0.9),
      value: share(lat, (s) => s <= t.latencySeconds), target: t.latencyShare,
      pass: lat.length ? share(lat, (s) => s <= t.latencySeconds) >= t.latencyShare : null,
    },
    cost: { perScan: costs.length ? mean(costs) : null, total: costs.length ? costs.reduce((s, v) => s + v, 0) : null },
  };
  // معايير الوسوم المفتوحة تدخل الحكم فقط إن قيست (لا تمنع النجاح عند غيابها، وتُفشله إن قيست وأخفقت)
  const gating = [c.expertDiff.pass, c.stability.pass, c.separation, c.notes.pass, c.latency.pass,
    ...[c.roast.pass, c.defect.pass].filter((v) => v !== null)];
  return {
    n: valid.length, skipped: rows.length - valid.length, criteria: c,
    // null = لم يُقَس (بيانات ناقصة) ولا يُعدّ نجاحاً
    overallPass: valid.length > 0 && gating.every((v) => v === true),
    unmeasured: gating.filter((v) => v === null).length,
  };
}

/**
 * مطابقة مستوى التحميص وكشف العيوب مقابل الوسوم الموجودة.
 * row.roastLabel: light|medium|dark ؛ row.defectLabel: 'defect'|'ok'
 * run.roast: light|medium|dark|green|unknown ؛ run.hasDefects: boolean
 * الحساب لكل تشغيل (تشغيلان لكل صورة). الصفوف بلا وسم أو بلا حقل في المخرجات لا تُحسب.
 */
export function labelMetrics(valid, t = TARGETS) {
  const runsOf = (r) => r.runs.slice(0, 2);
  const roastRuns = valid.filter((r) => r.roastLabel).flatMap((r) => runsOf(r).filter((x) => typeof x.roast === 'string').map((x) => ({ l: r.roastLabel, p: x.roast })));
  const defRuns = valid.filter((r) => r.defectLabel).flatMap((r) => runsOf(r).filter((x) => typeof x.hasDefects === 'boolean').map((x) => ({ l: r.defectLabel === 'defect', p: x.hasDefects })));
  const roastAcc = share(roastRuns, (x) => x.l === x.p);
  const classes = [...new Set(roastRuns.map((x) => x.l))].sort();
  const confusion = {};
  for (const x of roastRuns) { confusion[x.l] ??= {}; confusion[x.l][x.p] = (confusion[x.l][x.p] ?? 0) + 1; }
  const defAcc = share(defRuns, (x) => x.l === x.p);
  const pos = defRuns.filter((x) => x.l), neg = defRuns.filter((x) => !x.l);
  const pass = (v, target) => (v === null ? null : v >= target);
  return {
    roast: { value: roastAcc, n: roastRuns.length, target: t.roastAccuracy, classes, confusion, pass: pass(roastAcc, t.roastAccuracy) },
    defect: {
      value: defAcc, n: defRuns.length, target: t.defectAccuracy,
      recall: share(pos, (x) => x.p), specificity: share(neg, (x) => !x.p), pass: pass(defAcc, t.defectAccuracy),
    },
  };
}

export function byType(rows) {
  const out = { all: computeMetrics(rows) };
  for (const ty of [...new Set(rows.map((r) => r.type))]) out[ty] = computeMetrics(rows.filter((r) => r.type === ty));
  return out;
}
