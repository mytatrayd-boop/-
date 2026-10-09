import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/settings.dart';
import 'package:mawid/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('الرئيسية تعرض أقرب موعد، والشهر والتخصيص يعملان', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(MawidApp(s, today: DateTime(2026, 10, 9)));
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
}
