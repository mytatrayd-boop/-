// يولّد lib/src/features/common/gulf_map_data.dart: سواحل الخليج مبسّطة لخلفية
// الشاشة الرئيسية (DESIGN R3.1-13). المصدر: Natural Earth، طبقة اليابسة
// 1:10m (ملكية عامة)، ملف ne_10m_land.geojson من المستودع الرسمي
// github.com/nvkelso/natural-earth-vector.
//
// الاستخدام (من داخل apps/durur):
//   dart run tool/gen_gulf_map.dart <path/to/ne_10m_land.geojson>
//
// النطاق: الطول 50°–60.5° شرقاً، والعرض 21°–28° شمالاً، بإسقاط متساوي
// المسافات (x = الطول × cos 24.5°)، مبسّطاً بخوارزمية دوغلاس-بيوكر إلى نحو
// 300 نقطة. الإحداثيات الناتجة نسبية [0، 1] من عرض المستطيل وارتفاعه.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const minLon = 50.0, maxLon = 60.5, minLat = 21.0, maxLat = 28.0;
const targetPoints = 300;
const out = 'lib/src/features/common/gulf_map_data.dart';

typedef P = (double, double); // (x, y) بالدرجات المسقطة

final _k = math.cos((minLat + maxLat) / 2 * math.pi / 180);

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('الاستخدام: dart run tool/gen_gulf_map.dart <ne_10m_land.geojson>');
    exit(64);
  }
  final json = jsonDecode(await File(args.first).readAsString()) as Map;
  final rings = <List<P>>[];
  for (final f in json['features'] as List) {
    final g = (f as Map)['geometry'] as Map;
    final polys = g['type'] == 'Polygon'
        ? [g['coordinates'] as List]
        : (g['coordinates'] as List);
    for (final poly in polys) {
      for (final ring in poly as List) {
        final pts = [
          for (final c in ring as List)
            ((c as List)[0] as num).toDouble(),
        ];
        final lats = [for (final c in ring) ((c as List)[1] as num).toDouble()];
        var inBox = false;
        for (var i = 0; i < pts.length; i++) {
          if (pts[i] >= minLon - 1 &&
              pts[i] <= maxLon + 1 &&
              lats[i] >= minLat - 1 &&
              lats[i] <= maxLat + 1) {
            inBox = true;
            break;
          }
        }
        if (!inBox) continue;
        final clipped = _clip([
          for (var i = 0; i < pts.length; i++) (pts[i], lats[i]),
        ]);
        if (clipped.length >= 3) rings.add(clipped);
      }
    }
  }

  // تبسيط بتسامح يتزايد حتى يقارب العدد الهدف.
  var tol = 0.005;
  late List<List<P>> simple;
  while (true) {
    simple = [
      for (final r in rings)
        if (_area(r).abs() > tol * tol * 4) _dp(r, tol),
    ]..removeWhere((r) => r.length < 3);
    final n = simple.fold<int>(0, (a, r) => a + r.length);
    if (n <= targetPoints) break;
    tol *= 1.15;
  }
  final total = simple.fold<int>(0, (a, r) => a + r.length);
  final w = (maxLon - minLon) * _k;
  const h = maxLat - minLat;
  String f(double v) => v.toStringAsFixed(4);
  final b = StringBuffer()
    ..writeln('// مولّد بـ tool/gen_gulf_map.dart — لا يُعدَّل يدوياً.')
    ..writeln('// المصدر: Natural Earth، اليابسة 1:10m (ملكية عامة).')
    ..writeln('// النطاق ${minLon.toStringAsFixed(1)}°–${maxLon.toStringAsFixed(1)}° شرقاً، '
        '${minLat.toStringAsFixed(0)}°–${maxLat.toStringAsFixed(0)}° شمالاً، '
        'إسقاط متساوي المسافات؛ $total نقطة.')
    ..writeln()
    ..writeln('/// نسبة العرض إلى الارتفاع للمستطيل المسقط.')
    ..writeln('const double gulfMapAspect = ${f(w / h)};')
    ..writeln()
    ..writeln('/// مضلّعات اليابسة: أزواج (x، y) نسبية [0، 1]، y من الأعلى.')
    ..writeln('const List<List<double>> gulfMapLand = [');
  for (final r in simple) {
    b.write('  [');
    b.write([
      for (final (x, y) in r) '${f((x - minLon) * _k / w)}, ${f((maxLat - y) / h)}',
    ].join(', '));
    b.writeln('],');
  }
  b.writeln('];');
  await File(out).writeAsString(b.toString());
  print('كُتب $out: ${simple.length} مضلّع، $total نقطة (تسامح ${tol.toStringAsFixed(4)}°).');
}

/// قص Sutherland–Hodgman بالمستطيل (بالدرجات قبل الإسقاط).
List<P> _clip(List<P> poly) {
  List<P> edge(List<P> input, bool Function(P) inside, P Function(P, P) cross) {
    final output = <P>[];
    for (var i = 0; i < input.length; i++) {
      final cur = input[i];
      final prev = input[(i - 1 + input.length) % input.length];
      if (inside(cur)) {
        if (!inside(prev)) output.add(cross(prev, cur));
        output.add(cur);
      } else if (inside(prev)) {
        output.add(cross(prev, cur));
      }
    }
    return output;
  }

  P atX(P a, P b, double x) =>
      (x, a.$2 + (b.$2 - a.$2) * (x - a.$1) / (b.$1 - a.$1));
  P atY(P a, P b, double y) =>
      (a.$1 + (b.$1 - a.$1) * (y - a.$2) / (b.$2 - a.$2), y);
  var p = poly;
  p = edge(p, (q) => q.$1 >= minLon, (a, b) => atX(a, b, minLon));
  if (p.isEmpty) return p;
  p = edge(p, (q) => q.$1 <= maxLon, (a, b) => atX(a, b, maxLon));
  if (p.isEmpty) return p;
  p = edge(p, (q) => q.$2 >= minLat, (a, b) => atY(a, b, minLat));
  if (p.isEmpty) return p;
  p = edge(p, (q) => q.$2 <= maxLat, (a, b) => atY(a, b, maxLat));
  return p;
}

double _area(List<P> r) {
  var s = 0.0;
  for (var i = 0; i < r.length; i++) {
    final a = r[i], b = r[(i + 1) % r.length];
    s += a.$1 * _k * b.$2 - b.$1 * _k * a.$2;
  }
  return s / 2;
}

/// دوغلاس-بيوكر على حلقة مغلقة (المسافة بالدرجات المسقطة).
List<P> _dp(List<P> r, double tol) {
  if (r.length < 4) return r;
  // نقسم الحلقة عند أبعد نقطتين تقريباً: الأولى والأبعد عنها.
  var far = 0;
  var best = -1.0;
  for (var i = 1; i < r.length; i++) {
    final d = _dist(r[0], r[i]);
    if (d > best) {
      best = d;
      far = i;
    }
  }
  final a = _dpLine(r.sublist(0, far + 1), tol);
  final b = _dpLine([...r.sublist(far), r[0]], tol);
  return [...a.sublist(0, a.length - 1), ...b.sublist(0, b.length - 1)];
}

List<P> _dpLine(List<P> pts, double tol) {
  if (pts.length < 3) return pts;
  var idx = 0;
  var maxD = 0.0;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = _segDist(pts[i], pts.first, pts.last);
    if (d > maxD) {
      maxD = d;
      idx = i;
    }
  }
  if (maxD <= tol) return [pts.first, pts.last];
  final l = _dpLine(pts.sublist(0, idx + 1), tol);
  final rr = _dpLine(pts.sublist(idx), tol);
  return [...l.sublist(0, l.length - 1), ...rr];
}

double _dist(P a, P b) {
  final dx = (a.$1 - b.$1) * _k, dy = a.$2 - b.$2;
  return math.sqrt(dx * dx + dy * dy);
}

double _segDist(P p, P a, P b) {
  final ax = a.$1 * _k, ay = a.$2, bx = b.$1 * _k, by = b.$2;
  final px = p.$1 * _k, py = p.$2;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}
