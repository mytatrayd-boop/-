import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/permissions/permission_service.dart';

/// الخدمة الفعلية؛ تُستبدل في الاختبارات بـFakePermissionService.
final permissionServiceProvider = Provider<PermissionService>(
  (_) => const PermissionHandlerService(),
);

/// ترتيب الخطوات (DESIGN 7.1).
const permissionSteps = [
  AppPermission.camera,
  AppPermission.location,
  AppPermission.microphone,
];

class PermissionsState {
  const PermissionsState({
    this.statuses = const {},
    this.asked = const {},
    this.step = 0,
    this.done = false,
  });

  final Map<AppPermission, AppPermissionStatus> statuses;

  /// الأذونات التي طُلبت فعلاً في هذه الجلسة (للتمييز بين "لم يُطلب" و"رُفض").
  final Set<AppPermission> asked;
  final int step;
  final bool done;

  AppPermission get currentPermission => permissionSteps[step];

  AppPermissionStatus statusOf(AppPermission p) =>
      statuses[p] ?? AppPermissionStatus.denied;

  /// الأساسيان: الكاميرا والموقع بدقة كاملة (SPEC F2).
  bool get canStartRecording =>
      statusOf(AppPermission.camera) == AppPermissionStatus.granted &&
      statusOf(AppPermission.location) == AppPermissionStatus.granted;

  bool get micAvailable =>
      statusOf(AppPermission.microphone) == AppPermissionStatus.granted;

  PermissionsState copyWith({
    Map<AppPermission, AppPermissionStatus>? statuses,
    Set<AppPermission>? asked,
    int? step,
    bool? done,
  }) => PermissionsState(
    statuses: statuses ?? this.statuses,
    asked: asked ?? this.asked,
    step: step ?? this.step,
    done: done ?? this.done,
  );
}

class PermissionsController extends Notifier<PermissionsState> {
  @override
  PermissionsState build() => const PermissionsState();

  PermissionService get _svc => ref.read(permissionServiceProvider);

  /// يعيد فحص الأذونات كلها (عند الفتح وعند العودة من الإعدادات).
  Future<void> refresh() async {
    final m = <AppPermission, AppPermissionStatus>{};
    for (final p in permissionSteps) {
      m[p] = await _svc.check(p);
    }
    state = state.copyWith(statuses: m);
  }

  /// زر "السماح": يطلب الإذن الحالي ثم يتقدم إن مُنح؛ وإلا تظهر حالة الرفض.
  Future<void> allow() async {
    final p = state.currentPermission;
    final r = await _svc.request(p);
    state = state.copyWith(
      statuses: {...state.statuses, p: r},
      asked: {...state.asked, p},
    );
    if (r == AppPermissionStatus.granted) _advance();
  }

  /// "ليس الآن" / "متابعة بلا صوت" للميكروفون فقط.
  void skipMicrophone() {
    if (state.currentPermission == AppPermission.microphone) _advance();
  }

  /// "إعادة المحاولة" بعد الرفض: يفحص ثم يطلب ثانية إن أمكن.
  Future<void> retry() async {
    final p = state.currentPermission;
    final now = await _svc.check(p);
    state = state.copyWith(statuses: {...state.statuses, p: now});
    if (now == AppPermissionStatus.granted) {
      _advance();
    } else if (now == AppPermissionStatus.denied) {
      await allow();
    }
  }

  Future<void> openSettings() => _svc.openSettings();

  /// بعد العودة من الإعدادات: إن صار الإذن الحالي ممنوحاً نتقدم.
  Future<void> refreshAndAdvance() async {
    await refresh();
    if (!state.done &&
        state.statusOf(state.currentPermission) ==
            AppPermissionStatus.granted &&
        state.asked.contains(state.currentPermission)) {
      _advance();
    }
  }

  void _advance() {
    if (state.step >= permissionSteps.length - 1) {
      state = state.copyWith(done: true);
    } else {
      state = state.copyWith(step: state.step + 1);
    }
  }
}

final permissionsProvider =
    NotifierProvider<PermissionsController, PermissionsState>(
      PermissionsController.new,
    );
