import 'angles.dart';
import 'time.dart';

/// الزمن النجمي المتوسط في غرينتش بالدرجات (Meeus 12.4)، [jdUt] بالزمن العالمي.
double greenwichMeanSiderealTime(double jdUt) {
  final t = julianCenturies(jdUt);
  return normalizeDegrees(
    280.46061837 +
        360.98564736629 * (jdUt - j2000) +
        0.000387933 * t * t -
        t * t * t / 38710000.0,
  );
}

/// الزمن النجمي المحلي بالدرجات؛ [lonEast] خط الطول (الشرق موجب).
double localSiderealTime(double jdUt, double lonEast) =>
    normalizeDegrees(greenwichMeanSiderealTime(jdUt) + lonEast);
