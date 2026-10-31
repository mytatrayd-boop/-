const pct = (v) => (v === null || v === undefined ? 'غير مقاس' : `${(v * 100).toFixed(0)}%`);
const ok = (p) => (p === null ? 'غير مقاس' : p ? 'نجاح' : 'فشل');
export function formatReport(m, meta = {}) {
  const lines = [`# تقرير الجدوى — النموذج ${meta.model ?? '?'} — الطلب ${meta.promptVersion ?? '?'}`];
  for (const [k, v] of Object.entries(m)) {
    const c = v.criteria;
    lines.push(`\n## ${k} (n=${v.n}، مستبعد=${v.skipped})`,
      `- فرق ≤10 عن الخبير: ${pct(c.expertDiff.value)} (الهدف 70%) ${ok(c.expertDiff.pass)}`,
      `- ثبات ≤5: ${pct(c.stability.value)} (الهدف 90%) ${ok(c.stability.pass)}`,
      `- التفريق ضعيفة<ممتازة: ${ok(c.separation.pass)}`,
      `- الملاحظات صحيحة: ${pct(c.notes.value)} (الهدف 70%) ${ok(c.notes.pass)}`,
      `- الزمن: p50=${c.latency.p50?.toFixed(1) ?? '-'}s p90=${c.latency.p90?.toFixed(1) ?? '-'}s، ضمن 10ث: ${pct(c.latency.value)} ${ok(c.latency.pass)}`,
      `- التكلفة للفحص: ${c.cost.perScan === null ? 'غير مقاسة' : '$' + c.cost.perScan.toFixed(5)}`,
      `- النتيجة: ${v.overallPass ? 'نجاح' : 'لم ينجح'}${v.unmeasured ? ` (${v.unmeasured} معايير غير مقاسة)` : ''}`);
  }
  return lines.join('\n');
}
