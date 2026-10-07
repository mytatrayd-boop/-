import 'dart:async';
import 'dart:math' as math;

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/domain/weather_symbol.dart';
import 'package:durur/src/features/common/draft_banner.dart';
import 'package:durur/src/features/home/astro_sheets.dart';
import 'package:durur/src/features/home/dial/day_dial.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/features/home/home_cards.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/home/symbol_bubble.dart';
import 'package:durur/src/features/item_detail/item_detail_sheet.dart';
import 'package:durur/src/features/report/report_sheet.dart';
import 'package:durur/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// الميزة 6 و16: الشاشة الرئيسية والدائرة (DESIGN R3.1، R3.2، R3.10، 7.4، 7.7).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  void phone(WidgetTester tester, {double width = 412, double height = 900}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openHome(
    WidgetTester tester, {
    String city = 'riyadh',
    DateTime? now,
    double textScale = 1,
    Tables? withTables,
  }) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      prefs: await fakePrefs(savedCity(city)),
      tables: withTables ?? tables,
      textScale: textScale,
      extra: [fixedClock(now ?? DateTime(2026, 10, 2, 9, 30))],
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

  DateTime selected(WidgetTester tester) =>
      containerOf(tester).read(selectedDateProvider);

  DialModel model(WidgetTester tester) =>
      tester.widget<DayDial>(find.byType(DayDial)).model;

  SemanticsData dialData(WidgetTester tester) =>
      tester.getSemantics(find.byKey(DayDial.dialKey)).getSemanticsData();

  void perform(WidgetTester tester, SemanticsAction action) {
    final node = tester.getSemantics(find.byKey(DayDial.dialKey));
    node.owner!.performAction(node.id, action);
  }

  List<String> customActions(WidgetTester tester) => [
    for (final id in dialData(tester).customSemanticsActionIds!)
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void performCustom(WidgetTester tester, String label) {
    final data = dialData(tester);
    final i = customActions(tester).indexOf(label);
    expect(i, isNonNegative, reason: label);
    final node = tester.getSemantics(find.byKey(DayDial.dialKey));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      data.customSemanticsActionIds![i],
    );
  }

  /// زاوية منتصف يوم بالدرجات مع عقارب الساعة من الأعلى (R3.1-3): 21
  /// ديسمبر عند 180°، والزمن عكس عقارب الساعة.
  double degOf(DateTime d) {
    final days = DateTime.utc(d.year + 1).difference(DateTime.utc(d.year)).inDays;
    final index = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(d.year))
        .inDays;
    final anchor = DateTime.utc(d.year, 12, 21)
        .difference(DateTime.utc(d.year))
        .inDays;
    return 180 - (index - anchor) * 360 / days;
  }

  /// نقطة على الدائرة: [fraction] من R، و[degrees] مع عقارب الساعة من الأعلى.
  /// منتصفات الحلقات في الخليج: A 0.94، الأشهر 0.82، الأيام 0.725، الدرور
  /// 0.59، الطوالع 0.455، البروج 0.38، المركز 0.2؛ وبلا درور: الطوالع 0.60،
  /// البروج 0.455، المركز 0.22.
  Offset dialPoint(WidgetTester tester, double fraction, double degrees) {
    final c = tester.getCenter(find.byKey(DayDial.dialKey));
    final r = tester.getSize(find.byKey(DayDial.dialKey)).width / 2;
    final rr = fraction * r;
    final a = degrees * math.pi / 180;
    return c + Offset(rr * math.sin(a), -rr * math.cos(a));
  }

  Future<void> tapDial(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    // الضغطة تنتظر مهلة الضغطتين المتتاليتين (التكبير).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester, Finder sheet) async {
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
  }

  group('R3: الشاشة بنظرة', () {
    testWidgets('الخليج (مسقط): الدائرة بسبع حلقات، والبطاقات الأربع بعمودين، '
        'وشريط الدَّرّ مع «الجو المعتاد حسب التراث»', (tester) async {
      phone(tester);
      await openHome(tester, city: 'muscat');
      expect(find.byKey(DayDial.dialKey), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byKey(DayDial.dialKey))),
        TextDirection.rtl,
      );
      expect(model(tester).hasDurur, isTrue);
      // القطر = العرض − 16 (R3.1-2).
      expect(tester.getSize(find.byType(DayDial)).width, 412 - 16);

      // الصف العلوي: العنوان، والمكان والتاريخ الهجري، والقائمة والجرس.
      expect(find.text('دليل المواسم'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(HomeScreen.placeKey),
          matching: find.text('مسقط'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(HomeScreen.datesLineKey),
          matching: find.text('٢١ ربيع الآخر ١٤٤٨هـ'),
        ),
        findsOneWidget,
      );
      // القائمة في البداية (يمين) والجرس في النهاية (يسار).
      expect(
        tester.getCenter(find.byKey(HomeScreen.menuKey)).dx,
        greaterThan(tester.getCenter(find.byKey(HomeScreen.bellKey)).dx),
      );

      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      final star = find.byKey(HomeCardKeys.starCard);
      for (final text in [
        'الطالع',
        'نجم الموسم الآن',
        'الموسم: ${tables.items[info.majorSeason.itemId]!.name.ar}',
      ]) {
        expect(
          find.descendant(of: star, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      // الشبكة: الصف 1 الزراعة (يمين) والطالع (يسار)، والصف 2 القادم والطقس.
      final agri = tester.getRect(find.byKey(HomeCardKeys.agriCard));
      final starBox = tester.getRect(star);
      final upcoming = tester.getRect(find.byKey(HomeCardKeys.upcomingCard));
      final live = tester.getRect(find.byKey(HomeCardKeys.liveWeatherCard));
      expect(agri.left, greaterThan(starBox.right));
      expect(agri.top, starBox.top);
      expect(upcoming.left, greaterThan(live.right));
      expect(upcoming.top, greaterThan(agri.bottom));
      expect(starBox.width, closeTo((412 - 44) / 2, 0.5));
      expect(
        find.descendant(
          of: find.byKey(HomeCardKeys.liveWeatherCard),
          matching: find.text('غير متاح بعد'),
        ),
        findsOneWidget,
      );

      // شريط الدَّرّ ثم صف الجو المعتاد داخله (R3.1-18).
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.darStrip));
      final dar = find.byKey(HomeCardKeys.darStrip);
      expect(
        find.descendant(of: dar, matching: find.text('دَرّ ${info.dar!.name.ar}')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dar, matching: find.text('اليوم ٣ من ١٠')),
        findsOneWidget,
      );
      final weather = find.descendant(
        of: dar,
        matching: find.byKey(HomeCardKeys.weatherCard),
      );
      for (final text in [
        'الجو المعتاد حسب التراث',
        'حسب التراث، وليس توقعاً للطقس.',
      ]) {
        expect(
          find.descendant(of: weather, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(find.byKey(HomeCardKeys.usualWeatherCard), findsNothing);
    });

    testWidgets('السعودية (الرياض) بلا درور (R3.10): لا شريط دَرّ، وبطاقة '
        '«الجو المعتاد حسب التراث» من الطالع، و«القادم» بلا درور', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      expect(model(tester).hasDurur, isFalse);
      expect(find.byKey(HomeCardKeys.darStrip), findsNothing);
      expect(find.textContaining('دَرّ'), findsNothing);
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.usualWeatherCard));
      final card = find.byKey(HomeCardKeys.usualWeatherCard);
      expect(
        find.descendant(of: card, matching: find.text('حر')),
        findsOneWidget,
      );
      final rows = [
        for (var i = 0; i < 3; i++) find.byKey(HomeCardKeys.upcomingRow(i)),
      ];
      expect(
        find.descendant(of: rows[0], matching: find.text('الوسم')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rows[0], matching: find.text('بعد ٩ أيام')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rows[1], matching: find.text('الشتاء')),
        findsOneWidget,
      );
      for (final r in rows) {
        expect(tester.getSize(r).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('العبارة الثابتة وسطر المصدر', (tester) async {
      phone(tester);
      await openHome(tester);
      await scrollHomeTo(
        tester,
        find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
      );
      expect(find.textContaining('المصدر: '), findsOneWidget);
    });

    testWidgets('شريط «بيانات تجريبية» ظاهر ما دامت البيانات مسودة', (
      tester,
    ) async {
      Future<void> pumpFrame(bool draft) => tester.pumpWidget(
        ProviderScope(
          overrides: [hasUnapprovedDataProvider.overrideWithValue(draft)],
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: [Locale('ar')],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DraftBannerFrame(child: SizedBox()),
          ),
        ),
      );
      await pumpFrame(true);
      await tester.pumpAndSettle();
      expect(find.text('بيانات تجريبية — غير معتمدة'), findsOneWidget);
      await pumpFrame(false);
      await tester.pumpAndSettle();
      expect(find.byKey(DraftBannerFrame.bannerKey), findsNothing);
    });

    testWidgets('القائمة تفتح الدرج، والجرس يُقرأ «الإذن مرفوض» بلا إذن', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester);
      // المُجدوِل الوهمي بلا إذن افتراضياً.
      expect(find.byTooltip('التنبيهات، الإذن مرفوض'), findsOneWidget);
      await tester.tap(find.byKey(HomeScreen.menuKey));
      await tester.pumpAndSettle();
      final drawer = find.byKey(HomeScreen.drawerKey);
      expect(drawer, findsOneWidget);
      expect(tester.getSize(drawer).width, 304);
      // من اليمين (بداية RTL).
      expect(tester.getRect(drawer).right, 412);
      for (final text in ['المدينة', 'التنبيهات', 'المصادر', 'أصل التقويم',
          'أبلغ عن خطأ']) {
        expect(
          find.descendant(of: drawer, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });
  });

  group('الوصولية (7.7، R3.5)', () {
    testWidgets('الخليج: التاريخ ← الفصل ← الدَّرّ ← النجم ← موسم الجو ← الجو', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city');
      final data = dialData(tester);
      expect(data.label, 'اليوم');
      final value = data.value;
      expect(value, startsWith('الجمعة، ٢ أكتوبر ٢٠٢٦، '));
      expect(value, contains(' هجري. '));
      expect(value, isNot(contains('٢٠٢٦م')));
      expect(value, contains('الفصل: الخريف، من ٢٣ سبتمبر إلى ٢١ ديسمبر.'));
      final order = [
        'هجري.',
        'الفصل:',
        'دَرّ ',
        'النجم:',
        'موسم الجو:',
        'الجو المعتاد:',
      ].map(value.indexOf).toList();
      expect(order.every((i) => i >= 0), isTrue, reason: value);
      expect(order, orderedEquals([...order]..sort()));
      expect(
        data.hint,
        'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الموسم.',
      );
      expect(
        customActions(tester),
        containsAll([
          'افتح صفحة النجم',
          'افتح صفحة الموسم',
          'افتح ورقة الفصل',
          'اقرأ الفصل والبرج',
          'اقرأ رموز الجو حول اليوم',
          'انتقل دَرّاً للأمام',
          'انتقل دَرّاً للخلف',
        ]),
      );
      handle.dispose();
    });

    testWidgets('السعودية: لا جملة دَرّ، و«انتقل طالعاً»، والتلميح للطالع', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester);
      final data = dialData(tester);
      final value = data.value;
      expect(value, isNot(contains('دَرّ')));
      final order = [
        'هجري.',
        'الفصل:',
        'الموسم:',
        'موسم الجو:',
        'النجم:',
        'الجو المعتاد:',
      ].map(value.indexOf).toList();
      expect(order.every((i) => i >= 0), isTrue, reason: value);
      expect(order, orderedEquals([...order]..sort()));
      expect(
        data.hint,
        'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الطالع.',
      );
      final labels = customActions(tester);
      expect(labels, contains('انتقل طالعاً للأمام'));
      expect(labels, isNot(contains('انتقل دَرّاً للأمام')));
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      performCustom(tester, 'انتقل طالعاً للأمام');
      await tester.pumpAndSettle();
      final end = info.star.end;
      expect(selected(tester), DateTime(end.year, end.month, end.day + 1));
      handle.dispose();
    });

    testWidgets('السحب لأعلى/أسفل يغيّر اليوم، و«التاريخ المعروض»', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city');
      final before = dialData(tester);
      perform(tester, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(selected(tester), DateTime(2026, 10, 3));
      final after = dialData(tester);
      expect(after.label, 'التاريخ المعروض');
      expect(after.value, before.increasedValue);
      expect(after.decreasedValue, before.value);
      perform(tester, SemanticsAction.decrease);
      perform(tester, SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(selected(tester), DateTime(2026, 10, 1));
      handle.dispose();
    });

    testWidgets('نهاية السنة وحدّا 2025 و2040', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city', now: DateTime(2026, 12, 31));
      var data = dialData(tester);
      expect(data.increasedValue, startsWith('الجمعة، ١ يناير ٢٠٢٧، '));
      expect(data.decreasedValue, startsWith('الأربعاء، ٣٠ ديسمبر ٢٠٢٦، '));

      containerOf(tester)
          .read(selectedDateProvider.notifier)
          .select(DateTime(2040, 12, 31));
      await tester.pumpAndSettle();
      data = dialData(tester);
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.decreasedValue, startsWith('الأحد، ٣٠ ديسمبر ٢٠٤٠، '));

      containerOf(tester)
          .read(selectedDateProvider.notifier)
          .select(DateTime(2025, 1, 1));
      await tester.pumpAndSettle();
      data = dialData(tester);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      expect(data.increasedValue, startsWith('الخميس، ٢ يناير ٢٠٢٥، '));
      handle.dispose();
    });

    testWidgets('إجراء «انتقل دَرّاً للأمام» في الخليج', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city');
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      performCustom(tester, 'انتقل دَرّاً للأمام');
      await tester.pumpAndSettle();
      final end = info.dar!.end;
      expect(selected(tester), DateTime(end.year, end.month, end.day + 1));
      handle.dispose();
    });

    testWidgets('خط 200% على شاشة 320dp بلا فيضان، والبطاقات عمود واحد', (
      tester,
    ) async {
      phone(tester, width: 320, height: 640);
      await openHome(tester, city: 'muscat', textScale: 2);
      expect(tester.takeException(), isNull);
      await scrollHomeTo(
        tester,
        find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
      );
      expect(tester.takeException(), isNull);
      final starBox = tester.getRect(find.byKey(HomeCardKeys.starCard));
      final agriBox = tester.getRect(find.byKey(HomeCardKeys.agriCard));
      expect(starBox.top, greaterThanOrEqualTo(agriBox.bottom));
    });

    testWidgets('شاشة 320dp بخط عادي، وأهداف اللمس 48dp', (tester) async {
      phone(tester, width: 320, height: 640);
      await openHome(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(DayDial.dialKey)).width,
        lessThanOrEqualTo(320),
      );
      for (final k in [
        HomeScreen.prevKey,
        HomeScreen.nextKey,
        HomeScreen.placeKey,
        HomeScreen.datesLineKey,
        HomeScreen.menuKey,
        HomeScreen.bellKey,
      ]) {
        expect(tester.getSize(find.byKey(k)).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('المعيار 5: التنقل وزر «اليوم»', () {
    testWidgets('التالي/السابق، و«اليوم» يظهر ويعيد', (tester) async {
      phone(tester);
      await openHome(tester);
      expect(find.byKey(HomeScreen.todayButtonKey), findsNothing);
      await tester.tap(find.byKey(HomeScreen.nextKey));
      await tester.pumpAndSettle();
      expect(selected(tester), DateTime(2026, 10, 3));
      expect(find.text('تعرض: ٢٢ ربيع الآخر ١٤٤٨هـ'), findsOneWidget);
      expect(find.byKey(HomeScreen.todayButtonKey), findsOneWidget);
      await tester.tap(find.byKey(HomeScreen.todayButtonKey));
      await tester.pumpAndSettle();
      expect(selected(tester), DateTime(2026, 10, 2));
      expect(find.byKey(HomeScreen.todayButtonKey), findsNothing);
      await tester.tap(find.byKey(HomeScreen.prevKey));
      await tester.pumpAndSettle();
      expect(selected(tester), DateTime(2026, 10, 1));
    });

    testWidgets('الضغط المطوّل على التالي يقفز لبداية الدَّرّ التالي', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city');
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      await tester.longPress(find.byKey(HomeScreen.nextKey));
      await tester.pumpAndSettle();
      final s = selected(tester);
      expect(containerOf(tester).read(dayInfoProvider(s))!.dar!.dayNumber, 1);
      final end = info.dar!.end;
      expect(s, DateTime(end.year, end.month, end.day + 1));
    });

    testWidgets('بلا درور: الضغط المطوّل يقفز طالعاً', (tester) async {
      phone(tester);
      await openHome(tester);
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      await tester.longPress(find.byKey(HomeScreen.nextKey));
      await tester.pumpAndSettle();
      final end = info.star.end;
      expect(selected(tester), DateTime(end.year, end.month, end.day + 1));
    });

    testWidgets('القرص ثابت والعقرب يتبع الإصبع: عكس عقارب الساعة يقدّم، '
        'ومعها يرجع (R3.1-3)', (tester) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city');
      final start = degOf(DateTime(2026, 10, 2));
      var g = await tester.startGesture(dialPoint(tester, 0.59, start));
      await tester.pump();
      for (var d = 2; d <= 30; d += 2) {
        await g.moveTo(dialPoint(tester, 0.59, start - d));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      final forward = selected(tester);
      final days = forward.difference(DateTime(2026, 10, 2)).inDays;
      expect(days, inInclusiveRange(27, 33));
      expect(find.byKey(HomeScreen.todayButtonKey), findsOneWidget);

      g = await tester.startGesture(dialPoint(tester, 0.59, start - 30));
      await tester.pump();
      for (var d = 28; d >= 10; d -= 2) {
        await g.moveTo(dialPoint(tester, 0.59, start - d));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(selected(tester).isBefore(forward), isTrue);
    });

    testWidgets('ضغطة على حلقة الأشهر تنقل العقرب إلى أول الشهر', (tester) async {
      phone(tester);
      await openHome(tester);
      await tapDial(tester, dialPoint(tester, 0.82, degOf(DateTime(2026, 11, 15))));
      expect(selected(tester), DateTime(2026, 11, 1));
    });

    testWidgets('المحور: يعيد إلى اليوم، وإن كان المعروض اليوم يفتح ورقة الفصل', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city');
      await tester.tap(find.byKey(HomeScreen.nextKey));
      await tester.pumpAndSettle();
      await tapDial(tester, dialPoint(tester, 0, 0));
      expect(selected(tester), DateTime(2026, 10, 2));
      await tapDial(tester, dialPoint(tester, 0, 0));
      expect(find.byKey(AstroSheetKeys.season), findsOneWidget);
    });
  });

  group('المعيار 4: الضغط على جزء في الدائرة يفتح ورقته', () {
    testWidgets('الطالع، والدَّرّ، والبرج، والفصل', (tester) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city');
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      final deg = degOf(DateTime(2026, 10, 2));
      final sheet = find.byKey(ItemDetailSheet.sheetKey);

      await tapDial(tester, dialPoint(tester, 0.455, deg));
      expect(find.descendant(of: sheet, matching: find.text('نجم')), findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(tables.items[info.star.itemId]!.name.ar),
        ),
        findsOneWidget,
      );
      await closeSheet(tester, sheet);

      await tapDial(tester, dialPoint(tester, 0.59, deg));
      expect(find.descendant(of: sheet, matching: find.text('دَرّ')), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text(info.dar!.name.ar)),
        findsOneWidget,
      );
      await closeSheet(tester, sheet);

      await tapDial(tester, dialPoint(tester, 0.38, deg));
      final zodiac = find.byKey(AstroSheetKeys.zodiac);
      expect(
        find.descendant(of: zodiac, matching: find.text('الشمس في برج الميزان')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: zodiac,
          matching: find.text('موقع الشمس بين البروج، حساب فلكي.'),
        ),
        findsOneWidget,
      );
      await closeSheet(tester, zodiac);

      await tapDial(tester, dialPoint(tester, 0.2, deg));
      final season = find.byKey(AstroSheetKeys.season);
      for (final text in [
        'الخريف',
        'مدته ٨٩ يوماً',
        'مضى ٩ أيام — بقي ٨٠ يوماً',
        'حساب فلكي',
      ]) {
        expect(
          find.descendant(of: season, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(
          of: season,
          matching: find.textContaining('يبدأ: الأربعاء ٢٣ سبتمبر ٢٠٢٦م، '),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: season,
          matching: find.textContaining('يقابله في التراث: '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('بلا درور: حلقة الطوالع مكان الدرور', (tester) async {
      phone(tester);
      await openHome(tester);
      await tapDial(tester, dialPoint(tester, 0.60, degOf(DateTime(2026, 10, 2))));
      final sheet = find.byKey(ItemDetailSheet.sheetKey);
      expect(find.descendant(of: sheet, matching: find.text('نجم')), findsOneWidget);
    });
  });

  testWidgets('التكبير: ضغطتان ← زر «إعادة الحجم»، والزر يعيد 1×', (
    tester,
  ) async {
    phone(tester);
    await openHome(tester);
    final at = dialPoint(tester, 0.59, 0);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byKey(DayDial.resetZoomKey), findsOneWidget);
    expect(find.byTooltip('إعادة الحجم'), findsOneWidget);
    await tester.dragFrom(at, const Offset(-60, 40));
    await tester.pumpAndSettle();
    expect(selected(tester), DateTime(2026, 10, 2));
    await tester.tap(find.byKey(DayDial.resetZoomKey));
    await tester.pumpAndSettle();
    expect(find.byKey(DayDial.resetZoomKey), findsNothing);
  });

  group('التحميل والخطأ', () {
    testWidgets('تحميل بطيء: لا شيء قبل 300ms، ثم هيكل رمادي', (tester) async {
      phone(tester);
      final pending = Completer<Tables>();
      await pumpScreen(
        tester,
        const HomeScreen(),
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: null,
        extra: [tablesProvider.overrideWith((ref) => pending.future)],
      );
      expect(find.byKey(HomeScreen.skeletonKey), findsNothing);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(HomeScreen.skeletonKey), findsOneWidget);
      pending.complete(tables);
      await tester.pumpAndSettle();
      expect(find.byKey(DayDial.dialKey), findsOneWidget);
    });

    testWidgets('فشل تحميل الجداول ← رسالة وإعادة المحاولة تنجح', (
      tester,
    ) async {
      phone(tester);
      var calls = 0;
      await pumpScreen(
        tester,
        const HomeScreen(),
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: null,
        extra: [
          fixedClock(DateTime(2026, 10, 2, 9)),
          tablesProvider.overrideWith((ref) async {
            calls++;
            if (calls == 1) throw const FormatException('تالف');
            return tables;
          }),
        ],
      );
      expect(find.byKey(HomeScreen.loadErrorKey), findsOneWidget);
      expect(find.text('تعذّر فتح بيانات الدرور'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(DayDial.dialKey), findsOneWidget);
    });
  });

  testWidgets('منتصف الليل والتطبيق مفتوح: يتحدث «اليوم» تلقائياً', (
    tester,
  ) async {
    phone(tester);
    var now = DateTime(2026, 10, 2, 23, 59, 58);
    await pumpScreen(
      tester,
      const HomeScreen(),
      prefs: await fakePrefs(savedCity('riyadh')),
      tables: tables,
      extra: [clockProvider.overrideWithValue(() => now)],
    );
    expect(selected(tester), DateTime(2026, 10, 2));
    now = DateTime(2026, 10, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(selected(tester), DateTime(2026, 10, 3));
    expect(find.text('٢٢ ربيع الآخر ١٤٤٨هـ'), findsOneWidget);
  });

  group('R3.1-17: العدّاد والبطاقات', () {
    testWidgets('العدّاد: «٩ أيام على دخول الوسم» بلا «باقي»، وقارئ الشاشة', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final counter = find.byKey(HomeCardKeys.countdown);
      for (final text in ['٩', 'أيام', 'على دخول الوسم', 'الجمعة ١٦ أكتوبر']) {
        expect(
          find.descendant(of: counter, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(of: counter, matching: find.text('باقي')),
        findsNothing,
      );
      expect(tester.getSize(counter).width, 200);
      expect(tester.getSize(counter).height, greaterThanOrEqualTo(84));
      expect(
        tester.getSemantics(counter).label,
        'باقي ٩ أيام على دخول الوسم، الجمعة ١٦ أكتوبر',
      );
      handle.dispose();
    });

    testWidgets('يوم البداية نفسه: «دخل الوسم اليوم»، وتاريخ آخر ← «من …»', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 16, 9));
      expect(find.text('دخل الوسم اليوم'), findsOneWidget);
      await tester.tap(find.byKey(HomeScreen.nextKey));
      await tester.pumpAndSettle();
      expect(find.text('من ١٧ أكتوبر ٢٠٢٦م'), findsOneWidget);
    });

    testWidgets('القادم في الخليج: الدَّرّ التالي والموسم الكبير بالأيام', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city', now: DateTime(2026, 10, 7, 9));
      final card = find.byKey(HomeCardKeys.upcomingCard);
      expect(
        find.descendant(of: card, matching: find.textContaining('دَرّ ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('الدرور والمواسم والطوالع')),
        findsOneWidget,
      );
    });

    testWidgets('الزراعة بلا بيانات: النص بالضبط و«أعرف مصدراً» يفتح البلاغ', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester);
      final card = find.byKey(HomeCardKeys.agriCard);
      await scrollHomeTo(tester, card);
      expect(
        find.descendant(
          of: card,
          matching: find.text('لا توجد بيانات زراعية موثقة لمنطقتك'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(HomeCardKeys.agriKnowSource));
      await tester.pumpAndSettle();
      expect(find.byKey(ReportSheet.sheetKey), findsOneWidget);
      expect(find.textContaining('نجد'), findsWidgets);
    });
  });

  group('الميزة 16: رموز الجو في الإطار (R3.1-5)', () {
    DayDialState dialState(WidgetTester tester) =>
        tester.state<DayDialState>(find.byType(DayDial));

    testWidgets('رمز لكل دَرّ، والضغط على خليته يفتح فقاعة واحدة بالاسم والشرح '
        'والفترة، وتُغلق بالضغط خارجها', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'muscat', now: DateTime(2026, 10, 7, 9));
      final marks = dialState(tester).visibleMarks;
      expect(marks.length, greaterThanOrEqualTo(20));
      final screen = tester.getRect(find.byType(HomeScreen));
      final mark = marks.firstWhere(
        (m) => screen.deflate(30).contains(m.center),
      );
      await tapDial(tester, mark.center);
      final bubble = find.byKey(SymbolBubbleContent.contentKey);
      expect(bubble, findsOneWidget);
      final name = AppLocalizations.of(
        tester.element(bubble),
      ).weatherSymbolName(mark.symbol.code);
      expect(find.descendant(of: bubble, matching: find.text(name)), findsOneWidget);
      expect(
        find.descendant(of: bubble, matching: find.textContaining('يتبع: دَرّ ')),
        findsOneWidget,
      );
      expect(tester.getSemantics(bubble).label, startsWith('$name. '));
      final rect = tester.getRect(bubble);
      expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight), isTrue);
      expect(find.byKey(ItemDetailSheet.sheetKey), findsNothing);
      await tester.tapAt(screen.bottomLeft + const Offset(10, -10));
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);
      expect(selected(tester), DateTime(2026, 10, 7));
      handle.dispose();
    });

    testWidgets('الضغط على خلية أخرى والفقاعة مفتوحة يفتح فقاعتها (واحدة فقط)', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, city: 'muscat', now: DateTime(2026, 10, 7, 9));
      final screen = tester.getRect(find.byType(HomeScreen));
      final marks = dialState(tester).visibleMarks
          .where((m) => screen.deflate(30).contains(m.center))
          .toList();
      final other = marks.firstWhere((m) => m.symbol != marks[0].symbol);
      await tapDial(tester, marks[0].center);
      await tester.tapAt(other.center);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final bubble = find.byKey(SymbolBubbleContent.contentKey);
      expect(bubble, findsOneWidget);
      final name = AppLocalizations.of(
        tester.element(bubble),
      ).weatherSymbolName(other.symbol.code);
      expect(find.descendant(of: bubble, matching: find.text(name)), findsOneWidget);
    });

    testWidgets('بلا درور: الفقاعة «يتبع: طالع …»', (tester) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final screen = tester.getRect(find.byType(HomeScreen));
      final mark = dialState(tester).visibleMarks.firstWhere(
        (m) => screen.deflate(30).contains(m.center),
      );
      expect(mark.cell.starItemId, isNotNull);
      await tapDial(tester, mark.center);
      expect(
        find.descendant(
          of: find.byKey(SymbolBubbleContent.contentKey),
          matching: find.textContaining('يتبع: طالع '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('شريحة الجو تفتح فقاعة الرمز', (tester) async {
      phone(tester);
      await openHome(tester);
      final chip = find.byKey(HomeCardKeys.weatherChip(WeatherSymbol.hot));
      await scrollHomeTo(tester, chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      final bubble = find.byKey(SymbolBubbleContent.contentKey);
      expect(
        find.descendant(
          of: bubble,
          matching: find.text('حرّ معتاد في هذه الفترة حسب التراث.'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(ItemDetailSheet.sheetKey), findsNothing);
    });

    testWidgets('خط ≥ 1.5×: الفقاعة ورقة سفلية بالمحتوى نفسه', (tester) async {
      phone(tester, width: 320, height: 640);
      await openHome(tester, textScale: 2);
      final chip = find.byKey(HomeCardKeys.weatherChip(WeatherSymbol.hot));
      await scrollHomeTo(tester, chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(SymbolBubbleContent.contentKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
