import 'package:asraty/backend/backend.dart';
import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openDemoSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const AsratyApp()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('تجربة سريعة بأسرة جاهزة'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byIcon(Icons.settings_outlined));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('privacy policy is one tappable line, without the long URL', (tester) async {
    await _openDemoSettings(tester);
    const url = String.fromEnvironment('PRIVACY_URL');
    if (url.isEmpty) return; // run with --dart-define=PRIVACY_URL=... to cover this
    expect(find.text('🔒 سياسة الخصوصية'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    await tester.tap(find.text('🔒 سياسة الخصوصية'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });
  realAccountTests();
  testWidgets('sign-out returns to the full onboarding screen', (tester) async {
    await _openDemoSettings(tester);
    expect(find.text('الإعدادات'), findsWidgets);
    await tester.tap(find.text('خروج').last); // the settings button (the header one asks first)
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('أهلاً بك في أسرتي'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('تجربة سريعة بأسرة جاهزة'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

/// Signed-in "real" account whose sign-out takes a moment, like FirebaseBackend
/// (unregisterToken request, then auth sign-out).
class _SlowBackend extends DemoBackend {
  @override
  bool get isDemo => false;
  @override
  Future<void> signOut() async {
    // FirebaseBackend: the people/family listeners fire first (session still set, no data)…
    emit(AppState(session: current.session));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // …then auth sign-out clears the session.
    await super.signOut();
  }

  @override
  Future<void> deleteFamily() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await signOut();
  }
}

void realAccountTests() {
  testWidgets('real account: sign-out from settings shows the onboarding form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), realBackendFactoryProvider.overrideWithValue(_SlowBackend.new)],
      child: const AsratyApp(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('لوحة المسؤول'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('خروج').last); // the settings button (the header one asks first)
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('أهلاً بك في أسرتي'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('real account: deleting the family ends on the onboarding form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), realBackendFactoryProvider.overrideWithValue(_SlowBackend.new)],
      child: const AsratyApp(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.text('حذف الأسرة كاملة'));
    await tester.tap(find.text('حذف الأسرة كاملة'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('حذف نهائي'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('أهلاً بك في أسرتي'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
