import 'package:brewlens/backend/demo/demo_analysis_repository.dart';
import 'package:brewlens/domain/models/app_failure.dart';
import 'package:brewlens/domain/models/auth_session.dart';
import 'package:brewlens/domain/repositories/auth_repository.dart';
import 'package:brewlens/features/auth/login_screen.dart';
import 'package:brewlens/features/home/home_screen.dart';
import 'package:brewlens/features/paywall/paywall_screen.dart';
import 'package:brewlens/features/result/result_screen.dart';
import 'package:brewlens/services/image_capture_service.dart';
import 'package:brewlens/features/settings/settings_screen.dart';
import 'package:brewlens/features/share/share_card.dart';
import 'package:brewlens/features/share/share_card_renderer.dart';
import 'package:brewlens/app/app.dart';
import 'package:brewlens/app/env.dart';
import 'package:brewlens/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flow_widget_test.dart' as flow;

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav_settings')));
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
}

/// مصادقة تفشل بلا اتصال في المرة الأولى ثم تنجح.
class FlakyAuth implements AuthRepository {
  var calls = 0;
  AuthSession? _session;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> sessionChanges() => const Stream.empty();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    calls++;
    if (calls == 1) throw const AppFailure(FailureCode.offline);
    return _session = AuthSession(userId: 'u', email: email);
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) => signIn(email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'BrewLens',
      packageName: 'com.mytatrayd.brewlens',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  test('share card renders a 1080×1350 PNG without throwing', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    final photo = await decodeImage(flow.png);
    for (final dir in [TextDirection.rtl, TextDirection.ltr]) {
      final bytes = await renderShareCard(
        ShareCardData(
          photo: photo,
          logo: null,
          score: 7.5,
          scoreText: '7.5',
          scoreOutOf: '/10',
          title: 'تقييم المظهر',
          typeLabel: 'إسبريسو',
          appName: 'عدسة البُن',
          brand: 'BrewLens',
          textDirection: dir,
          rating: 4,
          shopName: 'مقهى',
          note: 'كريما متجانسة',
        ),
        view: binding.platformDispatcher.views.first,
      );
      final out = await decodeImage(bytes);
      expect(out.width, 1080);
      expect(out.height, 1350);
      out.dispose();
    }
    photo.dispose();
  });

  testWidgets('share button on the result shares the generated card only', (
    tester,
  ) async {
    await flow.pumpApp(tester);
    await flow.openCameraAndShoot(tester);
    await tester.tap(find.byKey(const Key('share_card')));
    // فك الصورة والترميز يعملان على المحرك بوقت حقيقي.
    for (var i = 0; i < 100 && flow.share.shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(flow.share.shared, hasLength(1));
    final image = await tester.runAsync(
      () => decodeImage(flow.share.shared.single),
    );
    expect(image!.width, 1080);
    expect(find.text('تعذّر إنشاء البطاقة، حاول مجدداً'), findsNothing);
  });

  testWidgets(
    'settings is the third tab; simulate subscriber makes the limit 20',
    (tester) async {
      await flow.pumpApp(tester);
      expect(find.text('متبقٍّ لك اليوم: 2 من 2'), findsOneWidget);
      await openSettings(tester);
      expect(find.byKey(const Key('fab_camera')), findsNothing);
      await tester.scrollUntilVisible(find.text('الإصدار 1.0.0 (1)'), 200);
      await tester.scrollUntilVisible(
        find.byKey(const Key('simulate_subscriber')),
        -200,
      );
      expect(find.text('مجاني'), findsOneWidget);
      await tester.tap(find.byKey(const Key('simulate_subscriber')));
      await tester.pumpAndSettle();
      expect(find.text('مشترك'), findsOneWidget);
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();
      expect(find.text('متبقٍّ لك اليوم: 20 من 20'), findsOneWidget);
    },
  );

  testWidgets(
    'language: switching to English applies immediately and is saved',
    (tester) async {
      await flow.pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lang_en')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(SettingsScreen))),
        TextDirection.ltr,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en');
    },
  );

  testWidgets('paywall from settings: plans, terms, demo purchase message', (
    tester,
  ) async {
    await flow.pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('settings_subscription')));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('اشترك في عدسة البُن'), findsOneWidget);
    expect(find.text('99.99 ر.س / سنة'), findsOneWidget);
    expect(find.text('14.99 ر.س / شهر'), findsOneWidget);
    expect(find.text('7 أيام مجاناً'), findsOneWidget);
    expect(find.text('وفّر 44%'), findsOneWidget);
    expect(find.text('ابدأ التجربة المجانية'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan_monthly')));
    await tester.pumpAndSettle();
    expect(find.text('اشترك الآن'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('subscribe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscribe')));
    await tester.pump();
    expect(find.text('الشراء غير متاح في نسخة العرض'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byKey(const Key('restore_purchases')));
    await tester.pump();
    expect(find.text('الشراء غير متاح في نسخة العرض'), findsOneWidget);
  });

  testWidgets(
    'delete account needs the confirm word, then wipes data and returns to login',
    (tester) async {
      await flow.pumpApp(tester, usedToday: 1);
      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_delete_account')),
        200,
      );
      await tester.tap(find.byKey(const Key('settings_delete_account')));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('delete_account_button'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('delete_confirm_field')),
        'حذ',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('delete_confirm_field')),
        'حذف',
      );
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('تم حذف حسابك'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'locale'});
      expect(prefs.getInt(DemoAnalysisRepository.countKey), isNull);
    },
  );

  testWidgets('login offline shows "try again" which retries', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'ar'});
    final prefs = await SharedPreferences.getInstance();
    final auth = FlakyAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig.demo()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          analysisRepositoryProvider.overrideWithValue(
            DemoAnalysisRepository(prefs),
          ),
        ],
        child: const BrewLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'a@b.co');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth_retry')));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect(find.byKey(const Key('auth_retry')), findsNothing);
    expect(find.byType(HomeScreen), findsNothing); // FlakyAuth لا يبث الجلسة.
  });

  testWidgets('Android lost photo is recovered and analyzed when the camera opens', (tester) async {
    await flow.pumpApp(tester);
    flow.capture.lost = flow.png;
    await tester.tap(find.byKey(const Key('fab_camera')));
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('camera denied: shutter re-enabled when the app resumes from settings', (tester) async {
    await flow.pumpApp(tester);
    flow.capture.error = const CaptureAccessDenied(CaptureSource.camera);
    await flow.openCameraAndShoot(tester);
    final shutter = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ShutterButton');
    bool enabled() => (tester.widget(shutter) as dynamic).onPressed != null;
    expect(enabled(), isFalse);
    flow.capture.error = null;
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
      AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    expect(enabled(), isTrue);
  });
}
