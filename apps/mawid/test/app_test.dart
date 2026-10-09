import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/settings.dart';
import 'package:mawid/main.dart';
import 'package:mawid/model/holidays.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('الرئيسية تعرض أقرب موعد، والشهر والتخصيص يعملان', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(MawidApp(s, today: DateTime(2026, 10, 9)));
    expect(find.text('مواعيد الرواتب والإجازات'), findsOneWidget);
    expect(find.text('حساب المواطن'), findsWidgets);
    expect(find.text('بعد يومين'), findsOneWidget);
    expect(find.textContaining('أُخّر من السبت 10 أكتوبر'), findsOneWidget);

    await t.tap(find.text('الشهر'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('مواعيد الشهر'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('مواعيد الشهر'), findsOneWidget);

    await t.tap(find.text('تخصيص'));
    await t.pumpAndSettle();
    await s.setVisible('citizen', false);
    await t.tap(find.text('الرئيسية'));
    await t.pumpAndSettle();
    expect(find.text('بعد يومين'), findsNothing);
  });

  testWidgets('الميزانية تعرض رسم التوزيع وفاصل المواعيد، والتخصيص يعرض التنبيهات', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(MawidApp(s, today: DateTime(2026, 10, 9)));
    await t.tap(find.text('الميزانية'));
    await t.pumpAndSettle();
    expect(find.text('توزيع أكتوبر'), findsOneWidget);
    // مواعيد أكتوبر 2026: 1، 5، 11، 25، 26، 27 (الأقصى بين 5 و11 = 6 ثم 11 و25 = 14)
    expect(find.text('أطول فاصل بين موعدين: 14 يوماً'), findsOneWidget);

    await t.tap(find.text('تخصيص'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('التنبيهات'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('التنبيهات'), findsOneWidget);
    expect(find.text('ودجت الشاشة الرئيسية'), findsOneWidget);
  });

  testWidgets('لا نص إنجليزي تحت عنوان الشهر، واللون يتغير باختيار المستخدم', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(MawidApp(s, today: DateTime(2026, 10, 9)));
    await t.tap(find.text('الشهر'));
    await t.pumpAndSettle();
    final latin = RegExp(r'[A-Za-z]');
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').where((x) => x.contains(' – '));
    expect(texts, isNotEmpty);
    for (final x in texts) {
      expect(latin.hasMatch(x), isFalse, reason: x);
    }
    // أكتوبر 2026 بلا إجازات: لا مفتاح إجازات
    expect(find.text('رسمية'), findsNothing);

    await t.tap(find.text('تخصيص'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('لون أخضر'));
    await t.pumpAndSettle();
    expect(s.accentIndex, 1);
    expect(ink, accents[1].ink);
  });

  testWidgets('مفتاح الإجازات يعرض أنواع الشهر المعروض فقط', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    final extra = ValueNotifier<List<Holiday>>(parseExtra(File('remote/holidays.json').readAsStringSync()));
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(MawidApp(s, today: DateTime(2027, 7, 9), extra: extra));
    await t.tap(find.text('الشهر'));
    await t.pumpAndSettle();
    expect(find.text('إجازة صيفية'), findsWidgets); // القائمة والمفتاح
    expect(find.text('التعليم'), findsOneWidget);
    expect(find.text('رسمية'), findsNothing);
    expect(find.text('الإجازة الصيفية'), findsNothing);
  });

  testWidgets('كل إجازة تظهر مرة واحدة في قائمة الإجازات (بلا تكرار)', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    final extra = ValueNotifier<List<Holiday>>(parseExtra(File('remote/holidays.json').readAsStringSync()));
    await t.binding.setSurfaceSize(const Size(390, 1400));
    await t.pumpWidget(MawidApp(s, today: DateTime(2026, 11, 9), extra: extra));
    await t.tap(find.text('الشهر'));
    await t.pumpAndSettle();
    // مرة في المفتاح ومرة في القائمة فقط
    expect(find.text('إجازة منتصف الفصل'), findsNWidgets(2));
  });
}
