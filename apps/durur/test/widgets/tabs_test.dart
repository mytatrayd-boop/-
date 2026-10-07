import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/weather_symbol.dart';
import 'package:durur/src/features/about/origin_screen.dart';
import 'package:durur/src/features/heritage/heritage_screen.dart';
import 'package:durur/src/features/home/dial/day_dial.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/item_detail/item_detail_sheet.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/features/settings/sources_screen.dart';
import 'package:durur/src/features/shell/app_shell.dart';
import 'package:durur/src/features/symbols/symbols_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/app_harness.dart';

/// شريط التبويب (DESIGN R2.9) ودليل الرموز (SPEC 16.8، 16.9).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final l10n = lookupAppLocalizations(const Locale('ar'));

  void phone(WidgetTester tester, {double width = 411, double height = 900}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openApp(WidgetTester tester) async => pumpDururApp(
    tester,
    prefs: await fakePrefs(savedCity('riyadh')),
    tables: tables,
    extra: [fixedClock(DateTime(2026, 10, 7, 9))],
  );

  test('SPEC 16.9: لكل رمز من الـ17 اسم وسطر شرح في ARB', () {
    for (final s in WeatherSymbol.values) {
      expect(l10n.weatherSymbolName(s.code), isNotEmpty, reason: s.code);
      expect(l10n.weatherSymbolDesc(s.code), isNotEmpty, reason: s.code);
      expect(l10n.weatherSymbolDesc(s.code), endsWith('.'), reason: s.code);
    }
    expect(
      WeatherSymbol.values.map((s) => l10n.weatherSymbolDesc(s.code)).toSet(),
      hasLength(17),
    );
  });

  testWidgets('4 تبويبات من اليمين: الدائرة، الرموز، التراث، الإعدادات', (
    tester,
  ) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    await openApp(tester);
    expect(find.byKey(AppShell.tabBarKey), findsOneWidget);
    // الكبسولة (R3.1-19): 56 ارتفاعاً، وعرضها min(العرض − 32، 360).
    expect(tester.getSize(find.byKey(AppShell.tabBarKey)).height, 56);
    expect(tester.getSize(find.byKey(AppShell.tabBarKey)).width, 360);
    final labels = ['الدائرة', 'الرموز', 'التراث', 'الإعدادات'];
    double? lastX;
    for (final (i, label) in labels.indexed) {
      final tab = find.byKey(AppShell.tabKey(i));
      expect(find.descendant(of: tab, matching: find.text(label)), findsOneWidget);
      final size = tester.getSize(tab);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(56));
      final x = tester.getCenter(tab).dx;
      if (lastX != null) expect(x, lessThan(lastX), reason: label);
      lastX = x;
    }
    expect(tester.getSemantics(find.byKey(AppShell.tabKey(0))).label, 'الدائرة');
    // لا «التوقعات» ولا «النصائح»، ولا زر إعدادات في الشريط العلوي.
    expect(find.text('التوقعات'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    handle.dispose();
  });

  testWidgets('الرموز: الـ17 بأيقونة واسم وشرح', (tester) async {
    phone(tester, height: 2400);
    await openApp(tester);
    await openTab(tester, AppTab.symbols);
    expect(find.byKey(SymbolsScreen.screenKey), findsOneWidget);
    expect(find.text(l10n.symbolsTitle), findsOneWidget);
    for (final s in WeatherSymbol.values) {
      final row = find.byKey(SymbolsScreen.rowKey(s));
      await tester.scrollUntilVisible(row, 200);
      expect(
        find.descendant(of: row, matching: find.text(l10n.weatherSymbolDesc(s.code))),
        findsOneWidget,
      );
    }
    // الرجوع للدائرة يحفظ حالتها.
    await openTab(tester, AppTab.wheel);
    expect(find.byKey(DayDial.dialKey), findsOneWidget);
  });

  testWidgets('التراث: أصل التقويم والمصادر صفحات كاملة فوق الشريط', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    await openTab(tester, AppTab.heritage);
    expect(find.byKey(HeritageScreen.screenKey), findsOneWidget);
    await tester.tap(find.byKey(HeritageScreen.sourcesRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(SourcesScreen.screenKey), findsOneWidget);
    // الشريط مخفي تحت الصفحة الكاملة.
    expect(find.byKey(AppShell.tabBarKey), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HeritageScreen.originRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(OriginScreen.screenKey), findsOneWidget);
    expect(find.byKey(AppShell.tabBarKey), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(AppShell.tabBarKey), findsOneWidget);
  });

  testWidgets('الإعدادات تبويب بلا زر رجوع، والورقة من الدائرة فوق الشريط', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    await openTab(tester, AppTab.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(
      GoRouter.of(tester.element(find.byType(SettingsScreen))).state.uri.path,
      '/settings',
    );
    await openTab(tester, AppTab.wheel);
    expect(find.byType(HomeScreen), findsOneWidget);
    // ضغطة على الطوالع (الرياض بلا درور: 0.69–0.51 من R، R3.10) ← الورقة
    // في موجّه الجذر (فوق شريط التبويب).
    final c = tester.getCenter(find.byKey(DayDial.dialKey));
    final r = tester.getSize(find.byKey(DayDial.dialKey)).width / 2;
    await tester.tapAt(c + Offset(0, -0.60 * r));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final sheet = find.byKey(ItemDetailSheet.sheetKey);
    expect(sheet, findsOneWidget);
    expect(
      Navigator.of(tester.element(sheet)),
      same(Navigator.of(tester.element(sheet), rootNavigator: true)),
    );
  });

  testWidgets('خط ≥ 1.5×: الشريط يُخفي التسميات ويبقي الأسماء لقارئ الشاشة', (
    tester,
  ) async {
    phone(tester, width: 320, height: 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final handle = tester.ensureSemantics();
    await openApp(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(AppShell.tabBarKey),
        matching: find.text('الرموز'),
      ),
      findsNothing,
    );
    expect(tester.getSemantics(find.byKey(AppShell.tabKey(1))).label, 'الرموز');
    handle.dispose();
  });
}
