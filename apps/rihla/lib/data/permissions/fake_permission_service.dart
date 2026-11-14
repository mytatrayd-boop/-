import 'permission_service.dart';

/// نسخة مزيّفة للاختبار: تتحكم بالحالة الحالية ونتيجة الطلب لكل إذن.
class FakePermissionService implements PermissionService {
  FakePermissionService({
    Map<AppPermission, AppPermissionStatus>? initial,
    Map<AppPermission, AppPermissionStatus>? onRequest,
  }) : current = {
         for (final p in AppPermission.values)
           p: initial?[p] ?? AppPermissionStatus.denied,
       },
       results = {...?onRequest};

  /// الحالة التي يعيدها check.
  final Map<AppPermission, AppPermissionStatus> current;

  /// نتيجة request لكل إذن (الافتراضي: ممنوح).
  final Map<AppPermission, AppPermissionStatus> results;

  final List<AppPermission> requested = [];
  int openSettingsCalls = 0;

  @override
  Future<AppPermissionStatus> check(AppPermission p) async => current[p]!;

  @override
  Future<AppPermissionStatus> request(AppPermission p) async {
    requested.add(p);
    final r = results[p] ?? AppPermissionStatus.granted;
    current[p] = r;
    return r;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}
