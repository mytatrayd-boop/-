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

  testWidgets('الشاشة تعرض التاريخ الهجري بأم القرى', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: DururApp.arabic,
        supportedLocales: const [DururApp.arabic],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: HomeScreen(today: DateTime(2026, 2, 18)),
      ),
    );
    await tester.pumpAndSettle();

    final hijri = tester.widget<Text>(find.byKey(const Key('hijriDate')));
    expect(hijri.data, contains('رمضان'));
    expect(hijri.data, endsWith('هـ'));
  });
}
