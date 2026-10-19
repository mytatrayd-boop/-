import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/main.dart';

void main() {
  testWidgets('الشاشة الفارغة من اليمين لليسار', (tester) async {
    await tester.pumpWidget(const LamhaApp());
    final dir = Directionality.of(tester.element(find.byType(Scaffold)));
    expect(dir, TextDirection.rtl);
  });
}
