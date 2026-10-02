import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  testWidgets('التطبيق يفتح بالعربية ومن اليمين لليسار', (tester) async {
    await pumpDururApp(tester,
        prefs: await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'}),
        tables: tables);

    expect(tester.widget<Title>(find.byType(Title)).title, 'ديرة الدرور');
    final direction = Directionality.of(tester.element(find.byType(HomeScreen)));
    expect(direction, TextDirection.rtl);
    expect(find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
        findsOneWidget);
  });

  testWidgets('الشاشة تعرض التاريخين الهجري والميلادي بالعربية (الميزة 2)',
      (tester) async {
    await pumpScreen(
      tester,
      HomeScreen(today: DateTime(2026, 10, 2, 9, 30)),
      prefs: await fakePrefs(),
      tables: tables,
    );

    final hijri = find.byKey(const Key('hijriDate'));
    final gregorian = find.byKey(const Key('gregorianDate'));
    expect(tester.widget<Text>(hijri).data, '٢١ ربيع الآخر ١٤٤٨هـ');
    expect(tester.widget<Text>(gregorian).data, '٢ أكتوبر ٢٠٢٦م');
    expect(Directionality.of(tester.element(hijri)), TextDirection.rtl);
    expect(Directionality.of(tester.element(gregorian)), TextDirection.rtl);
  });
}
