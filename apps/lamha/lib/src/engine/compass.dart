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
