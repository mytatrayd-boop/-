import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bunn_lens/app/app.dart';
import 'package:bunn_lens/app/locale_provider.dart';

Future<void> pumpApp(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _FixedLocale(locale)),
      ],
      child: const BunnLensApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedLocale extends LocaleNotifier {
  _FixedLocale(this._locale);
  final Locale _locale;
  @override
  Locale build() => _locale;
}
