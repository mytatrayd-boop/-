import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:rihla/core/router/app_router.dart';
import 'package:rihla/data/permissions/permission_service.dart';
import 'package:rihla/features/onboarding_permissions/permissions_controller.dart';

PermissionsState st(Map<AppPermission, AppPermissionStatus> m) =>
    PermissionsState(statuses: m);

PermissionHandlerService svc({
  ph.PermissionStatus status = ph.PermissionStatus.granted,
  geo.LocationAccuracyStatus? acc = geo.LocationAccuracyStatus.precise,
  bool accThrows = false,
}) => PermissionHandlerService(
  readStatus: (_) async => status,
  requestPermission: (_) async => status,
  readLocationAccuracy: () async {
    if (accThrows) throw Exception('no plugin');
    return acc!;
  },
);

void main() {
  group('الإقلاع', () {
    const g = AppPermissionStatus.granted;
    test('نقص الكاميرا أو الموقع الدقيق يحوّل إلى /permissions', () {
      expect(
        initialLocationFor(
          st({AppPermission.camera: g, AppPermission.location: g}),
        ),
        AppRoutes.home,
      );
      expect(
        initialLocationFor(const PermissionsState()),
        AppRoutes.permissions,
      );
      expect(
        initialLocationFor(st({AppPermission.camera: g})),
        AppRoutes.permissions,
      );
      expect(
        initialLocationFor(
          st({
            AppPermission.camera: g,
            AppPermission.location: AppPermissionStatus.approximateOnly,
          }),
        ),
        AppRoutes.permissions,
      );
    });
    test('الميكروفون اختياري فلا يمنع الرئيسية', () {
      expect(
        initialLocationFor(
          st({
            AppPermission.camera: g,
            AppPermission.location: g,
            AppPermission.microphone: AppPermissionStatus.permanentlyDenied,
          }),
        ),
        AppRoutes.home,
      );
    });
  });

  group('PermissionHandlerService: الموقع التقريبي', () {
    test('ممنوح + reduced => approximateOnly (check وrequest)', () async {
      final s = svc(acc: geo.LocationAccuracyStatus.reduced);
      expect(
        await s.check(AppPermission.location),
        AppPermissionStatus.approximateOnly,
      );
      expect(
        await s.request(AppPermission.location),
        AppPermissionStatus.approximateOnly,
      );
    });
    test('ممنوح + precise => granted', () async {
      expect(
        await svc().check(AppPermission.location),
        AppPermissionStatus.granted,
      );
    });
    test('unknown أو فشل الاستعلام => granted', () async {
      expect(
        await svc(acc: geo.LocationAccuracyStatus.unknown)
            .check(AppPermission.location),
        AppPermissionStatus.granted,
      );
      expect(
        await svc(accThrows: true).check(AppPermission.location),
        AppPermissionStatus.granted,
      );
    });
    test('المرفوض لا يستعلم عن الدقة', () async {
      var called = false;
      final s = PermissionHandlerService(
        readStatus: (_) async => ph.PermissionStatus.denied,
        readLocationAccuracy: () async {
          called = true;
          return geo.LocationAccuracyStatus.reduced;
        },
      );
      expect(await s.check(AppPermission.location), AppPermissionStatus.denied);
      expect(called, isFalse);
    });
    test('الكاميرا والميكروفون لا يتأثران بالدقة', () async {
      final s = svc(acc: geo.LocationAccuracyStatus.reduced);
      expect(await s.check(AppPermission.camera), AppPermissionStatus.granted);
      expect(
        await s.check(AppPermission.microphone),
        AppPermissionStatus.granted,
      );
    });
    test('permanentlyDenied وrestricted', () async {
      expect(
        await svc(status: ph.PermissionStatus.permanentlyDenied)
            .check(AppPermission.camera),
        AppPermissionStatus.permanentlyDenied,
      );
      expect(
        await svc(status: ph.PermissionStatus.restricted)
            .check(AppPermission.camera),
        AppPermissionStatus.permanentlyDenied,
      );
    });
  });
}
