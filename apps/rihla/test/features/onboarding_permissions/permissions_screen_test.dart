import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rihla/core/router/app_router.dart';
import 'package:rihla/core/theme/app_theme.dart';
import 'package:rihla/data/permissions/fake_permission_service.dart';
import 'package:rihla/data/permissions/permission_service.dart';
import 'package:rihla/features/onboarding_permissions/permissions_controller.dart';
import 'package:rihla/features/onboarding_permissions/permissions_screen.dart';
import 'package:rihla/l10n/app_localizations.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';
import 'package:rihla/l10n/app_localizations_en.dart';

const _cam = AppPermission.camera;
const _loc = AppPermission.location;
const _mic = AppPermission.microphone;
const _granted = AppPermissionStatus.granted;
const _denied = AppPermissionStatus.denied;
const _perm = AppPermissionStatus.permanentlyDenied;

late ProviderContainer container;

Future<void> pumpScreen(
  WidgetTester t,
  FakePermissionService svc, {
  Locale locale = const Locale('ar'),
  Size size = const Size(800, 360),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.permissions,
    routes: [
      GoRoute(
        path: AppRoutes.permissions,
        builder: (_, _) => const PermissionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [permissionServiceProvider.overrideWithValue(svc)],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(
            theme: AppTheme.dark(),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tapKey(WidgetTester t, String k) async {
  await t.tap(find.byKey(Key(k)));
  await t.pumpAndSettle();
}

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  testWidgets('الشرح يظهر قبل أي طلب (لا طلب تلقائي)', (t) async {
    final svc = FakePermissionService();
    await pumpScreen(t, svc);
    expect(find.text(ar.permCameraReason), findsOneWidget);
    expect(find.text(ar.permPrivacy), findsOneWidget);
    expect(svc.requested, isEmpty);
    expect(
      Directionality.of(t.element(find.text(ar.permCameraReason))),
      TextDirection.rtl,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('كله ممنوح: ثلاث خطوات ثم الرئيسية، ويُسمح بالبدء', (t) async {
    final svc = FakePermissionService();
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permLocationReason), findsOneWidget);
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permMicReason), findsOneWidget);
    await tapKey(t, 'perm-allow');
    expect(svc.requested, [_cam, _loc, _mic]);
    expect(find.text('HOME'), findsOneWidget);
    expect(container.read(permissionsProvider).canStartRecording, isTrue);
  });

  testWidgets('رفض الكاميرا: رسالة وإعدادات وإعادة محاولة، ولا تقدّم', (
    t,
  ) async {
    final svc = FakePermissionService(onRequest: {_cam: _denied});
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permCameraDenied), findsOneWidget);
    expect(find.byKey(const Key('perm-retry')), findsOneWidget);
    expect(find.byKey(const Key('perm-settings')), findsOneWidget);
    expect(find.text(ar.permLocationReason), findsNothing);
    expect(container.read(permissionsProvider).canStartRecording, isFalse);

    // إعادة المحاولة تطلب ثانية؛ هذه المرة يمنح المستخدم.
    svc.results[_cam] = _granted;
    await tapKey(t, 'perm-retry');
    expect(svc.requested, [_cam, _cam]);
    expect(find.text(ar.permLocationReason), findsOneWidget);
  });

  testWidgets('رفض دائم للكاميرا: زر الإعدادات فقط، ويفتحها', (t) async {
    final svc = FakePermissionService(onRequest: {_cam: _perm});
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    expect(find.byKey(const Key('perm-retry')), findsNothing);
    expect(find.text(ar.permPermanentHint), findsOneWidget);
    await tapKey(t, 'perm-settings');
    expect(svc.openSettingsCalls, 1);
  });

  testWidgets('العودة من الإعدادات بعد المنح تتقدم تلقائياً', (t) async {
    final svc = FakePermissionService(onRequest: {_cam: _perm});
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    svc.current[_cam] = _granted; // المستخدم منحه من الإعدادات
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.text(ar.permLocationReason), findsOneWidget);
  });

  testWidgets('رفض الموقع (ممنوع الكاميرا): لا بدء', (t) async {
    final svc = FakePermissionService(onRequest: {_loc: _denied});
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permLocationDenied), findsOneWidget);
    final s = container.read(permissionsProvider);
    expect(s.statusOf(_cam), _granted);
    expect(s.canStartRecording, isFalse);
  });

  testWidgets('رفض دائم للموقع', (t) async {
    final svc = FakePermissionService(onRequest: {_loc: _perm});
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    await tapKey(t, 'perm-allow');
    expect(find.byKey(const Key('perm-retry')), findsNothing);
    expect(find.byKey(const Key('perm-settings')), findsOneWidget);
  });

  testWidgets('الموقع التقريبي فقط: شرح الدقة الكاملة وإعدادات فقط', (t) async {
    final svc = FakePermissionService(
      onRequest: {_loc: AppPermissionStatus.approximateOnly},
    );
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permLocationApproximate), findsOneWidget);
    expect(find.byKey(const Key('perm-settings')), findsOneWidget);
    expect(container.read(permissionsProvider).canStartRecording, isFalse);
  });

  testWidgets('رفض الميكروفون: شريحة ومتابعة بلا صوت، ويُسمح بالبدء', (
    t,
  ) async {
    final svc = FakePermissionService(onRequest: {_mic: _denied});
    await pumpScreen(t, svc);
    await tapKey(t, 'perm-allow');
    await tapKey(t, 'perm-allow');
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permAudioUnavailable), findsOneWidget);
    expect(find.text(ar.permMicDenied), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    await tapKey(t, 'perm-skip');
    expect(find.text('HOME'), findsOneWidget);
    final s = container.read(permissionsProvider);
    expect(s.canStartRecording, isTrue);
    expect(s.micAvailable, isFalse);
  });

  testWidgets('"ليس الآن" للميكروفون فقط', (t) async {
    final svc = FakePermissionService();
    await pumpScreen(t, svc);
    expect(find.byKey(const Key('perm-skip')), findsNothing);
    await tapKey(t, 'perm-allow');
    expect(find.byKey(const Key('perm-skip')), findsNothing);
    await tapKey(t, 'perm-allow');
    expect(find.text(ar.permNotNow), findsOneWidget);
    await tapKey(t, 'perm-skip');
    expect(svc.requested, [_cam, _loc]);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('رفض دائم للميكروفون: إعدادات مع متابعة', (t) async {
    final svc = FakePermissionService(onRequest: {_mic: _perm});
    await pumpScreen(t, svc);
    for (var i = 0; i < 3; i++) {
      await tapKey(t, 'perm-allow');
    }
    expect(find.byKey(const Key('perm-settings')), findsOneWidget);
    expect(find.byKey(const Key('perm-skip')), findsOneWidget);
  });

  testWidgets('إنجليزي LTR وبلا overflow بخط كبير', (t) async {
    final svc = FakePermissionService(onRequest: {_cam: _perm});
    await pumpScreen(
      t,
      svc,
      locale: const Locale('en'),
      size: const Size(640, 300),
    );
    expect(find.text(en.permCameraReason), findsOneWidget);
    expect(
      Directionality.of(t.element(find.text(en.permCameraReason))),
      TextDirection.ltr,
    );
    await tapKey(t, 'perm-allow');
    expect(find.text(en.permCameraDenied), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('الخدمة الحقيقية لا تُستدعى في الاختبارات ومنطق canStart', () {
    const s = PermissionsState();
    expect(s.canStartRecording, isFalse);
  });

  test('بيانات النظام: Manifest وInfo.plist فيهما الأذونات والنصوص', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final p in ['CAMERA', 'RECORD_AUDIO', 'ACCESS_FINE_LOCATION']) {
      expect(m, contains('android.permission.$p'));
    }
    expect(m, isNot(contains('BACKGROUND_LOCATION')));
    final i = File('ios/Runner/Info.plist').readAsStringSync();
    for (final k in [
      'NSCameraUsageDescription',
      'NSLocationWhenInUseUsageDescription',
      'NSMicrophoneUsageDescription',
    ]) {
      final m = RegExp('<key>$k</key>\\s*<string>([^<]+)</string>')
          .firstMatch(i);
      expect(m, isNotNull, reason: k);
      expect(m!.group(1), matches(RegExp(r'[؀-ۿ]')));
      expect(m.group(1), matches(RegExp(r'[A-Za-z]')));
    }
  });
}
