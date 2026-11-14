import 'dart:math' as math;

import 'distance.dart';
import 'geo_point.dart';

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// يطبّع زاوية إلى [0, 360).
double normalizeDegrees(double d) => ((d % 360) + 360) % 360;

/// الفرق الموقّع الأقصر من [from] إلى [to] في (-180, 180].
double shortestAngleDelta(double from, double to) {
  final d = normalizeDegrees(to - from);
  return d > 180 ? d - 360 : d;
}

/// الاتجاه الابتدائي (0 = شمال، 90 = شرق) من [a] إلى [b] بالدرجات.
double bearingBetween(GeoPoint a, GeoPoint b) {
  final p1 = _rad(a.lat), p2 = _rad(b.lat);
  final dl = _rad(b.lng - a.lng);
  final y = math.sin(dl) * math.cos(p2);
  final x =
      math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return normalizeDegrees(_deg(math.atan2(y, x)));
}

/// يشتق اتجاه السير من نقاط GPS المتتالية (heading-up، FEEDBACK 10).
/// المصدر الأول heading الجهاز إن كان يتحرك (سرعة >= [minSpeedMps] أو غير
/// معروفة)، وإلا الاتجاه بين نقطة مرجعية والنقطة الحالية حين تبتعد
/// >= [minMoveMeters]. التنعيم بمتوسط دائري؛ عند الوقوف يثبت آخر اتجاه.
class BearingTracker {
  BearingTracker({
    this.minSpeedMps = 1.0,
    this.minMoveMeters = 8,
    this.smoothing = 0.5,
  });

  final double minSpeedMps;
  final double minMoveMeters;

  /// وزن القراءة الجديدة (1 = بلا تنعيم).
  final double smoothing;

  double? _bearing;
  GeoPoint? _anchor;

  /// آخر اتجاه معروف (null قبل أول حركة).
  double? get bearing => _bearing;

  void reset() {
    _bearing = null;
    _anchor = null;
  }

  /// يغذّي موضعاً جديداً؛ يعيد الاتجاه الحالي.
  double? update(
    double lat,
    double lng, {
    double? headingDeg,
    double? speedMps,
  }) {
    final p = GeoPoint(lat, lng);
    if (!p.isValid) return _bearing;
    final moving = speedMps == null || speedMps >= minSpeedMps;
    double? raw;
    if (headingDeg != null && headingDeg.isFinite && headingDeg >= 0) {
      if (moving) raw = normalizeDegrees(headingDeg);
    } else {
      final a = _anchor;
      if (a == null) {
        _anchor = p;
      } else if (haversineMeters(a, p) >= minMoveMeters && moving) {
        raw = bearingBetween(a, p);
        _anchor = p;
      }
    }
    if (raw != null) {
      final old = _bearing;
      _bearing = old == null
          ? raw
          : normalizeDegrees(old + smoothing * shortestAngleDelta(old, raw));
    }
    return _bearing;
  }
}

/// نقطة تتقدّم [pixels] بكسل شاشة باتجاه [bearingDeg] من ([lat],[lng]) عند
/// التقريب [zoom] (إسقاط ميركاتور بلاطات 256). تُستعمل لإزاحة مركز الكاميرا
/// فتظهر العلامة في الثلث السفلي.
({double lat, double lng}) shiftAheadPixels(
  double lat,
  double lng,
  double bearingDeg,
  double pixels,
  double zoom,
) {
  final world = 256 * math.pow(2, zoom).toDouble();
  final sinLat = math.sin(_rad(lat.clamp(-85.0511, 85.0511)));
  var x = (lng + 180) / 360 * world;
  var y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * world;
  final b = _rad(bearingDeg);
  x += math.sin(b) * pixels;
  y -= math.cos(b) * pixels;
  final nLng = x / world * 360 - 180;
  final n = math.pi - 2 * math.pi * y / world;
  final nLat = _deg(math.atan(0.5 * (math.exp(n) - math.exp(-n))));
  return (lat: nLat.clamp(-90.0, 90.0), lng: nLng);
}

/// نسبة موضع العلامة من أعلى منطقة الخريطة المرئية (الثلث السفلي).
const double markerTopFraction = 0.75;
