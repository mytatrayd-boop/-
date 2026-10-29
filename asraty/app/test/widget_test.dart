import 'package:asraty/backend/access.dart';
import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding → quick demo → admin dashboard → approvals', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(400 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const AsratyApp()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('أهلاً بك في أسرتي'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.tap(find.text('تجربة سريعة بأسرة جاهزة'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('لوحة المسؤول'), findsOneWidget);
    expect(find.text('أسرة آل محمد'), findsOneWidget);

    await tester.tap(find.text('الموافقات'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('قراءة صفحة قرآن'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('موافقة'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('لا شيء بانتظارك. عندما ينجز أحد الأعضاء مهمة ستظهر هنا.'), findsOneWidget);
    // Let the toast timer finish.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('sign-in page: use an activation code', (tester) async {
    Access.debugDeviceId = 'test-device-1';
    addTearDown(() => Access.debugDeviceId = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(400 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const AsratyApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.textContaining('استخدم كود للتسجيل'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).last, 'nope');
    Future<void> activate() async {
      await tester.tap(find.text('تفعيل'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await activate();
    expect(find.textContaining('الكود غير صحيح'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'ASR-AB12-CD34');
    await activate();
    await tester.pump(const Duration(milliseconds: 300));
    expect(prefs.getString('activationCode'), 'ASR-AB12-CD34');
    expect(find.textContaining('التطبيق مفعّل على هذا الجهاز'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
