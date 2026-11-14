import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/core/geo/geo.dart';
import 'package:xml/xml.dart';

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
    test('NaN points do not throw', () {
      final path = [p(0, 0), p(double.nan, 0.001), p(0, 0.002), p(0, 0.003)];
      expect(() => simplifyDouglasPeucker(path, 5), returnsNormally);
      expect(() => simplifyToCount(path, 3), returnsNormally);
      final allNan = [
        p(double.nan, double.nan),
        p(double.nan, double.nan),
        p(double.nan, double.nan),
      ];
      expect(() => simplifyDouglasPeucker(allNan, 5), returnsNormally);
      expect(simplifyToCount(path, 3).first, path.first);
      expect(simplifyToCount(path, 3).last, path.last);
    });
    test('out-of-range coordinates do not throw and keep endpoints', () {
      final path = [p(0, 0), p(95, 200), p(0, 0.002), p(-100, -500), p(0, 1)];
      final s = simplifyDouglasPeucker(path, 5);
      expect(s.first, path.first);
      expect(s.last, path.last);
      final c = simplifyToCount(path, 3);
      expect(c.length, 3);
      expect(c.first, path.first);
      expect(c.last, path.last);
    });
    test('identical points collapse to endpoints', () {
      final same = [for (var i = 0; i < 10; i++) p(5, 5)];
      expect(simplifyDouglasPeucker(same, 1), [same.first, same.last]);
      expect(simplifyToCount(same, 4).length, 4);
      final loop = [p(1, 1), p(1.01, 1.01), p(1.02, 1.0), p(1, 1)];
      expect(simplifyDouglasPeucker(loop, 10).length, greaterThan(2));
    });
    test('long path does not overflow the stack', () {
      final big = [for (var i = 0; i < 20000; i++) p(i * 1e-5, (i % 7) * 1e-5)];
      expect(simplifyToCount(big, 5).length, 5);
    });
  });

  group('maps link: movement judged by farthest point and path length', () {
    // حلقة ~1 كم نصف قطرها: بداية = نهاية
    List<GeoPoint> loop(int n, double r) => [
      for (var i = 0; i <= n; i++)
        p(
          10 + r * math.sin(2 * math.pi * i / n),
          20 + r * (1 - math.cos(2 * math.pi * i / n)),
        ),
    ];
    test('circular long trip (start == end): directions with waypoints', () {
      final path = loop(40, 0.005);
      expect(haversineMeters(path.first, path.last), lessThan(1));
      final l = buildMapsLink(path)!;
      expect(l.kind, MapsLinkKind.route);
      final q = Uri.parse(l.url).queryParameters;
      expect(q['origin'], q['destination']);
      expect(q['waypoints']!.split('|').length, 3);
      expect(q['api'], '1');
      expect(q['travelmode'], 'driving');
      expect(l.url.length, lessThanOrEqualTo(2048));
      expect(l.url, startsWith('https://www.google.com/maps/dir/?api=1&'));
    });
    test('circular at any url budget: never origin==destination bare', () {
      final path = loop(40, 0.005);
      var sawBare = false;
      for (var max = 120; max <= 400; max += 10) {
        final l = buildMapsLink(path, maxLength: max);
        if (l == null) continue;
        final q = Uri.parse(l.url).queryParameters;
        if (q['waypoints'] == null) {
          sawBare = true;
          expect(q['origin'], isNot(q['destination']));
        }
      }
      expect(sawBare, isTrue);
    });
    test('short wander (< 50 m from start, short path): location', () {
      final path = [p(10, 20), p(10.0001, 20), p(10, 20.0001), p(10, 20)];
      expect(hasMovement(path), isFalse);
      expect(buildMapsLink(path)!.kind, MapsLinkKind.location);
    });
    test('identical points: location', () {
      final path = [for (var i = 0; i < 5; i++) p(10, 20)];
      expect(buildMapsLink(path)!.kind, MapsLinkKind.location);
    });
    test('long straight: route', () {
      expect(
        buildMapsLink([p(10, 20), p(10.01, 20)])!.kind,
        MapsLinkKind.route,
      );
    });
    test('invalid point: no link (share sheet uses same rule)', () {
      expect(buildMapsLink([p(10, 20), p(95, 20)]), isNull);
      expect(hasMovement([p(10, 20), p(95, 20)]), isFalse);
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
      expect(u, contains('/search/?api=1&query=24.713600%2C46.675300'));
    });
    test('zero points: no link', () {
      expect(buildMapsLink([]), isNull);
    });
    test('one point: location link of that point, 6 decimals', () {
      final l = buildMapsLink([p(18.51841, 42.06458)])!;
      expect(l.kind, MapsLinkKind.location);
      expect(l.url, contains('/maps/search/?api=1&query='));
      expect(l.url, contains('18.518410%2C42.064580'));
      expect(l.url, isNot(contains('/dir/')));
    });
    test('identical start and end (owner screenshot): location, no dir', () {
      final a = p(18.51841, 42.06458);
      final l = buildMapsLink([a, p(18.51841, 42.06458), a])!;
      expect(l.kind, MapsLinkKind.location);
      expect(l.url, isNot(contains('origin=')));
    });
    test('start-end under 50 m: location of last point', () {
      // 0.0002 deg lat ~ 22 m
      final l = buildMapsLink([p(10, 20), p(10.0001, 20), p(10.0002, 20)])!;
      expect(l.kind, MapsLinkKind.location);
      expect(l.url, contains('10.000200%2C20.000000'));
    });
    test('start-end just over 50 m: directions with 6-decimal coords', () {
      // 0.00050 deg ~ 55.6 m
      final l = buildMapsLink([p(10, 20), p(10.0005, 20)])!;
      expect(l.kind, MapsLinkKind.route);
      expect(l.url, contains('origin=10.000000%2C20.000000'));
      expect(l.url, contains('destination=10.000500%2C20.000000'));
    });
    test('long route: directions', () {
      final path = [for (var i = 0; i < 50; i++) p(24 + i * 0.01, 46)];
      final l = buildMapsLink(path)!;
      expect(l.kind, MapsLinkKind.route);
      expect(l.url, contains('/dir/'));
    });
    test('two points: no waypoints', () {
      final u = buildGoogleMapsUrl([p(1, 2), p(3, 4)])!;
      expect(u, isNot(contains('waypoints')));
      expect(Uri.parse(u).queryParameters['origin'], '1.000000,2.000000');
      expect(Uri.parse(u).queryParameters['destination'], '3.000000,4.000000');
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
    test('travelmode defaults to driving and is overridable', () {
      final u = buildGoogleMapsUrl([p(1, 2), p(3, 4)])!;
      expect(Uri.parse(u).queryParameters['travelmode'], 'driving');
      final w = buildGoogleMapsUrl([p(1, 2), p(3, 4)], travelMode: 'walking')!;
      expect(Uri.parse(w).queryParameters['travelmode'], 'walking');
      final path = [for (var i = 0; i < 50; i++) p(i * 0.1, i * 0.1)];
      final m = buildGoogleMapsUrl(path)!;
      expect(Uri.parse(m).queryParameters['travelmode'], 'driving');
      expect(m.length, lessThanOrEqualTo(2048));
    });
    test('negative and antimeridian coordinates', () {
      final u = buildGoogleMapsUrl([p(-33.8, 179.99), p(-33.9, -179.99)])!;
      expect(Uri.parse(u).queryParameters['origin'], '-33.800000,179.990000');
      expect(
        Uri.parse(u).queryParameters['destination'],
        '-33.900000,-179.990000',
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

  group('gpx (real XML parser)', () {
    XmlDocument parse(String g) => XmlDocument.parse(g);
    Iterable<XmlElement> trkpts(XmlDocument d) => d.findAllElements('trkpt');

    test('empty path parses, has trkseg and no trkpt', () {
      final d = parse(buildGpx([]));
      expect(d.rootElement.name.local, 'gpx');
      expect(d.rootElement.getAttribute('version'), '1.1');
      expect(d.findAllElements('trkseg').length, 1);
      expect(trkpts(d), isEmpty);
    });
    test('50 points with ele and time round-trip', () {
      final t0 = DateTime.utc(2026, 11, 14, 8);
      final pts = [
        for (var i = 0; i < 50; i++)
          GeoPoint(
            24 + i * 0.001,
            -46.25 + i * 0.002,
            time: t0.add(Duration(seconds: i)),
            elevation: 600 + i * 0.5,
          ),
      ];
      final d = parse(buildGpx(pts, time: t0));
      final list = trkpts(d).toList();
      expect(list.length, 50);
      for (var i = 0; i < 50; i++) {
        final e = list[i];
        expect(double.parse(e.getAttribute('lat')!), closeTo(pts[i].lat, 1e-6));
        expect(double.parse(e.getAttribute('lon')!), closeTo(pts[i].lng, 1e-6));
        expect(
          double.parse(e.getElement('ele')!.innerText),
          closeTo(pts[i].elevation!, 1e-6),
        );
        expect(DateTime.parse(e.getElement('time')!.innerText), pts[i].time);
      }
      expect(DateTime.parse(d.findAllElements('time').first.innerText), t0);
    });
    test('non-UTC time converted to UTC; invalid points skipped', () {
      final local = DateTime.parse('2026-11-14T10:00:00+03:00');
      final d = parse(buildGpx([p(100, 0), GeoPoint(1, 2, time: local)]));
      final list = trkpts(d).toList();
      expect(list.length, 1);
      expect(list.single.getElement('time')!.innerText, endsWith('Z'));
      expect(
        DateTime.parse(list.single.getElement('time')!.innerText),
        DateTime.utc(2026, 11, 14, 7),
      );
    });
    test('Arabic name with <&"\' round-trips exactly', () {
      const name = 'رحلة <A&B> "x" \'y\'';
      final d = parse(buildGpx([], name: name));
      expect(d.findAllElements('name').single.innerText, name);
    });
    test('control characters are stripped and document still parses', () {
      final g = buildGpx([], name: 'a\u0000b\u0001c\u0008d\u000Be\u001Ff');
      final d = parse(g);
      expect(d.findAllElements('name').single.innerText, 'abcdef');
    });
    test('antimeridian points kept as given', () {
      final list = trkpts(
        parse(buildGpx([p(0, 179.999999), p(0, -179.999999)])),
      ).map((e) => double.parse(e.getAttribute('lon')!)).toList();
      expect(list, [179.999999, -179.999999]);
    });
  });
}
