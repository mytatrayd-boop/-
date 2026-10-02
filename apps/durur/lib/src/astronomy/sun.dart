import 'angles.dart';
import 'time.dart';

/// الموضع الظاهري للشمس بالدقة المنخفضة (Meeus فصل 25، ~0.01°).
/// [jde] التاريخ اليولياني بالزمن الديناميكي.
Equatorial sunApparentPosition(double jde) {
  final t = julianCenturies(jde);
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  final c =
      (1.914602 - 0.004817 * t - 0.000014 * t * t) * sinDeg(m) +
      (0.019993 - 0.000101 * t) * sinDeg(2 * m) +
      0.000289 * sinDeg(3 * m);
  final trueLongitude = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  final lambda = trueLongitude - 0.00569 - 0.00478 * sinDeg(omega);
  final epsilon = meanObliquity(t) + 0.00256 * cosDeg(omega);
  final ra = atan2Deg(cosDeg(epsilon) * sinDeg(lambda), cosDeg(lambda));
  final dec = asinDeg(sinDeg(epsilon) * sinDeg(lambda));
  return Equatorial(normalizeDegrees(ra), dec);
}

/// الميل المتوسط لدائرة البروج بالدرجات (Meeus 22.2)، [t] قرون يوليانية.
double meanObliquity(double t) =>
    23.0 +
    26.0 / 60 +
    (21.448 - 46.8150 * t - 0.00059 * t * t + 0.001813 * t * t * t) / 3600;
