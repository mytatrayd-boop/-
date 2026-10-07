import 'dart:io';

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/local_date.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/features/about/origin_screen.dart';
import 'package:durur/src/features/heritage/heritage_screen.dart';
import 'package:durur/src/features/home/home_cards.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/item_detail/detail_data.dart';
import 'package:durur/src/features/item_detail/item_detail_page.dart';
import 'package:durur/src/features/item_detail/item_detail_sheet.dart';
import 'package:durur/src/features/item_detail/item_detail_view.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/features/settings/sources_screen.dart';
import 'package:durur/src/formatting/date_labels.dart';
import 'package:durur/src/formatting/digits.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/app_harness.dart';

/// الميزة 7: صفحة النجم أو الموسم (والدَّرّ)، و«أصل التقويم»، والمصادر.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final now = DateTime(2026, 10, 2, 9, 30);
  final today = DateTime(2026, 10, 2);

  void phone(WidgetTester tester, {double width = 411, double height = 900}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  const openKey = Key('openSheet');

  /// زر يفتح الورقة السفلية لطلب (كما تفعل الدائرة).
  Future<ProviderContainer> openSheet(
    WidgetTester tester,
    DetailRequest request, {
    String city = 'riyadh',
    double textScale = 1,
    List<Override> extra = const [],
  }) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: openKey,
            onPressed: () => showItemDetailSheet(context, request),
            child: const Text('open'),
          ),
        ),
      ),
      prefs: await fakePrefs(savedCity(city)),
      tables: tables,
      textScale: textScale,
      extra: [fixedClock(now), ...extra],
    );
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byKey(openKey)));
  }

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byKey(ItemDetailSheet.sheetKey), matching: f);

  /// يمرّر محتوى الورقة/الصفحة حتى يظهر [f].
  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      150,
      scrollable: find
          .descendant(
            of: find.byKey(ItemDetailView.viewKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  String name(String id) => tables.items[id]!.name.ar;

  group('المعيار 2: محتوى الصفحة (الورقة من الدائرة)', () {
    testWidgets('سهيل في الرياض: الاسم، التواريخ في جدول نجد، الحالة، '
        'التعريف، المثل بخط Amiri، والمصدر لكل معلومة', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      final container = await openSheet(tester, (
        target: const ItemTarget('suhail'),
        from: today,
      ));
      expect(inSheet(find.text(l10n.detailTypeStar)), findsOneWidget);
      expect(inSheet(find.text(name('suhail'))), findsOneWidget);
      expect(
        tester.getSemantics(find.text(name('suhail'))),
        matchesSemantics(label: name('suhail'), isHeader: true),
      );
      // شريحة الموسم الكبير في بداية الفترة (الصفري في 24 أغسطس).
      expect(
        find.descendant(
          of: find.byKey(ItemDetailView.seasonChipKey),
          matching: find.text(name('safari')),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.detailRange(
            gregorianDateLabel(l10n, DateTime(2026, 8, 24)),
            gregorianDateLabel(l10n, DateTime(2027, 6, 6)),
            'نجد',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.detailDuration(287, '٢٨٧')), findsOneWidget);
      expect(find.text('٢٨٧ يوماً'), findsOneWidget);
      expect(find.text('جارٍ الآن — اليوم ٤٠ من ٢٨٧'), findsOneWidget);

      // المعيار 4 من الميزة 5: التاريخ المحسوب لمدينة المستخدم.
      final rising = container.read(currentHeliacalProvider(2026))!.suhail!;
      final days = daysBetween(
        DateTime(rising.year, rising.month, rising.day),
        today,
      );
      expect(days, greaterThan(0));
      expect(
        find.text(
          l10n.detailStarRisenAgo('m', days, 'الرياض', formatInteger(days)),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.detailAstroNote), findsOneWidget);

      final item = tables.items['suhail']!;
      // التعريف أولاً: زر البلاغ أسفل الصفحة (الميزة 9) يطيلها، فالتمرير
      // إلى المثل قد يُخرج التعريف من القائمة الكسولة.
      await scrollTo(tester, find.byKey(ItemDetailView.definitionKey));
      expect(find.text(item.definition.ar), findsOneWidget);
      await scrollTo(tester, find.byKey(ItemDetailView.proverbKey));
      final proverb = tester.widget<Text>(find.text(item.proverb.ar));
      expect(proverb.style!.fontFamily, DururFonts.proverb);
      expect(find.text(l10n.detailProverb), findsOneWidget);
      // علامة الاقتباس زخرفة مخفية عن القارئ.
      expect(find.bySemanticsLabel('”'), findsNothing);

      await scrollTo(tester, find.byKey(ItemDetailView.datesSourceKey));
      expect(
        find.text(l10n.detailContentSource(item.sources.first.title)),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.detailDatesSource(
            tables.regionTables['najd']!.stars
                .firstWhere((r) => r.itemId == 'suhail')
                .source
                .title,
          ),
        ),
        findsOneWidget,
      );
      // البيانات الحالية مسودة: «بانتظار الاعتماد» تحت كل مصدر.
      expect(find.text(l10n.approvalPending), findsNWidgets(2));
      handle.dispose();
    });

    testWidgets('شريحة الموسم تفتح صفحته داخل الورقة، والرجوع الداخلي', (
      tester,
    ) async {
      phone(tester);
      await openSheet(tester, (
        target: const ItemTarget('suhail'),
        from: today,
      ));
      expect(find.byKey(ItemDetailSheet.backKey), findsNothing);
      await tester.tap(find.byKey(ItemDetailView.seasonChipKey));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(l10n.detailTypeSeason)), findsOneWidget);
      expect(inSheet(find.text(name('safari'))), findsOneWidget);
      expect(find.byKey(ItemDetailView.seasonChipKey), findsNothing);
      expect(find.byTooltip(l10n.commonBack), findsOneWidget);
      await tester.tap(find.byKey(ItemDetailSheet.backKey));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(name('suhail'))), findsOneWidget);
      // رجوع النظام يعود داخل الورقة أولاً، ثم يغلقها.
      await tester.tap(find.byKey(ItemDetailView.seasonChipKey));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(inSheet(find.text(name('suhail'))), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailSheet.sheetKey), findsNothing);
    });

    testWidgets('«انتقل إلى بدايته» يغلق الورقة ويدير إلى أول يوم', (
      tester,
    ) async {
      phone(tester);
      final container = await openSheet(tester, (
        target: const ItemTarget('suhail'),
        from: today,
      ));
      await tester.tap(find.byKey(ItemDetailView.goToStartKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailSheet.sheetKey), findsNothing);
      expect(container.read(selectedDateProvider), DateTime(2026, 8, 24));
    });

    testWidgets('حالة «يبدأ بعد» و«انتهى قبل» نسبةً إلى اليوم', (tester) async {
      phone(tester);
      await openSheet(tester, (target: const ItemTarget('wasm'), from: today));
      expect(find.text(l10n.detailTypeWeatherSeason), findsOneWidget);
      expect(find.text('يبدأ بعد ١٤ يوماً'), findsOneWidget);
      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();

      await openSheet(tester, (
        target: const ItemTarget('wasm'),
        from: DateTime(2025, 10, 20),
      ));
      // 6 ديسمبر 2025 ← 2 أكتوبر 2026 = 300 يوم.
      expect(find.text('انتهى قبل ٣٠٠ يوماً'), findsOneWidget);
    });

    testWidgets('سهيل في سنة قادمة: «يطلع في الرياض يوم …»', (tester) async {
      phone(tester);
      final container = await openSheet(tester, (
        target: const ItemTarget('suhail'),
        from: DateTime(2027, 7, 1),
      ));
      final rising = container.read(currentHeliacalProvider(2027))!.suhail!;
      expect(
        find.text(
          l10n.detailStarRisesOn(
            'm',
            'الرياض',
            gregorianDateLabel(
              l10n,
              DateTime(rising.year, rising.month, rising.day),
            ),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('الثريا بالمؤنث (§13): «تطلع… يوم» و«طلعت… قبل»', (
      tester,
    ) async {
      phone(tester);
      var container = await openSheet(tester, (
        target: const ItemTarget('thurayya'),
        from: DateTime(2027, 5, 1),
      ));
      final r2027 = container.read(currentHeliacalProvider(2027))!.thurayya!;
      final date = gregorianDateLabel(
        l10n,
        DateTime(r2027.year, r2027.month, r2027.day),
      );
      expect(
        find.text(l10n.detailStarRisesOn('f', 'الرياض', date)),
        findsOneWidget,
      );
      expect(find.text('تطلع في الرياض يوم $date'), findsOneWidget);
      expect(find.textContaining('يطلع في'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      // اليوم 2 أكتوبر 2026: طلعت الثريا في يونيو.
      container = await openSheet(tester, (
        target: const ItemTarget('thurayya'),
        from: DateTime(2026, 6, 1),
      ));
      final r2026 = container.read(currentHeliacalProvider(2026))!.thurayya!;
      final days = daysBetween(
        DateTime(r2026.year, r2026.month, r2026.day),
        today,
      );
      final ago = find.text(
        l10n.detailStarRisenAgo('f', days, 'الرياض', formatInteger(days)),
      );
      expect(ago, findsOneWidget);
      expect(
        tester.widget<Text>(ago).data,
        startsWith('طلعت في الرياض قبل '),
      );
    });

    test('detailStarRisesToday وصيغ الجمع داخل الاختيار حسب الجنس', () {
      expect(l10n.detailStarRisesToday('m', 'الرياض'), 'يطلع في الرياض اليوم');
      expect(l10n.detailStarRisesToday('f', 'الرياض'), 'تطلع في الرياض اليوم');
      expect(l10n.detailStarRisenAgo('f', 1, 'الرياض', '١'),
          'طلعت في الرياض قبل يوم واحد');
      expect(l10n.detailStarRisenAgo('f', 2, 'الرياض', '٢'),
          'طلعت في الرياض قبل يومين');
      expect(l10n.detailStarRisenAgo('f', 3, 'الرياض', '٣'),
          'طلعت في الرياض قبل ٣ أيام');
      expect(l10n.detailStarRisenAgo('f', 12, 'الرياض', '١٢'),
          'طلعت في الرياض قبل ١٢ يوماً');
      expect(l10n.detailStarRisenAgo('m', 1, 'الرياض', '١'),
          'طلع في الرياض قبل يوم واحد');
      expect(l10n.detailStarRisenAgo('m', 2, 'الرياض', '٢'),
          'طلع في الرياض قبل يومين');
      expect(l10n.detailStarRisenAgo('m', 103, 'الرياض', '١٠٣'),
          'طلع في الرياض قبل ١٠٣ أيام');
      expect(l10n.detailStarRisenAgo('m', 12, 'الرياض', '١٢'),
          'طلع في الرياض قبل ١٢ يوماً');
      expect(l10n.notifStarTitle('m', 'سهيل', 'الرياض'),
          'طلع سهيل اليوم في الرياض');
      expect(l10n.notifStarBody('m'), 'أول ظهوره قبل الفجر. اضغط لتعرف عنه.');
    });

    testWidgets('تعذّر الحساب الفلكي: «تاريخ تقريبي من جدول المنطقة»', (
      tester,
    ) async {
      phone(tester);
      await openSheet(
        tester,
        (target: const ItemTarget('thurayya'), from: today),
        extra: [currentHeliacalProvider.overrideWith((ref, year) => null)],
      );
      expect(find.text(l10n.detailAstroFallback), findsOneWidget);
      expect(find.text(l10n.detailAstroNote), findsNothing);
    });

    testWidgets('نجم غير سهيل والثريا: بلا سطر فلكي', (tester) async {
      phone(tester);
      await openSheet(tester, (
        target: const ItemTarget('dabaran'),
        from: today,
      ));
      expect(find.byKey(ItemDetailView.astroKey), findsNothing);
    });
  });

  group('D26: صفحة الدَّرّ من سجله', () {
    testWidgets('مسقط: دَرّ الإمارات وعُمان، شريحة المئة، بلا مثل، ومصدر', (
      tester,
    ) async {
      phone(tester);
      final day = CalendarEngine.fromTables(tables, 'uae_oman').resolve(today);
      await openSheet(tester, detailRequestFor(DialRing.durur, day));
      expect(inSheet(find.text(l10n.detailTypeDar)), findsOneWidget);
      expect(inSheet(find.text(day.dar!.name.ar)), findsOneWidget);
      expect(find.textContaining('في جدول الإمارات وعُمان'), findsOneWidget);
      expect(find.byKey(ItemDetailView.proverbKey), findsNothing);
      expect(find.byKey(ItemDetailView.definitionKey), findsNothing);
      final hundred = name(day.dar!.record.seasonId);
      expect(find.text(l10n.detailDarHundred(hundred)), findsOneWidget);
      await scrollTo(tester, find.byKey(ItemDetailView.datesSourceKey));
      expect(
        find.text(l10n.commonSource(day.dar!.record.source.title)),
        findsOneWidget,
      );
      expect(find.byKey(ItemDetailView.contentSourceKey), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(ItemDetailView.seasonChipKey),
        -150,
        scrollable: find
            .descendant(
              of: find.byKey(ItemDetailView.viewKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // يكتمل ظهور الشريحة داخل الورقة قبل الضغط (لا حافتها فقط).
      await tester.ensureVisible(find.byKey(ItemDetailView.seasonChipKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ItemDetailView.seasonChipKey));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(hundred)), findsOneWidget);
      expect(inSheet(find.text(l10n.detailTypeSeason)), findsOneWidget);
    });
  });

  group('المعيار 1: من الشاشة الرئيسية (صفحة كاملة بمسار)', () {
    Future<ProviderContainer> openApp(
      WidgetTester tester, {
      String city = 'riyadh',
    }) async {
      await pumpDururApp(
        tester,
        prefs: await fakePrefs(savedCity(city)),
        tables: tables,
        extra: [fixedClock(now)],
      );
      return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    }

    // مسار الصفحة الظاهرة في الأعلى.
    String location(WidgetTester tester) {
      for (final f in [
        find.byKey(ItemDetailPage.pageKey),
        find.byKey(OriginScreen.screenKey),
        find.byType(HomeScreen),
      ]) {
        if (f.evaluate().isNotEmpty) {
          return GoRouterState.of(tester.element(f.last)).uri.toString();
        }
      }
      return '';
    }

    testWidgets('بطاقة الطالع ← /item/suhail، والرجوع للرئيسية', (tester) async {
      phone(tester);
      await openApp(tester);
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.starCard));
      // خارج خانات الطوالع (الخانة تفتح طالعها): العنوان الفرعي للبطاقة.
      await tester.tap(
        find.descendant(
          of: find.byKey(HomeCardKeys.starCard),
          matching: find.text(l10n.cardStarSubtitle),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
      expect(location(tester), '/item/suhail?from=2026-10-02');
      expect(find.text(name('suhail')), findsOneWidget);
      expect(find.byKey(ItemDetailView.astroKey), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.pageKey), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('شريط الدَّرّ ← /dar/uae_oman/<MM-DD>، وشريحة المئة '
        'تفتح صفحة الموسم، و«انتقل إلى بدايته» يعود للرئيسية', (tester) async {
      phone(tester);
      // الخليج (مسقط): في السعودية لا شريط دَرّ (R3.10).
      final container = await openApp(tester, city: 'muscat');
      final info = container.read(dayInfoProvider(today))!;
      final row = find.text(l10n.darTitle(info.dar!.name.ar));
      await scrollHomeTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        location(tester),
        '/dar/uae_oman/${info.dar!.record.start}?from=2026-10-02',
      );
      expect(find.textContaining('في جدول الإمارات وعُمان'), findsOneWidget);

      await tester.tap(find.byKey(ItemDetailView.seasonChipKey));
      await tester.pumpAndSettle();
      expect(location(tester), startsWith('/item/${info.dar!.record.seasonId}'));
      await tester.tap(find.byKey(ItemDetailView.goToStartKey).last);
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.pageKey), findsNothing);
      expect(location(tester), '/');
      final start = container.read(selectedDateProvider);
      expect(
        container.read(dayInfoProvider(start))!.majorSeason.itemId,
        isNotNull,
      );
      expect(start.isBefore(today) || start == today, isTrue);
    });

    testWidgets('شريحة المئة في شريط الدَّرّ تفتح صفحة موسمها', (tester) async {
      phone(tester);
      // الكويت: الشريحة بجانب اسم الدَّرّ في شريطه.
      await pumpDururApp(
        tester,
        prefs: await fakePrefs(savedCity('kuwait_city')),
        tables: tables,
        extra: [fixedClock(now)],
      );
      final info = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      ).read(dayInfoProvider(today))!;
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.darSeasonChip));
      await tester.tap(find.byKey(HomeCardKeys.darSeasonChip));
      await tester.pumpAndSettle();
      expect(location(tester), startsWith('/item/${info.dar!.record.seasonId}'));
    });

    testWidgets('العدّاد وصفوف «القادم» تفتح صفحاتها الكاملة', (tester) async {
      phone(tester);
      await openApp(tester, city: 'muscat');
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.countdown));
      await tester.tap(find.byKey(HomeCardKeys.countdown));
      await tester.pumpAndSettle();
      expect(location(tester), '/item/wasm?from=2026-10-12');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await scrollHomeTo(tester, find.byKey(HomeCardKeys.upcomingRow(0)));
      await tester.tap(find.byKey(HomeCardKeys.upcomingRow(0)));
      await tester.pumpAndSettle();
      expect(location(tester), startsWith('/dar/uae_oman/'));
      expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
    });

    testWidgets('مسار لا يجد سجله ← الرئيسية بلا خطأ', (tester) async {
      phone(tester);
      await openApp(tester);
      for (final path in [
        '/item/nope',
        '/dar/uae_oman/13-40',
        '/dar/uae_oman/04-04',
        // نجد بلا درور (D50): رابط دَرّ قديم ← الرئيسية (SPEC 20.10).
        '/dar/najd/01-08',
      ]) {
        GoRouter.of(tester.element(find.byType(HomeScreen))).go(path);
        await tester.pumpAndSettle();
        expect(find.byKey(ItemDetailPage.pageKey), findsNothing, reason: path);
        expect(find.byType(HomeScreen), findsOneWidget, reason: path);
        expect(tester.takeException(), isNull, reason: path);
      }
      // ومسار صحيح من التنبيه بلا تاريخ: التاريخ المعروض.
      GoRouter.of(tester.element(find.byType(HomeScreen))).go('/item/wasm');
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
      expect(find.text('يبدأ بعد ١٤ يوماً'), findsOneWidget);
    });

    testWidgets('«أصل التقويم»: الدرج الجانبي وتبويب «التراث» يفتحانها', (
      tester,
    ) async {
      phone(tester);
      await openApp(tester);
      await tester.tap(find.byKey(HomeScreen.menuKey));
      await tester.pumpAndSettle();
      expect(find.byKey(HomeScreen.drawerKey), findsOneWidget);
      await tester.tap(find.byKey(HomeScreen.drawerItem(3)));
      await tester.pumpAndSettle();
      expect(find.byKey(OriginScreen.screenKey), findsOneWidget);
      expect(location(tester), '/about/origin');
      for (final text in [
        l10n.originTitle,
        l10n.originTawaliTitle,
        l10n.originTawaliBody,
        l10n.originDururTitle,
        // لا عبارة مقارنة: لا درور في السعودية (D50).
        l10n.originDururBody,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await openTab(tester, AppTab.heritage);
      await tester.tap(find.byKey(HeritageScreen.originRowKey));
      await tester.pumpAndSettle();
      expect(find.byKey(OriginScreen.screenKey), findsOneWidget);
      expect(location(tester), '/about/origin');
    });
  });

  group('D27: صفحة المصادر', () {
    Future<List<Uri>> openSources(
      WidgetTester tester, {
      bool opens = true,
      double textScale = 1,
    }) async {
      final opened = <Uri>[];
      await pumpDururApp(
        tester,
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: tables,
        extra: [
          fixedClock(now),
          urlOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return opens;
          }),
        ],
      );
      await tester.tap(find.byTooltip(l10n.settingsTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsScreen.sourcesRowKey));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('مصادر بلا تكرار، و«رخص البيانات» مع رابطي GeoNames والرخصة', (
      tester,
    ) async {
      phone(tester, height: 2400);
      final opened = await openSources(tester);
      expect(find.byKey(SourcesScreen.screenKey), findsOneWidget);
      expect(find.text(l10n.sourcesTablesTitle), findsOneWidget);
      final geo = tables.cities.first.source.title;
      expect(find.text(geo), findsOneWidget);
      expect(find.text(tables.hijri!.source.title), findsOneWidget);
      expect(find.text(l10n.approvalPending), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(SourcesScreen.licenseLinkKey),
        200,
      );
      expect(find.text(l10n.sourcesLicensesTitle), findsOneWidget);
      expect(find.text(l10n.sourcesGeoNames), findsOneWidget);
      expect(find.text(l10n.sourcesHijri), findsOneWidget);
      await tester.tap(find.byKey(SourcesScreen.geoNamesLinkKey));
      await tester.tap(find.byKey(SourcesScreen.licenseLinkKey));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse('https://www.geonames.org/'),
        Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
      ]);
      expect(find.text(l10n.linkOpenError), findsNothing);
    });

    testWidgets('تعذّر فتح الرابط ← رسالة واضحة', (tester) async {
      phone(tester, height: 2400);
      await openSources(tester, opens: false);
      await tester.scrollUntilVisible(
        find.byKey(SourcesScreen.geoNamesLinkKey),
        200,
      );
      await tester.tap(find.byKey(SourcesScreen.geoNamesLinkKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.linkOpenError), findsOneWidget);
    });
  });

  group('الوصولية: RTL، تكبير 200% على 320dp، أهداف اللمس', () {
    testWidgets('الورقة والصفحات بخط 200% بلا فيضان', (tester) async {
      phone(tester, width: 320, height: 640);
      await openSheet(tester, (
        target: const ItemTarget('suhail'),
        from: today,
      ), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byKey(ItemDetailView.viewKey))),
        TextDirection.rtl,
      );
      await scrollTo(tester, find.byKey(ItemDetailView.datesSourceKey));
      expect(tester.takeException(), isNull);
      // أهداف اللمس 48dp.
      for (final key in [
        ItemDetailView.goToStartKey,
        ItemDetailView.seasonChipKey,
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(key),
          -150,
          scrollable: find
              .descendant(
                of: find.byKey(ItemDetailView.viewKey),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(48),
          reason: '$key',
        );
      }

      for (final screen in [const OriginScreen(), const SourcesScreen()]) {
        await pumpScreen(
          tester,
          screen,
          prefs: await fakePrefs(savedCity('riyadh')),
          tables: tables,
          textScale: 2,
          // عدد الاستبدالات نفسه في كل ProviderScope.
          extra: [fixedClock(now)],
        );
        expect(tester.takeException(), isNull, reason: '$screen');
      }
    });

    testWidgets('الورقة تُسحب لأعلى لتصبح كاملة الشاشة', (tester) async {
      phone(tester);
      await openSheet(tester, (
        target: const ItemTarget('suhail'),
        from: today,
      ));
      final before = tester.getTopLeft(find.byKey(ItemDetailView.viewKey)).dy;
      expect(before, greaterThan(300));
      await tester.drag(find.text(l10n.detailTypeStar), const Offset(0, -600));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byKey(ItemDetailView.viewKey)).dy;
      expect(after, lessThan(before));
    });
  });

  test('ملف الخط Amiri ورخصته موجودان', () {
    for (final path in [
      'assets/fonts/Amiri-Regular.ttf',
    ]) {
      expect(File(path).lengthSync(), greaterThan(100000), reason: path);
    }
    expect(
      readAsset('assets/fonts/Amiri-OFL.txt'),
      contains('Open Font License'),
    );
  });
}
