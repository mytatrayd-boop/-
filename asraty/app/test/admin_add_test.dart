import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/common.dart';
import 'package:asraty/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester, [int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _demoAdminPage(WidgetTester tester, String tile) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const AsratyApp()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('تجربة سريعة بأسرة جاهزة'));
  await _settle(tester);
  await tester.ensureVisible(find.text(tile));
  await tester.tap(find.text(tile));
  await _settle(tester);
}

void main() {
  test('numbers typed on the Arabic keypad are understood', () {
    expect(parseDigits('١٠'), 10);
    expect(parseDigits(' 25 '), 25);
    expect(parseDigits('۳۰'), 30);
    expect(parseDigits('abc'), isNull);
  });

  testWidgets('adding a task shows it in the list right away', (tester) async {
    await _demoAdminPage(tester, 'مهام أفراد الأسرة');
    await tester.enterText(find.widgetWithText(TextField, 'اسم المهمة، مثل: ترتيب الغرفة'), 'سقي الزرع');
    await tester.enterText(find.widgetWithText(TextField, '10'), '١٥');
    await tester.ensureVisible(find.text('إضافة المهمة'));
    await tester.tap(find.text('إضافة المهمة'));
    await _settle(tester);
    expect(find.text('أُضيفت المهمة ✓'), findsOneWidget);
    expect(find.textContaining('سقي الزرع'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('adding a reward level shows it in the list right away', (tester) async {
    await _demoAdminPage(tester, 'الجوائز والمكافآت');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'نزهة البحر');
    await tester.enterText(fields.at(1), '٣٠');
    await tester.ensureVisible(find.text('إضافة المستوى'));
    await tester.tap(find.text('إضافة المستوى'));
    await _settle(tester);
    expect(find.text('أُضيف المستوى ✓'), findsOneWidget);
    expect(find.textContaining('نزهة البحر'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
  });
}
