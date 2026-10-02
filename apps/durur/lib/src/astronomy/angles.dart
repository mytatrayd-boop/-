import 'dart:math' as math;

/// أدوات زوايا بالدرجات (Dart صافٍ).

const double degToRad = math.pi / 180;
const double radToDeg = 180 / math.pi;

/// يعيد الزاوية إلى المدى [0، 360).
double normalizeDegrees(double degrees) {
  final r = degrees % 360;
  return r < 0 ? r + 360 : r;
}

double sinDeg(double degrees) => math.sin(degrees * degToRad);
double cosDeg(double degrees) => math.cos(degrees * degToRad);
double tanDeg(double degrees) => math.tan(degrees * degToRad);
double asinDeg(double x) => math.asin(x.clamp(-1.0, 1.0)) * radToDeg;
double atan2Deg(double y, double x) => math.atan2(y, x) * radToDeg;

/// إحداثيات استوائية بالدرجات: المطلع المستقيم [ra] في [0، 360) والميل [dec].
class Equatorial {
  const Equatorial(this.ra, this.dec);

  final double ra;
  final double dec;

  @override
  String toString() => 'Equatorial(ra: $ra°, dec: $dec°)';
}
