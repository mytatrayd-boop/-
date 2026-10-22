// منطق البوصلة الحية لشاشة «اتجاه القبلة» (مستقل عن الحساس ليُختبر).

/// الزاوية في [0، 360).
double normalizeDegrees(double d) {
  final r = d % 360;
  return r < 0 ? r + 360 : r;
}

/// زاوية سهم القبلة على الشاشة باتجاه عقارب الساعة من أعلى الجهاز:
/// القبلة من الشمال − اتجاه الجهاز من الشمال، مطبّعة إلى [0، 360).
double qiblaArrowAngle({required double qibla, required double heading}) =>
    normalizeDegrees(qibla - heading);

/// أقصى خطأ مقبول بالدرجات قبل طلب المعايرة. أندرويد في flutter_compass يعطي
/// ١٥ (عالية) أو ٣٠ (متوسطة) أو ٤٥ (منخفضة)، وnull إذا كانت غير موثوقة أو غير معروفة.
const calibrationThreshold = 30.0;

/// تُطلب المعايرة إذا كانت الدقة منخفضة أو غير معروفة.
bool needsCalibration(double? accuracy) =>
    accuracy == null || accuracy > calibrationThreshold;

/// السهم «على القبلة» إذا انحرف عن أعلى الجهاز بهذا القدر أو أقل.
const alignedWithin = 5.0;

/// ولا يخرج منها إلا بعد هذا الانحراف، كي لا تتذبذب الإشارة عند الحد.
const alignedRelease = 8.0;

/// انحراف السهم عن أعلى الجهاز بالدرجات في [0، 180].
double arrowDeviation(double arrow) {
  final a = normalizeDegrees(arrow);
  return a > 180 ? 360 - a : a;
}

/// هل الجهاز متجه إلى القبلة؟ [wasAligned] الحالة السابقة (تخلّف بين ٥° و٨°).
bool isAligned(double arrow, {required bool wasAligned}) =>
    arrowDeviation(arrow) <= (wasAligned ? alignedRelease : alignedWithin);
