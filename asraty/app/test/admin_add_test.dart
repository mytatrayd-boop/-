import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/common.dart';
import 'package:asraty/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester, [int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _demoAdminPage(WidgetTester tester, String tile, {bool nav = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const AsratyApp()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('تجربة سريعة بأسرة جاهزة'));
  await _settle(tester);
  if (nav) {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tile)));
  } else {
    await tester.ensureVisible(find.text(tile));
    await tester.tap(find.text(tile));
  }
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

  testWidgets('adding a prize shows it to everyone right away', (tester) async {
    await _demoAdminPage(tester, 'الجوائز', nav: true);
    await tester.enterText(find.widgetWithText(TextField, 'الجائزة، مثل: رحلة إلى الحديقة'), 'نزهة البحر');
    await tester.ensureVisible(find.text('إضافة الجائزة'));
    await tester.tap(find.text('إضافة الجائزة'));
    await _settle(tester);
    expect(find.text('أُضيفت الجائزة ✓ وأُبلغ الجميع'), findsOneWidget);
    expect(find.text('نزهة البحر'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('tasks: pick a member to see their done and not-done tasks; save / cancel fit', (tester) async {
    await _demoAdminPage(tester, 'مهام أفراد الأسرة');
    expect(find.text('اختر العضو'), findsOneWidget);
    // Aseel first: today's two tasks are done, the monthly one is not, nor today's prayer.
    Finder listed(String title) => find.descendant(of: find.byType(RowCard), matching: find.text(title));
    expect(listed('ترتيب السرير'), findsOneWidget);
    expect(listed('قراءة صفحة قرآن'), findsNothing, reason: "Lama's task is not listed under Aseel");
    await tester.ensureVisible(find.text('لمى').last);
    await tester.tap(find.text('لمى').last);
    await _settle(tester);
    expect(listed('قراءة صفحة قرآن'), findsOneWidget);
    expect(listed('ترتيب السرير'), findsNothing);
    await tester.ensureVisible(find.byTooltip('تعديل').first);
    await tester.tap(find.byTooltip('تعديل').first);
    await _settle(tester);
    for (final label in ['حفظ', 'إلغاء']) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.didExceedMaxLines, isFalse, reason: '$label fits on one line');
    }
    await tester.tap(find.text('حذف'));
    await _settle(tester);
    expect(find.text('حذف هذه المهمة؟\n«قراءة صفحة قرآن»'), findsOneWidget);
  });
}
