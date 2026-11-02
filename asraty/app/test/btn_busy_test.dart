import 'package:asraty/ui/common.dart';
import 'package:asraty/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a button shows the spinner when its screen is waiting (e.g. Enter on the keyboard), and ignores taps', (tester) async {
    var taps = 0;
    Widget app(bool busy) => MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: Btn('دخول', busy: busy, onPressed: () => taps++)),
        );
    await tester.pumpWidget(app(false));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('دخول'), findsOneWidget);
    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('دخول'), findsNothing);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0, reason: 'no repeat taps while waiting');
  });
}
