import 'dart:async';

import 'package:bunn_lens/features/cafes/data/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  bool serviceOn = true;
  LocationPermission current = LocationPermission.denied;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  Object? positionError;
  int requests = 0;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;
  @override
  Future<LocationPermission> checkPermission() async => current;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return current = afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    settings = locationSettings;
    if (positionError != null) throw positionError!;
    return Position(
      latitude: 24.7,
      longitude: 46.6,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late _FakePlatform p;
  late GeolocatorLocationService s;
  setUp(() {
    p = _FakePlatform();
    s = GeolocatorLocationService(platform: p);
  });

  test('يطلب الإذن ثم يعيد الموقع مع المهلة', () async {
    final r = await s.getCurrentLocation(timeout: const Duration(seconds: 7));
    expect(r.isSuccess, isTrue);
    expect((r.lat, r.lng), (24.7, 46.6));
    expect(p.requests, 1);
    expect(p.settings!.timeLimit, const Duration(seconds: 7));
  });

  test('إذن ممنوح مسبقاً لا يُطلب مرة أخرى', () async {
    p.current = LocationPermission.whileInUse;
    await s.getCurrentLocation();
    expect(p.requests, 0);
  });

  test('رفض الإذن', () async {
    p.afterRequest = LocationPermission.denied;
    expect((await s.getCurrentLocation()).failure, LocationFailure.denied);
  });

  test('رفض دائم بلا طلب', () async {
    p.current = LocationPermission.deniedForever;
    expect((await s.getCurrentLocation()).failure, LocationFailure.deniedForever);
    expect(p.requests, 0);
  });

  test('خدمة الموقع مغلقة', () async {
    p.serviceOn = false;
    expect((await s.getCurrentLocation()).failure, LocationFailure.serviceDisabled);
  });

  test('انتهاء المهلة وخطأ عام', () async {
    p.current = LocationPermission.whileInUse;
    p.positionError = TimeoutException('t');
    expect((await s.getCurrentLocation()).failure, LocationFailure.timeout);
    p.positionError = StateError('x');
    expect((await s.getCurrentLocation()).failure, LocationFailure.error);
  });
}
