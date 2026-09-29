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
    expect(find.text('مسؤول الأسرة'), findsOneWidget);

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
}
