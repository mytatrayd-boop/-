import 'package:adeeb_voice_lab/l10n/app_localizations_ar.dart';
import 'package:adeeb_voice_lab/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('without a bundled model the screen says so', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const VoiceLabApp());
    await tester.pumpAndSettle();
    expect(find.text(LabLocalizationsAr().labMissingModel), findsOneWidget);
  });
}
