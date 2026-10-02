import 'dart:io';

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/app.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الجداول الحقيقية من assets/tables (تُقرأ خارج FakeAsync في main أو setUpAll).
Future<Tables> loadAssetTables() =>
    TablesLoader((path) => File(path).readAsString()).load();

/// SharedPreferences وهمية بقيم أولية (تحاكي ما حُفظ على الجهاز).
Future<SharedPreferences> fakePrefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// [tables] null ← لا يُستبدل مزوّد الجداول (ليستبدله الاختبار في [extra]).
List<Override> appOverrides(
  SharedPreferences prefs,
  Tables? tables, [
  List<Override> extra = const [],
]) =>
    [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (tables != null) tablesProvider.overrideWith((ref) async => tables),
      ...extra,
    ];

/// التطبيق كاملاً (مع الموجّه).
Future<void> pumpDururApp(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required Tables tables,
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs, tables, extra),
      child: const DururApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// شاشة واحدة داخل MaterialApp عربي.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required SharedPreferences prefs,
  required Tables? tables,
  List<Override> extra = const [],
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs, tables, extra),
      child: MaterialApp(
        locale: DururApp.arabic,
        supportedLocales: const [DururApp.arabic],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
