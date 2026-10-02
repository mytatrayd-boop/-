import 'package:durur/src/domain/city.dart';
import 'package:durur/src/location/nearest_city.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

City _city(String id, double lat, double lon) => City.fromJson({
  'id': id,
  'name': {'ar': id},
  'country': 'SA',
  'lat': lat,
  'lon': lon,
  'regionId': 'najd',
  'source': {'title': 't'},
  'approval': {'status': 'draft'},
}, 'test');

Future<void> main() async {
  final tables = await loadAssetTables();

  group('haversineKm', () {
    test('نفس النقطة = 0', () {
      expect(haversineKm(24.7, 46.7, 24.7, 46.7), 0);
    });

    test('درجة طول على خط الاستواء ≈ 111.2 كم', () {
      expect(haversineKm(0, 0, 0, 1), closeTo(111.19, 0.05));
    });

    test('الرياض ← مدينة الكويت ≈ 535 كم (مسافة الدائرة العظمى)', () {
      expect(haversineKm(24.6877, 46.7219, 29.367, 47.9743), closeTo(535, 2));
    });

    test('متماثلة ولا تتأثر بعبور خط الطول 180', () {
      expect(
        haversineKm(10, 20, 30, 40),
        closeTo(haversineKm(30, 40, 10, 20), 1e-9),
      );
      expect(haversineKm(0, 179.5, 0, -179.5), closeTo(111.19, 0.05));
    });
  });

  group('findNearestCity', () {
    test('قائمة فارغة ← null', () {
      expect(findNearestCity(const [], 24, 46), isNull);
    });

    test('مدن حقيقية: أقرب مدينة صحيحة', () {
      final cases = {
        (24.70, 46.70): 'riyadh',
        (29.37, 47.97): 'kuwait_city',
        (23.60, 58.50): 'muscat',
        (25.29, 51.53): 'doha',
        (26.43, 50.10): 'dammam',
      };
      for (final MapEntry(key: (lat, lon), value: id) in cases.entries) {
        final n = findNearestCity(tables.cities, lat, lon)!;
        expect(n.city.id, id, reason: '($lat, $lon)');
        expect(n.inRange, isTrue);
        expect(n.distanceKm, lessThan(30));
      }
    });

    test('خارج الخليج (لندن، القاهرة) ← أبعد من 250 كم', () {
      for (final (lat, lon) in [(51.5074, -0.1278), (30.0444, 31.2357)]) {
        final n = findNearestCity(tables.cities, lat, lon)!;
        expect(n.inRange, isFalse, reason: '($lat, $lon)');
        expect(n.distanceKm, greaterThan(maxNearestCityKm));
      }
    });

    test('حد 250 كم: داخل الحد مقبول، وبعده خارج النطاق', () {
      final c = _city('c', 0, 0);
      // 1 درجة طول على خط الاستواء ≈ 111.19 كم.
      final inside = findNearestCity([c], 0, 249 / 111.195)!;
      final outside = findNearestCity([c], 0, 251 / 111.195)!;
      expect(inside.inRange, isTrue);
      expect(outside.inRange, isFalse);
      expect(maxNearestCityKm, 250);
    });

    test('عند التساوي تُختار الأسبق في القائمة', () {
      final a = _city('a', 0, 1);
      final b = _city('b', 0, -1);
      expect(findNearestCity([a, b], 0, 0)!.city.id, 'a');
      expect(findNearestCity([b, a], 0, 0)!.city.id, 'b');
    });
  });
}
