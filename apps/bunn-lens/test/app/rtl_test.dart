import 'package:bunn_lens/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('العربية: الاتجاه RTL والعنوان من ARB', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.byType(NavigationBar));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(AppLocalizations.of(ctx).localeName, 'ar');
    expect(find.text('فحص'), findsWidgets);
  });

  testWidgets('الإنجليزية: الاتجاه LTR', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    final ctx = tester.element(find.byType(NavigationBar));
    expect(Directionality.of(ctx), TextDirection.ltr);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('في RTL أول تبويب (فحص) في أقصى اليمين وآخر تبويب (الإعدادات) يساره', (tester) async {
    await pumpApp(tester);
    final scan = tester.getCenter(find.descendant(of: find.byType(NavigationBar), matching: find.text('فحص')));
    final settings = tester.getCenter(find.descendant(of: find.byType(NavigationBar), matching: find.text('الإعدادات')));
    expect(scan.dx, greaterThan(settings.dx));
  });

  test('اللغات المدعومة عربي وإنجليزي', () {
    final ar = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(ar, {'ar', 'en'});
  });
}
