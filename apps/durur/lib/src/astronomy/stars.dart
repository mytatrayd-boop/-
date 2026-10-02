import 'angles.dart';
import 'precession.dart';
import 'time.dart';

/// نجم بإحداثيات J2000 (ICRS) وحركته الذاتية.
class Star {
  const Star({
    required this.id,
    required this.raJ2000,
    required this.decJ2000,
    required this.pmRaCosDec,
    required this.pmDec,
    required this.magnitude,
  });

  final String id;

  /// المطلع المستقيم والميل عند J2000.0 بالدرجات.
  final double raJ2000;
  final double decJ2000;

  /// الحركة الذاتية بالملّي ثانية قوسية في السنة: μα·cosδ و μδ.
  final double pmRaCosDec;
  final double pmDec;

  /// القدر الظاهري (للتوثيق؛ المعيار يعتمد قوس الرؤية لكل نجم).
  final double magnitude;

  /// الموضع المتوسط عند [jde]: الحركة الذاتية ثم المبادرة (Meeus 21.b).
  Equatorial positionAt(double jde) {
    final years = (jde - j2000) / 365.25;
    final dRa = pmRaCosDec / cosDeg(decJ2000) / 3.6e6 * years;
    final dDec = pmDec / 3.6e6 * years;
    return precessFromJ2000(Equatorial(raJ2000 + dRa, decJ2000 + dDec), jde);
  }
}

double _hms(int h, int m, double s) => (h + m / 60 + s / 3600) * 15;
double _dms(int sign, int d, int m, double s) => sign * (d + m / 60 + s / 3600);

/// سهيل = α Carinae (Canopus، HIP 30438، القدر −0.74).
/// المصدر: SIMBAD (إحداثيات ICRS J2000 والحركة الذاتية من Hipparcos، van Leeuwen 2007).
final canopus = Star(
  id: 'canopus',
  raJ2000: _hms(6, 23, 57.10988),
  decJ2000: _dms(-1, 52, 41, 44.3810),
  pmRaCosDec: 19.93,
  pmDec: 23.24,
  magnitude: -0.74,
);

/// الثريا: η Tauri (Alcyone، HIP 17702، القدر 2.87) نقطةً مرجعية للعنقود.
/// المصدر: SIMBAD (إحداثيات ICRS J2000 والحركة الذاتية من Hipparcos، van Leeuwen 2007).
final alcyone = Star(
  id: 'alcyone',
  raJ2000: _hms(3, 47, 29.0765),
  decJ2000: _dms(1, 24, 6, 18.494),
  pmRaCosDec: 19.34,
  pmDec: -43.67,
  magnitude: 2.87,
);
