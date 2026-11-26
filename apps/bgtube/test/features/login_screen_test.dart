import 'dart:async';

import 'package:bgtube/app.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/ports/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes/fake_auth_service.dart';
import 'player_screen_test.dart' show FakeController;

Future<void> pumpApp(
  WidgetTester t,
  FakeAuthService auth, {
  MemRiskAckStore? ack,
  Locale locale = const Locale('ar'),
}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      playbackControllerProvider.overrideWithValue(FakeController()),
      authServiceProvider.overrideWithValue(auth),
      riskAckStoreProvider.overrideWithValue(ack ?? MemRiskAckStore()),
    ],
    child: BgtubeApp(locale: locale),
  ));
  await t.pumpAndSettle();
}

Future<void> openSettings(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.settings));
  await t.pumpAndSettle();
}

Future<void> openLogin(WidgetTester t) async {
  await openSettings(t);
  await t.tap(find.byKey(const Key('accountSignIn')));
  await t.pumpAndSettle();
}

Text statusText(WidgetTester t) => t.widget<Text>(find.byKey(const Key('accountStatus')));

void main() {
  testWidgets('login screen (Arabic RTL) shows explanation, Google button, not-now and password note',
      (t) async {
    await pumpApp(t, FakeAuthService());
    await openLogin(t);
    expect(find.text('سجّل الدخول لعرض قوائمك واشتراكاتك وإعجاباتك'), findsOneWidget);
    expect(find.text('المتابعة بحساب جوجل'), findsOneWidget);
    expect(find.text('ليس الآن'), findsOneWidget);
    expect(find.text('التطبيق لا يرى كلمة مرورك'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold).last)), TextDirection.rtl);
    expect(t.getSize(find.byKey(const Key('loginContinue'))).height, greaterThanOrEqualTo(48));
    expect(t.getSize(find.byKey(const Key('loginNotNow'))).height, greaterThanOrEqualTo(48));
  });

  testWidgets('first sign-in asks for the D10 risk acknowledgement; cancel does not sign in',
      (t) async {
    final auth = FakeAuthService();
    final ack = MemRiskAckStore();
    await pumpApp(t, auth, ack: ack);
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('riskDialog')), findsOneWidget);
    expect(find.textContaining('تخالف شروط يوتيوب'), findsOneWidget);
    expect(find.textContaining('غير موثّق'), findsOneWidget);
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(auth.signInCalls, 0);
    expect(ack.value, isFalse);
    expect(find.text('المتابعة بحساب جوجل'), findsOneWidget);
  });

  testWidgets('accept risk -> signs in, returns to settings showing the account connected',
      (t) async {
    final auth = FakeAuthService();
    final ack = MemRiskAckStore();
    await pumpApp(t, auth, ack: ack);
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    await t.tap(find.text('أقرّ وأتابع'));
    await t.pumpAndSettle();
    expect(auth.signInCalls, 1);
    expect(ack.value, isTrue);
    expect(find.byKey(const Key('loginContinue')), findsNothing); // عاد للإعدادات
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(statusText(t).data, 'متصل بحساب جوجل');
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('already acknowledged: no risk dialog', (t) async {
    final auth = FakeAuthService();
    await pumpApp(t, auth, ack: MemRiskAckStore(true));
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('riskDialog')), findsNothing);
    expect(auth.signInCalls, 1);
  });

  testWidgets('user cancels Google screen: stays on login without an error', (t) async {
    final auth = FakeAuthService()..nextSignIn = SignInOutcome.canceled;
    await pumpApp(t, auth, ack: MemRiskAckStore(true));
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.text('المتابعة بحساب جوجل'), findsOneWidget);
    expect(find.byKey(const Key('loginError')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('while signing in the button is disabled with a spinner', (t) async {
    final auth = FakeAuthService()..signInGate = Completer<void>();
    await pumpApp(t, auth, ack: MemRiskAckStore(true));
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('loginContinue'))).onPressed, isNull);
    auth.signInGate!.complete();
    await t.pumpAndSettle();
    expect(statusText(t).data, 'متصل بحساب جوجل');
  });

  testWidgets('sign-in failure shows the Arabic message and retry works', (t) async {
    final auth = FakeAuthService()..nextSignIn = const AppFailure(FailureKind.network);
    await pumpApp(t, auth, ack: MemRiskAckStore(true));
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.text('تعذّر الاتصال بالإنترنت. تحقق من الشبكة وأعد المحاولة.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    auth.nextSignIn = SignInOutcome.signedIn;
    await t.tap(find.text('إعادة المحاولة'));
    await t.pumpAndSettle();
    expect(auth.signInCalls, 2);
    expect(statusText(t).data, 'متصل بحساب جوجل');
  });

  testWidgets('generic failure uses the DESIGN sign-in error text', (t) async {
    final auth = FakeAuthService()..nextSignIn = const AppFailure(FailureKind.signInFailed);
    await pumpApp(t, auth, ack: MemRiskAckStore(true));
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.text('تعذّر تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى'), findsOneWidget);
  });

  testWidgets('sign-in not available in this build: button hidden with a clear message', (t) async {
    final auth = FakeAuthService()..nextSignIn = const AppFailure(FailureKind.signInUnavailable);
    await pumpApp(t, auth, ack: MemRiskAckStore(true));
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.text('الدخول غير مفعّل بعد في هذه النسخة'), findsOneWidget);
    expect(find.byKey(const Key('loginContinue')), findsNothing);
    expect(find.text('ليس الآن'), findsOneWidget);
  });

  testWidgets('not now returns to settings without signing in', (t) async {
    final auth = FakeAuthService();
    await pumpApp(t, auth);
    await openLogin(t);
    await t.tap(find.byKey(const Key('loginNotNow')));
    await t.pumpAndSettle();
    expect(auth.signInCalls, 0);
    expect(statusText(t).data, 'غير مسجّل الدخول');
  });

  testWidgets('sign out asks for confirmation; cancel keeps the session', (t) async {
    final auth = FakeAuthService(AuthStatus.signedIn);
    await pumpApp(t, auth);
    await openSettings(t);
    await t.tap(find.byKey(const Key('accountSignOut')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('signOutDialog')), findsOneWidget);
    expect(find.text('ستُمسح بيانات الدخول من هذا الجهاز.'), findsOneWidget);
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(auth.signOutCalls, 0);
    expect(statusText(t).data, 'متصل بحساب جوجل');
  });

  testWidgets('confirmed sign out calls the service and shows the sign-in button', (t) async {
    final auth = FakeAuthService(AuthStatus.signedIn);
    await pumpApp(t, auth);
    await openSettings(t);
    await t.tap(find.byKey(const Key('accountSignOut')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('signOutConfirm')));
    await t.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(statusText(t).data, 'غير مسجّل الدخول');
    expect(find.byKey(const Key('accountSignIn')), findsOneWidget);
  });

  testWidgets('sign out failure shows a message and keeps the session', (t) async {
    final auth = FakeAuthService(AuthStatus.signedIn)
      ..signOutError = const AppFailure(FailureKind.signOutFailed);
    await pumpApp(t, auth);
    await openSettings(t);
    await t.tap(find.byKey(const Key('accountSignOut')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('signOutConfirm')));
    await t.pumpAndSettle();
    expect(find.text('تعذّر تسجيل الخروج. حاول مرة أخرى'), findsOneWidget);
    expect(statusText(t).data, 'متصل بحساب جوجل');
  });

  testWidgets('expired session at startup shows the dialog; its button opens login', (t) async {
    final auth = FakeAuthService(AuthStatus.expired);
    await pumpApp(t, auth);
    expect(find.byKey(const Key('sessionExpiredDialog')), findsOneWidget);
    expect(find.text('انتهت جلستك، سجّل الدخول من جديد'), findsOneWidget);
    await t.tap(find.text('تسجيل الدخول'));
    await t.pumpAndSettle();
    expect(find.text('المتابعة بحساب جوجل'), findsOneWidget);
  });

  testWidgets('session expiring while running shows the dialog once; settings shows it too',
      (t) async {
    final auth = FakeAuthService(AuthStatus.signedIn);
    await pumpApp(t, auth);
    expect(find.byKey(const Key('sessionExpiredDialog')), findsNothing);
    auth.emit(AuthStatus.expired);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sessionExpiredDialog')), findsOneWidget);
    // إغلاق الحوار بالرجوع.
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sessionExpiredDialog')), findsNothing);
    await openSettings(t);
    expect(statusText(t).data, 'انتهت جلستك، سجّل الدخول من جديد');
    expect(find.byKey(const Key('accountSignIn')), findsOneWidget);
  });

  testWidgets('English strings and LTR', (t) async {
    await pumpApp(t, FakeAuthService(), locale: const Locale('en'));
    await openSettings(t);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
    await t.tap(find.byKey(const Key('accountSignIn')));
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold).last)), TextDirection.ltr);
    await t.tap(find.byKey(const Key('loginContinue')));
    await t.pumpAndSettle();
    expect(find.text('Before your first sign-in'), findsOneWidget);
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('no overflow at 1.3x font: login, risk dialog, settings account ($loc)', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(t, FakeAuthService(AuthStatus.expired), locale: Locale(loc));
      expect(t.takeException(), isNull);
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      await openSettings(t);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('accountSignIn')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('loginContinue')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('riskDialog')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
