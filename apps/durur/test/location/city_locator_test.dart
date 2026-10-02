import 'dart:async';

import 'package:durur/src/location/city_locator.dart';
import 'package:durur/src/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_location_service.dart';

Future<void> main() async {
  final tables = await loadAssetTables();
  final cities = tables.cities;

  Future<LocateResult> locate(
    FakeLocationService s, {
    Duration timeLimit = locationTimeLimit,
  }) => CityLocator(s, timeLimit: timeLimit).locate(cities);

  test('حد القراءة 10 ثوانٍ (SPEC الميزة 4 بند 4)', () {
    expect(locationTimeLimit, const Duration(seconds: 10));
  });

  group('النجاح', () {
    test(
      'إذن ممنوح: قراءة واحدة بحد 10 ث ثم أقرب مدينة، بلا طلب إذن',
      () async {
        final s = FakeLocationService();
        final r = await locate(s);
        expect(r, isA<LocateFound>());
        expect((r as LocateFound).city.id, 'riyadh');
        expect(s.reads, 1);
        expect(s.lastTimeLimit, const Duration(seconds: 10));
        expect(s.permissionRequests, 0);
      },
    );

    test('إذن غير ممنوح: يُطلب مرة، ثم قراءة واحدة', () async {
      final s = FakeLocationService(
        permission: LocationAccess.denied,
        position: FakeLocationService.muscat,
      );
      final r = await locate(s);
      expect((r as LocateFound).city.id, 'muscat');
      expect(s.permissionRequests, 1);
      expect(s.reads, 1);
    });
  });

  group('الرفض والتعطّل', () {
    test('رفض الإذن الآن ← LocateDenied، بلا قراءة', () async {
      final s = FakeLocationService(
        permission: LocationAccess.denied,
        afterRequest: LocationAccess.denied,
      );
      expect(await locate(s), isA<LocateDenied>());
      expect(s.reads, 0);
    });

    test('رفض نهائي الآن (لا تسألني مجدداً) ← LocateDenied', () async {
      final s = FakeLocationService(
        permission: LocationAccess.denied,
        afterRequest: LocationAccess.deniedForever,
      );
      expect(await locate(s), isA<LocateDenied>());
      expect(s.reads, 0);
    });

    test('رفض نهائي سابق ← LocateUnavailable، بلا طلب ولا قراءة', () async {
      final s = FakeLocationService(permission: LocationAccess.deniedForever);
      expect(await locate(s), isA<LocateUnavailable>());
      expect(s.permissionRequests, 0);
      expect(s.reads, 0);
    });

    test('خدمة الموقع مطفأة ← LocateUnavailable، بلا طلب إذن', () async {
      final s = FakeLocationService(serviceEnabled: false);
      expect(await locate(s), isA<LocateUnavailable>());
      expect(s.permissionChecks, 0);
      expect(s.permissionRequests, 0);
      expect(s.reads, 0);
    });

    test('حالة إذن غير معروفة ← LocateUnavailable', () async {
      expect(
        await locate(FakeLocationService(permission: LocationAccess.unknown)),
        isA<LocateUnavailable>(),
      );
      expect(
        await locate(
          FakeLocationService(
            permission: LocationAccess.denied,
            afterRequest: LocationAccess.unknown,
          ),
        ),
        isA<LocateUnavailable>(),
      );
    });
  });

  group('فشل القراءة', () {
    test(
      'لا نتيجة خلال الحد ← LocateTimeout (حتى لو تجاهلت المنصة الحد)',
      () async {
        final s = FakeLocationService(pending: Completer());
        final r = await locate(s, timeLimit: const Duration(milliseconds: 20));
        expect(r, isA<LocateTimeout>());
        expect(s.reads, 1);
      },
    );

    test('المنصة ترمي TimeoutException ← LocateTimeout', () async {
      final s = FakeLocationService(error: TimeoutException('x'));
      expect(await locate(s), isA<LocateTimeout>());
    });

    test('الخدمة تتعطل أثناء القراءة ← LocateUnavailable', () async {
      final s = FakeLocationService(
        error: const LocationUnavailableException(),
      );
      expect(await locate(s), isA<LocateUnavailable>());
    });

    test('سحب الإذن أثناء القراءة ← LocateDenied', () async {
      final s = FakeLocationService(error: const LocationPermissionException());
      expect(await locate(s), isA<LocateDenied>());
    });

    test('أي خطأ آخر من المنصة ← LocateUnavailable', () async {
      final s = FakeLocationService(error: Exception('platform'));
      expect(await locate(s), isA<LocateUnavailable>());
    });
  });

  group('خارج النطاق', () {
    test('لندن ← LocateOutOfRange', () async {
      final s = FakeLocationService(position: FakeLocationService.london);
      expect(await locate(s), isA<LocateOutOfRange>());
    });

    test('قائمة مدن فارغة ← LocateOutOfRange', () async {
      final r = await CityLocator(FakeLocationService()).locate(const []);
      expect(r, isA<LocateOutOfRange>());
    });
  });
}
