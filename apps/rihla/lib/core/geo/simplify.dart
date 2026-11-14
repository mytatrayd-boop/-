import 'dart:math' as math;

import 'distance.dart';
import 'geo_point.dart';

/// بُعد النقطة عن القطعة a-b بالمتر، بإسقاط محلي مسطّح حول a.
/// فرق خط الطول يُطبَّع إلى [-180,180] فيصح عبر خط التاريخ.
double _perpMeters(GeoPoint p, GeoPoint a, GeoPoint b) {
  final cosLat = math.cos(a.lat * math.pi / 180);
  const mPerDeg = earthRadiusMeters * math.pi / 180;
  double dx(GeoPoint q) {
    var d = q.lng - a.lng;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d * cosLat * mPerDeg;
  }

  double dy(GeoPoint q) => (q.lat - a.lat) * mPerDeg;

  final bx = dx(b), by = dy(b), px = dx(p), py = dy(p);
  final len2 = bx * bx + by * by;
  if (len2 == 0) return math.sqrt(px * px + py * py);
  final t = ((px * bx + py * by) / len2).clamp(0.0, 1.0);
  final cx = bx * t, cy = by * t;
  final ex = px - cx, ey = py - cy;
  return math.sqrt(ex * ex + ey * ey);
}

/// أهمية كل نقطة حسب Douglas-Peucker: أكبر بُعد عندما تُختار النقطة.
/// الطرفان = infinity. تكرارية (بلا عمق استدعاء) لتحمّل مسارات طويلة.
List<double> _importance(List<GeoPoint> pts) {
  final n = pts.length;
  final imp = List<double>.filled(n, 0);
  imp[0] = double.infinity;
  imp[n - 1] = double.infinity;
  final stack = <(int, int)>[(0, n - 1)];
  while (stack.isNotEmpty) {
    final (s, e) = stack.removeLast();
    if (e - s < 2) continue;
    var maxD = -1.0;
    var idx = -1;
    for (var i = s + 1; i < e; i++) {
      var d = _perpMeters(pts[i], pts[s], pts[e]);
      if (d.isNaN) d = 0; // نقطة غير صالحة: أقل أهمية بدل كسر الخوارزمية
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    imp[idx] = maxD;
    stack.add((s, idx));
    stack.add((idx, e));
  }
  return imp;
}

/// Douglas-Peucker بتسامح بالمتر. يُبقي البداية والنهاية دائماً.
List<GeoPoint> simplifyDouglasPeucker(
  List<GeoPoint> points,
  double toleranceMeters,
) {
  if (points.length <= 2) return List.of(points);
  final imp = _importance(points);
  final out = <GeoPoint>[];
  for (var i = 0; i < points.length; i++) {
    if (imp[i] > toleranceMeters || imp[i].isInfinite) out.add(points[i]);
  }
  return out;
}

/// يُبقي على الأكثر [maxPoints] نقطة (شاملةً الطرفين) بأعلى أهمية DP،
/// بالترتيب الأصلي. maxPoints < 2 يُعامل كـ2 (أو الكل إن كان أقل).
List<GeoPoint> simplifyToCount(List<GeoPoint> points, int maxPoints) {
  final limit = math.max(2, maxPoints);
  if (points.length <= limit) return List.of(points);
  final imp = _importance(points);
  final inner = [for (var i = 1; i < points.length - 1; i++) i]
    ..sort((a, b) {
      final c = imp[b].compareTo(imp[a]);
      return c != 0 ? c : a.compareTo(b);
    });
  final keep = <int>{0, points.length - 1, ...inner.take(limit - 2)};
  final sorted = keep.toList()..sort();
  return [for (final i in sorted) points[i]];
}
