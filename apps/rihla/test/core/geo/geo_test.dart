import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/core/geo/geo.dart';

GeoPoint p(double a, double b, {DateTime? t}) => GeoPoint(a, b, time: t);

void main() {
  group('distance', () {
    test('empty and single', () {
      expect(pathLengthMeters([]), 0);
      expect(pathLengthMeters([p(1, 1)]), 0);
      expect(pathDuration([]), Duration.zero);
      expect(pathDuration([p(1, 1)]), Duration.zero);
    });
    test('one degree of latitude ~111.2km', () {
      expect(haversineMeters(p(0, 0), p(1, 0)), closeTo(111195, 100));
    });
    test('antimeridian crossing is short', () {
      expect(haversineMeters(p(0, 179.5), p(0, -179.5)), closeTo(111195, 100));
      expect(
        pathLengthMeters([p(0, 179.5), p(0, -179.5), p(0, -178.5)]),
        closeTo(222390, 200),
      );
    });
    test('duration first to last timed point, never negative', () {
      final t0 = DateTime.utc(2026, 1, 1, 10);
      expect(
        pathDuration([
          p(0, 0),
          p(0, 0, t: t0),
          p(0, 0, t: t0.add(const Duration(minutes: 5))),
        ]),
        const Duration(minutes: 5),
      );
      expect(
        pathDuration([
          p(0, 0, t: t0),
          p(0, 0, t: t0.subtract(const Duration(seconds: 1))),
        ]),
        Duration.zero,
      );
      expect(pathDuration([p(0, 0, t: t0)]), Duration.zero);
    });
  });

  group('simplify', () {
    test('trivial inputs', () {
      expect(simplifyDouglasPeucker([], 5), isEmpty);
      expect(simplifyDouglasPeucker([p(1, 1)], 5), [p(1, 1)]);
      expect(simplifyToCount([], 5), isEmpty);
      expect(simplifyToCount([p(1, 1)], 0), [p(1, 1)]);
    });
    test('straight line collapses to endpoints', () {
      final line = [for (var i = 0; i <= 50; i++) p(0, i * 0.001)];
      final s = simplifyDouglasPeucker(line, 1);
      expect(s, [line.first, line.last]);
      expect(simplifyToCount(line, 5).length, 5);
    });
    test('keeps the corner', () {
      final path = [p(0, 0), p(0, 0.01), p(0.01, 0.01)];
      expect(simplifyDouglasPeucker(path, 10), path);
      expect(simplifyDouglasPeucker(path, 5000), [path.first, path.last]);
    });
    test('simplifyToCount: limit, order, endpoints, most significant', () {
      final path = [
        p(0, 0), p(0.0001, 0.001), p(0, 0.002), p(0.01, 0.003), // spike
        p(0, 0.004), p(0, 0.005),
      ];
      final s = simplifyToCount(path, 3);
      expect(s.length, 3);
      expect(s.first, path.first);
      expect(s.last, path.last);
      expect(s[1], path[3]);
      expect(simplifyToCount(path, 100), path);
      expect(simplifyToCount(path, 1).length, 2);
    });
    test('antimeridian: straight line across 180 simplifies away', () {
      final line = [
        p(0, 179.8),
        p(0, 179.9),
        p(0, -180),
        p(0, -179.9),
        p(0, -179.8),
      ];
      expect(simplifyDouglasPeucker(line, 1), [line.first, line.last]);
    });
    test('long path does not overflow the stack', () {
      final big = [for (var i = 0; i < 20000; i++) p(i * 1e-5, (i % 7) * 1e-5)];
      expect(simplifyToCount(big, 5).length, 5);
    });
  });

  group('google maps url', () {
    test('empty -> null, invalid -> null', () {
      expect(buildGoogleMapsUrl([]), isNull);
      expect(buildGoogleMapsUrl([p(91, 0), p(0, 0)]), isNull);
      expect(buildGoogleMapsUrl([p(double.nan, 0)]), isNull);
    });
    test('single point is a search url', () {
      final u = buildGoogleMapsUrl([p(24.7136, 46.6753)])!;
      expect(u, contains('/search/?api=1&query=24.71360%2C46.67530'));
    });
    test('two points: no waypoints', () {
      final u = buildGoogleMapsUrl([p(1, 2), p(3, 4)])!;
      expect(u, isNot(contains('waypoints')));
      expect(Uri.parse(u).queryParameters['origin'], '1.00000,2.00000');
      expect(Uri.parse(u).queryParameters['destination'], '3.00000,4.00000');
    });
    test('default 3 mid points, pipe and comma are encoded', () {
      final path = [
        for (var i = 0; i < 100; i++) p(i * 0.01, (i * i % 13) * 0.01),
      ];
      final u = buildGoogleMapsUrl(path)!;
      expect(u.length, lessThanOrEqualTo(2048));
      expect(u, contains('%7C'));
      expect(u, isNot(contains('|')));
      expect(u, isNot(contains(',')));
      final wp = Uri.parse(u).queryParameters['waypoints']!.split('|');
      expect(wp.length, 3);
    });
    test('negative and antimeridian coordinates', () {
      final u = buildGoogleMapsUrl([p(-33.8, 179.99), p(-33.9, -179.99)])!;
      expect(Uri.parse(u).queryParameters['origin'], '-33.80000,179.99000');
      expect(
        Uri.parse(u).queryParameters['destination'],
        '-33.90000,-179.99000',
      );
    });
    test('respects maxLength by dropping waypoints, else null', () {
      final path = [for (var i = 0; i < 50; i++) p(i * 0.1, i * 0.1)];
      final full = buildGoogleMapsUrl(path)!;
      final shorter = buildGoogleMapsUrl(path, maxLength: full.length - 1)!;
      expect(shorter.length, lessThan(full.length));
      expect(buildGoogleMapsUrl(path, maxLength: 20), isNull);
      for (final m in [0, 1, 5, 40]) {
        expect(
          buildGoogleMapsUrl(path, midWaypoints: m, maxLength: 2048)!.length,
          lessThanOrEqualTo(2048),
        );
      }
    });
  });

  group('gpx', () {
    test('empty path is valid gpx without trkpt', () {
      final g = buildGpx([]);
      expect(g, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(g, contains('<trkseg>'));
      expect(g, isNot(contains('<trkpt')));
      expect(g.trimRight(), endsWith('</gpx>'));
    });
    test('points with time and elevation', () {
      final t = DateTime.utc(2026, 11, 14, 8, 30, 5);
      final g = buildGpx([GeoPoint(24.5, -46.25, time: t, elevation: 612.5)]);
      expect(g, contains('<trkpt lat="24.5" lon="-46.25">'));
      expect(g, contains('<ele>612.5</ele>'));
      expect(g, contains('<time>2026-11-14T08:30:05.000Z</time>'));
    });
    test('non-UTC time converted to UTC; invalid points skipped', () {
      final g = buildGpx([p(100, 0), p(1, 2)]);
      expect('<trkpt'.allMatches(g).length, 1);
    });
    test('name with Arabic and XML special chars is escaped', () {
      final g = buildGpx([], name: 'رحلة <A&B> "x"\u0001');
      expect(g, contains('<name>رحلة &lt;A&amp;B&gt; &quot;x&quot;</name>'));
    });
    test('antimeridian points kept as given', () {
      final g = buildGpx([p(0, 179.999999), p(0, -179.999999)]);
      expect(g, contains('lon="179.999999"'));
      expect(g, contains('lon="-179.999999"'));
    });
  });
}
