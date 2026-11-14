import 'package:permission_handler/permission_handler.dart' as ph;

enum AppPermission { camera, location, microphone }

enum AppPermissionStatus {
  /// ممنوح بالكامل.
  granted,

  /// لم يُطلب بعد أو رُفض ويمكن السؤال ثانية.
  denied,

  /// رُفض دائماً أو مقيَّد: لا يمكن السؤال، الحل من إعدادات الجوال.
  permanentlyDenied,

  /// الموقع التقريبي فقط (المسار يحتاج الدقة الكاملة).
  approximateOnly,
}

/// واجهة مجردة للأذونات (D: كل ما هو أصلي خلف واجهة مع نسخة مزيّفة).
abstract class PermissionService {
  Future<AppPermissionStatus> check(AppPermission p);
  Future<AppPermissionStatus> request(AppPermission p);

  /// يفتح إعدادات التطبيق في النظام. يعيد false إن تعذّر.
  Future<bool> openSettings();
}

/// التنفيذ الحقيقي عبر permission_handler. لم يُجرَّب على جهاز.
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  ph.Permission _map(AppPermission p) => switch (p) {
    AppPermission.camera => ph.Permission.camera,
    AppPermission.location => ph.Permission.locationWhenInUse,
    AppPermission.microphone => ph.Permission.microphone,
  };

  // ملاحظة: لا يكشف هذا التنفيذ حالة "الموقع التقريبي فقط" بعد
  // (يحتاج geolocator أو استعلاماً أصلياً)؛ الواجهة تدعمها والنسخة المزيّفة تختبرها.
  AppPermissionStatus _from(ph.PermissionStatus s) => switch (s) {
    ph.PermissionStatus.granted => AppPermissionStatus.granted,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => AppPermissionStatus.permanentlyDenied,
    ph.PermissionStatus.limited => AppPermissionStatus.approximateOnly,
    _ => AppPermissionStatus.denied,
  };

  @override
  Future<AppPermissionStatus> check(AppPermission p) async =>
      _from(await _map(p).status);

  @override
  Future<AppPermissionStatus> request(AppPermission p) async =>
      _from(await _map(p).request());

  @override
  Future<bool> openSettings() => ph.openAppSettings();
}
