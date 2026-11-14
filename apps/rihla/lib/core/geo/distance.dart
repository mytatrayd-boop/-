import 'dart:math' as math;

import 'geo_point.dart';

const double earthRadiusMeters = 6371008.8;

double _rad(double d) => d * math.pi / 180;

/// مسافة هافرساين بالمتر. صحيحة عبر خط التاريخ (180/-180).
double haversineMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  final c = 2 * math.asin(math.min(1.0, math.sqrt(h.toDouble())));
  return earthRadiusMeters * c;
}

/// طول المسار الكلي بالمتر. 0 لمسار فارغ أو نقطة واحدة.
double pathLengthMeters(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

/// المدة بين أول وآخر نقطة لهما وقت. Duration.zero إن لم توجد نقطتان بوقت.
/// لا تُرجع قيمة سالبة.
Duration pathDuration(List<GeoPoint> points) {
  DateTime? first;
  DateTime? last;
  for (final p in points) {
    final t = p.time;
    if (t == null) continue;
    first ??= t;
    last = t;
  }
  if (first == null || last == null) return Duration.zero;
  final d = last.difference(first);
  return d.isNegative ? Duration.zero : d;
}
