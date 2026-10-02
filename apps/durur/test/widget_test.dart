import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/app.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('التطبيق يفتح بالعربية ومن اليمين لليسار', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DururApp()));
    await tester.pumpAndSettle();

    expect(find.text('ديرة الدرور'), findsWidgets);
    final direction = Directionality.of(tester.element(find.byType(HomeScreen)));
    expect(direction, TextDirection.rtl);
    expect(find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
        findsOneWidget);
  });

  testWidgets('الشاشة تعرض التاريخين الهجري والميلادي بالعربية (الميزة 2)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: DururApp.arabic,
        supportedLocales: const [DururApp.arabic],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: HomeScreen(today: DateTime(2026, 10, 2, 9, 30)),
      ),
    );
    await tester.pumpAndSettle();

    final hijri = find.byKey(const Key('hijriDate'));
    final gregorian = find.byKey(const Key('gregorianDate'));
    expect(tester.widget<Text>(hijri).data, '٢١ ربيع الآخر ١٤٤٨هـ');
    expect(tester.widget<Text>(gregorian).data, '٢ أكتوبر ٢٠٢٦م');
    expect(Directionality.of(tester.element(hijri)), TextDirection.rtl);
    expect(Directionality.of(tester.element(gregorian)), TextDirection.rtl);
  });
}
