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

/// الجهاز «على القبلة» إذا كان الفرق بهذا القدر أو أقل (طلب المالك: ٣°).
const alignedWithin = 3.0;

/// ولا يخرج منها إلا بعد هذا الفرق، كي لا تتذبذب الإشارة ولا يتكرر الاهتزاز عند الحد.
const alignedRelease = 5.0;

/// انحراف السهم عن أعلى الجهاز بالدرجات في [0، 180].
double arrowDeviation(double arrow) {
  final a = normalizeDegrees(arrow);
  return a > 180 ? 360 - a : a;
}

/// هل الجهاز متجه إلى القبلة؟ [wasAligned] الحالة السابقة (تخلّف بين ٣° و٥°).
bool isAligned(double arrow, {required bool wasAligned}) =>
    arrowDeviation(arrow) <= (wasAligned ? alignedRelease : alignedWithin);

/// تنعيم اتجاه الحساس (مرشح منخفض التمرير دائري): يقترب من [next] بنسبة [factor] عبر أقصر
/// طريق، فلا يقفز القرص بين ٣٥٩° و٠°.
double smoothHeading(double? previous, double next, {double factor = 0.25}) {
  if (previous == null) return normalizeDegrees(next);
  final delta = (next - previous + 540) % 360 - 180;
  return normalizeDegrees(previous + delta * factor);
}

/// دقة البوصلة لبطاقة «دقة البوصلة».
enum CompassAccuracy { excellent, good, poor }

/// من خطأ الحساس بالدرجات (أندرويد ١٥/٣٠/٤٥، وآيفون headingAccuracy): ≤١٥ ممتازة، و≤٣٠ جيدة،
/// وغير ذلك أو مجهولة أو سالبة (غير صالحة في آيفون) ضعيفة.
CompassAccuracy compassAccuracy(double? accuracy) {
  if (accuracy == null || accuracy < 0) return CompassAccuracy.poor;
  if (accuracy <= 15) return CompassAccuracy.excellent;
  if (accuracy <= calibrationThreshold) return CompassAccuracy.good;
  return CompassAccuracy.poor;
}
