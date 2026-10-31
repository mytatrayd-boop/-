/// فئة التقدير. الدرجة الرقمية تقدير تقريبي، فالمستخدم يرى الفئة فقط.
enum ScoreTier { excellent, good, average, weak }

ScoreTier tierOf(int score) {
  if (score >= 85) return ScoreTier.excellent;
  if (score >= 70) return ScoreTier.good;
  if (score >= 50) return ScoreTier.average;
  return ScoreTier.weak;
}
