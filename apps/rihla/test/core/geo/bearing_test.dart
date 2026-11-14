import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/core/geo/geo.dart';

void main() {
  group('bearingBetween', () {
    test('cardinal directions', () {
      const o = GeoPoint(10, 20);
      expect(bearingBetween(o, const GeoPoint(11, 20)), closeTo(0, 0.01));
      expect(bearingBetween(o, const GeoPoint(10, 21)), closeTo(90, 0.5));
      expect(bearingBetween(o, const GeoPoint(9, 20)), closeTo(180, 0.01));
      expect(bearingBetween(o, const GeoPoint(10, 19)), closeTo(270, 0.5));
    });
    test('across the antimeridian', () {
      expect(
        bearingBetween(const GeoPoint(0, 179.9), const GeoPoint(0, -179.9)),
        closeTo(90, 0.01),
      );
    });
  });

  group('BearingTracker', () {
    test('uses device heading when moving', () {
      final t = BearingTracker();
      expect(
        t.update(10, 20, headingDeg: 135, speedMps: 12),
        closeTo(135, 1e-9),
      );
    });
    test('ignores heading when stationary and keeps the last bearing', () {
      final t = BearingTracker();
      t.update(10, 20, headingDeg: 90, speedMps: 12);
      t.update(10, 20, headingDeg: 270, speedMps: 0.1);
      expect(t.bearing, closeTo(90, 1e-9));
    });
    test('falls back to last two points beyond the distance threshold', () {
      final t = BearingTracker();
      expect(t.update(10, 20), isNull);
      // ~2 m: below threshold -> still unknown
      expect(t.update(10.00002, 20), isNull);
      // ~111 m north from anchor -> 0
      expect(t.update(10.001, 20), closeTo(0, 0.01));
      // then east
      final b = t.update(10.001, 20.001)!;
      expect(b, closeTo(45, 1)); // smoothed halfway from 0 to 90
    });
    test('stationary after moving holds the bearing', () {
      final t = BearingTracker();
      t.update(10, 20);
      t.update(10, 20.001);
      final b = t.bearing;
      t.update(10, 20.001);
      t.update(10.000001, 20.001);
      expect(t.bearing, b);
    });
    test('smoothing takes the shortest way around north', () {
      final t = BearingTracker();
      t.update(0, 0, headingDeg: 350, speedMps: 10);
      final b = t.update(0, 0, headingDeg: 10, speedMps: 10)!;
      expect(b, closeTo(0, 1e-9));
    });
    test('invalid position ignored', () {
      final t = BearingTracker();
      expect(t.update(double.nan, 0), isNull);
    });
  });

  group('shiftAheadPixels', () {
    test(
      'north moves lat up, east moves lng up, no drift on the other axis',
      () {
        final n = shiftAheadPixels(10, 20, 0, 200, 16);
        expect(n.lat, greaterThan(10));
        expect(n.lng, closeTo(20, 1e-9));
        final e = shiftAheadPixels(10, 20, 90, 200, 16);
        expect(e.lng, greaterThan(20));
        expect(e.lat, closeTo(10, 1e-6));
      },
    );
    test('zero pixels is identity', () {
      final r = shiftAheadPixels(24.7, 46.7, 123, 0, 15);
      expect(r.lat, closeTo(24.7, 1e-9));
      expect(r.lng, closeTo(46.7, 1e-9));
    });
  });
}
