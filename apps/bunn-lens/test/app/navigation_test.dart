import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bunn_lens/app/router.dart';

import '../helpers.dart';

void main() {
  testWidgets('أربعة تبويبات بالترتيب: فحص، السجل، المفضلة، الإعدادات', (tester) async {
    await pumpApp(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);
    expect(bar.selectedIndex, 0);
    final labels = bar.destinations.map((d) => (d as NavigationDestination).label).toList();
    expect(labels, ['فحص', 'السجل', 'المفضلة', 'الإعدادات']);
  });

  testWidgets('الضغط على كل تبويب يفتح شاشته ويغيّر المسار', (tester) async {
    await pumpApp(tester);
    String loc() => GoRouter.of(tester.element(find.byType(NavigationBar)))
        .routeInformationProvider.value.uri.path;
    expect(loc(), AppRoutes.scan);

    final bar = find.byType(NavigationBar);
    for (final (label, path) in [
      ('السجل', AppRoutes.history),
      ('المفضلة', AppRoutes.favorites),
      ('الإعدادات', AppRoutes.settings),
      ('فحص', AppRoutes.scan),
    ]) {
      await tester.tap(find.descendant(of: bar, matching: find.text(label)));
      await tester.pumpAndSettle();
      expect(loc(), path);
      // عنوان الشاشة في الـ AppBar
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(label)), findsOneWidget);
    }
  });
}
