/// السرعات المتاحة (SPEC 7). النغمة ثابتة (يضمنها المشغّل).
const playbackSpeeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];
const defaultPlaybackSpeed = 1.0;

/// يعيد أقرب سرعة مسموحة؛ قيمة غير صالحة (NaN/سالبة/غريبة) تعطي الافتراضي.
double normalizeSpeed(double? value) {
  if (value == null || value.isNaN || value.isInfinite) return defaultPlaybackSpeed;
  for (final s in playbackSpeeds) {
    if ((s - value).abs() < 0.001) return s;
  }
  return defaultPlaybackSpeed;
}
