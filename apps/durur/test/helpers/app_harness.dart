import 'dart:io';

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/app.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/features/shell/app_shell.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_notification_scheduler.dart';

/// الجداول الحقيقية من assets/tables (تُقرأ خارج FakeAsync في main أو setUpAll).
Future<Tables> loadAssetTables() =>
    TablesLoader((path) => File(path).readAsString()).load();

/// SharedPreferences وهمية بقيم أولية (تحاكي ما حُفظ على الجهاز).
Future<SharedPreferences> fakePrefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// إعدادات محفوظة لمستخدم أنهى الإعداد الأولي واختار [cityId].
Map<String, Object> savedCity(String cityId) => {
  SettingsRepository.cityIdKey: cityId,
  SettingsRepository.onboardingDoneKey: true,
};

/// [tables] null ← لا يُستبدل مزوّد الجداول (ليستبدله الاختبار في [extra]).
/// المُجدوِل وهمي افتراضياً (لا بلجن في الاختبارات)؛ يُستبدل في [extra].
List<Override> appOverrides(
  SharedPreferences prefs,
  Tables? tables, [
  List<Override> extra = const [],
]) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  if (tables != null) tablesProvider.overrideWith((ref) async => tables),
  if (!extra.any(_isSchedulerOverride))
    notificationSchedulerProvider.overrideWithValue(
      FakeNotificationScheduler(),
    ),
  ...extra,
];

/// مُجدوِل وهمي مسمّى ليُستبدل به المُجدوِل في [appOverrides].
Override fakeScheduler(FakeNotificationScheduler scheduler) =>
    _SchedulerOverride(scheduler).override;

bool _isSchedulerOverride(Override o) => _schedulerOverrides[o] ?? false;
final _schedulerOverrides = Expando<bool>();

class _SchedulerOverride {
  _SchedulerOverride(FakeNotificationScheduler scheduler)
    : override = notificationSchedulerProvider.overrideWithValue(scheduler) {
    _schedulerOverrides[override] = true;
  }

  final Override override;
}

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

/// ساعة ثابتة للجهاز (اليوم المعروض في الرئيسية).
Override fixedClock(DateTime now) => clockProvider.overrideWithValue(() => now);

/// يمرّر قائمة الرئيسية حتى [finder] (السحب على الدائرة يدوّرها لا يمرّر).
Future<void> scrollHomeTo(WidgetTester tester, Finder finder) async {
  final list = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(list).position;
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    position.jumpTo(
      (position.pixels + 200).clamp(0, position.maxScrollExtent).toDouble(),
    );
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// نص أصل من القرص (لاختبار زمن التحميل).
String readAsset(String path) => File(path).readAsStringSync();

/// سطر التاريخين بصيغتيه: سطر واحد بفاصل «—»، أو سطران بلا فاصل إن لم
/// يتسع (خط الاختبار Ahem أعرض من الخط الحقيقي فينكسر غالباً).
Finder findDatesLine(String single) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data == single || w.data == single.replaceFirst(' — ', '\n')),
  description: 'سطر التاريخين "$single"',
);

/// تبويبات الشريط السفلي (DESIGN R2.9) بترتيبها من اليمين.
enum AppTab { wheel, symbols, heritage, settings }

/// يضغط تبويباً في شريط التبويب.
Future<void> openTab(WidgetTester tester, AppTab tab) async {
  await tester.tap(find.byKey(AppShell.tabKey(tab.index)));
  await tester.pumpAndSettle();
}
