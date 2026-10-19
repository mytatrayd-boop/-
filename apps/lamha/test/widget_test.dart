import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app/app_helpers.dart';

void main() {
  testWidgets('التطبيق من اليمين لليسار', (tester) async {
    await pumpApp(tester);
    final dir = Directionality.of(tester.element(find.byType(Scaffold)));
    expect(dir, TextDirection.rtl);
  });
}
