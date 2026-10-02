import 'angles.dart';
import 'time.dart';

/// المبادرة الدقيقة من J2000.0 إلى [jde] (Meeus فصل 21، المعادلات 21.3 و21.4).
/// التحوّل (النوتيشن) والزيغ مُهملان (أقل من 20″، ARCHITECTURE §6).
Equatorial precessFromJ2000(Equatorial j2000Position, double jde) {
  final t = julianCenturies(jde);
  final zeta = (2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600;
  final z = (2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600;
  final theta = (2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600;
  final a0 = j2000Position.ra;
  final d0 = j2000Position.dec;
  final a = cosDeg(d0) * sinDeg(a0 + zeta);
  final b =
      cosDeg(theta) * cosDeg(d0) * cosDeg(a0 + zeta) -
      sinDeg(theta) * sinDeg(d0);
  final c =
      sinDeg(theta) * cosDeg(d0) * cosDeg(a0 + zeta) +
      cosDeg(theta) * sinDeg(d0);
  return Equatorial(normalizeDegrees(atan2Deg(a, b) + z), asinDeg(c));
}
