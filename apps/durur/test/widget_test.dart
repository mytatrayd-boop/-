import 'package:durur/src/features/home/dial/day_dial.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  testWidgets('التطبيق يفتح بالعربية ومن اليمين لليسار', (tester) async {
    await pumpDururApp(
      tester,
      prefs: await fakePrefs(savedCity('riyadh')),
      tables: tables,
    );

    expect(tester.widget<Title>(find.byType(Title)).title, 'دليل المواسم');
    final direction = Directionality.of(
      tester.element(find.byType(HomeScreen)),
    );
    expect(direction, TextDirection.rtl);
    // العبارة الثابتة في أسفل الرئيسية القابلة للتمرير (الميزة 6، معيار 8).
    await scrollHomeTo(
      tester,
      find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
    );
    expect(
      find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
      findsOneWidget,
    );
  });

  testWidgets('الشاشة تعرض التاريخين الهجري والميلادي بالعربية (الميزة 2)', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      prefs: await fakePrefs(savedCity('riyadh')),
      tables: tables,
      extra: [fixedClock(DateTime(2026, 10, 2, 9, 30))],
    );

    // R3.1-1: سطر الرأس فيه الهجري وحده (أم القرى)، والميلادي يُقرأ في
    // قيمة الدائرة مع الهجري (وتشير إليه حلقة الأشهر والعقرب).
    final line = find.byKey(HomeScreen.datesLineKey);
    expect(
      find.descendant(of: line, matching: find.text('٢١ ربيع الآخر ١٤٤٨هـ')),
      findsOneWidget,
    );
    final dial = tester.widget<DayDial>(find.byType(DayDial));
    expect(dial.semanticsValue, contains('٢ أكتوبر ٢٠٢٦'));
    expect(dial.semanticsValue, contains('٢١ ربيع الآخر ١٤٤٨'));
    expect(Directionality.of(tester.element(line)), TextDirection.rtl);
  });
}
