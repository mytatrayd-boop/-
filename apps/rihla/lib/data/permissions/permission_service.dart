import 'package:geolocator/geolocator.dart' as geo;
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

/// التنفيذ الحقيقي عبر permission_handler، ويكشف الموقع التقريبي عبر
/// geolocator (getLocationAccuracy). لم يُجرَّب على جهاز؛ المنطق مختبَر
/// بحقن دوال القراءة (انظر الوسائط).
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService({
    this.readStatus = _defaultStatus,
    this.requestPermission = _defaultRequest,
    this.readLocationAccuracy = _defaultAccuracy,
  });

  final Future<ph.PermissionStatus> Function(ph.Permission) readStatus;
  final Future<ph.PermissionStatus> Function(ph.Permission) requestPermission;
  final Future<geo.LocationAccuracyStatus> Function() readLocationAccuracy;

  static Future<ph.PermissionStatus> _defaultStatus(ph.Permission p) =>
      p.status;
  static Future<ph.PermissionStatus> _defaultRequest(ph.Permission p) =>
      p.request();
  static Future<geo.LocationAccuracyStatus> _defaultAccuracy() =>
      geo.Geolocator.getLocationAccuracy();

  ph.Permission _map(AppPermission p) => switch (p) {
    AppPermission.camera => ph.Permission.camera,
    AppPermission.location => ph.Permission.locationWhenInUse,
    AppPermission.microphone => ph.Permission.microphone,
  };

  AppPermissionStatus _from(ph.PermissionStatus s) => switch (s) {
    ph.PermissionStatus.granted => AppPermissionStatus.granted,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => AppPermissionStatus.permanentlyDenied,
    ph.PermissionStatus.limited => AppPermissionStatus.approximateOnly,
    _ => AppPermissionStatus.denied,
  };

  /// الموقع الممنوح قد يكون تقريبياً فقط (iOS 14+، أندرويد 12+ عند منح
  /// COARSE دون FINE). unknown أو فشل الاستعلام يُعاملان كدقيق (لا نمنع
  /// المستخدم بلا دليل).
  Future<AppPermissionStatus> _refineLocation(AppPermissionStatus s) async {
    if (s != AppPermissionStatus.granted) return s;
    try {
      final a = await readLocationAccuracy();
      return a == geo.LocationAccuracyStatus.reduced
          ? AppPermissionStatus.approximateOnly
          : s;
    } catch (_) {
      return s;
    }
  }

  @override
  Future<AppPermissionStatus> check(AppPermission p) async {
    final s = _from(await readStatus(_map(p)));
    return p == AppPermission.location ? _refineLocation(s) : s;
  }

  @override
  Future<AppPermissionStatus> request(AppPermission p) async {
    final s = _from(await requestPermission(_map(p)));
    return p == AppPermission.location ? _refineLocation(s) : s;
  }

  @override
  Future<bool> openSettings() => ph.openAppSettings();
}
