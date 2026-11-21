import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/settings.dart';
import 'package:mawid/features/sources_page.dart';
import 'package:mawid/main.dart';
import 'package:mawid/model/programs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('one entry per official website, covering every program', () {
    final g = groupedSources();
    expect(g.map((e) => e.$3).toSet(), programs.map((p) => p.sourceUrl).toSet());
    expect(g.any((e) => e.$1 == 'الضمان الاجتماعي والتأهيل الشامل' && e.$3 == 'https://www.hrsd.gov.sa'), isTrue);
  });

  testWidgets('«المصادر الرسمية» تُفتح من التخصيص وفيها رابط كل جهة', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(MawidApp(s, today: DateTime(2026, 10, 9)));
    await t.tap(find.text('تخصيص'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('المصادر الرسمية'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('المصادر الرسمية'));
    await t.pumpAndSettle();
    expect(find.byType(SourcesPage), findsOneWidget);
    for (final host in ['www.ca.gov.sa', 'www.hrsd.gov.sa', 'www.gosi.gov.sa', 'sakani.sa', 'www.mof.gov.sa']) {
      await t.scrollUntilVisible(find.text(host).first, 200, scrollable: find.byType(Scrollable).last);
      expect(find.text(host), findsWidgets, reason: host);
    }
  });
}
