import 'dart:async';
import 'dart:math' as math;

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/features/common/draft_banner.dart';
import 'package:durur/src/features/home/day_card.dart';
import 'package:durur/src/features/home/dial/day_dial.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/item_detail/item_detail_sheet.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// الميزة 6: الشاشة الرئيسية والدائرة التفاعلية (SPEC 6، DESIGN 7 و8.4).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  void phone(WidgetTester tester, {double width = 411, double height = 900}) {
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
      prefs: await fakePrefs({SettingsRepository.cityIdKey: city}),
      tables: withTables ?? tables,
      textScale: textScale,
      extra: [fixedClock(now ?? DateTime(2026, 10, 2, 9, 30))],
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

  DateTime selected(WidgetTester tester) =>
      containerOf(tester).read(selectedDateProvider);

  SemanticsData dialData(WidgetTester tester) =>
      tester.getSemantics(find.byKey(DayDial.dialKey)).getSemanticsData();

  void perform(WidgetTester tester, SemanticsAction action) {
    final node = tester.getSemantics(find.byKey(DayDial.dialKey));
    node.owner!.performAction(node.id, action);
  }

  Offset dialPoint(WidgetTester tester, double refRadius, double degrees) {
    final c = tester.getCenter(find.byKey(DayDial.dialKey));
    final r = tester.getSize(find.byKey(DayDial.dialKey)).width / 2;
    final rr = refRadius / 170 * r;
    final a = degrees * math.pi / 180;
    return c + Offset(rr * math.sin(a), -rr * math.cos(a));
  }

  Future<void> tapDial(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    // الضغطة تنتظر مهلة الضغطتين المتتاليتين (التكبير).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('المعيار 1 و2: الدائرة واليوم بنظرة', () {
    testWidgets('تظهر الدائرة والبطاقة لليوم، والشاشة RTL', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'muscat');
      expect(find.byKey(DayDial.dialKey), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byKey(DayDial.dialKey))),
        TextDirection.rtl,
      );

      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      final card = find.byKey(DayCard.cardKey);
      // الدَّرّ واليوم داخله والموسم والنجم وموسم الجو ورموز الجو.
      for (final text in [
        info.dar.name.ar,
        tables.items[info.majorSeason.itemId]!.name.ar,
        tables.items[info.star.itemId]!.name.ar,
        'حر',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsWidgets,
          reason: text,
        );
      }
      expect(find.text('اليوم ٣ من ١٠'), findsWidgets);
      expect(find.text('لا يوجد موسم جو مسمّى في هذه الأيام'), findsOneWidget);
      // اسم المدينة في الشريحة، والتاريخان مع اسم اليوم.
      expect(find.text('مسقط · الإمارات وعُمان'), findsOneWidget);
      expect(
        findDatesLine('الجمعة ٢ أكتوبر ٢٠٢٦م\u00a0— ٢١ ربيع الآخر ١٤٤٨هـ'),
        findsOneWidget,
      );
      handle.dispose();
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
  });

  group('الوصولية (DESIGN 7.7)', () {
    testWidgets('label البادئة فقط، وvalue المتغيّر بطول الدَّرّ الفعلي', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      // الرياض ← درور الإمارات وعُمان: دَرّ 6 أغسطس طوله 5 أيام في التجريبية.
      await openHome(tester, now: DateTime(2026, 8, 8, 7));
      final data = dialData(tester);
      expect(data.label, 'اليوم');
      final value = data.value;
      // التاريخ مسموعاً بلا «م» و«هـ»، وكلمة «هجري».
      expect(value, startsWith('السبت، ٨ أغسطس ٢٠٢٦، '));
      expect(value, contains(' هجري. '));
      expect(value, isNot(contains('٢٠٢٦م')));
      expect(value, isNot(contains('هـ')));
      expect(value, contains('اليوم ٣ من ٥.'));
      expect(value, isNot(contains('عشرة')));
      // نجد تستعير: الموسم ← موسم الجو ← النجم ← الدَّرّ المستعار ← الجو (7.7).
      final order = [
        'الموسم:',
        'موسم الجو:',
        'النجم:',
        'دَرّ ',
        'الجو المعتاد:',
      ].map(value.indexOf).toList();
      expect(order.every((i) => i >= 0), isTrue, reason: value);
      expect(order, orderedEquals([...order]..sort()));
      expect(value, contains('حسب حساب الإمارات وعُمان'));
      // اليوم التالي والسابق.
      expect(data.increasedValue, startsWith('الأحد، ٩ أغسطس ٢٠٢٦، '));
      expect(data.increasedValue, contains('اليوم ٤ من ٥.'));
      expect(data.decreasedValue, startsWith('الجمعة، ٧ أغسطس ٢٠٢٦، '));
      expect(data.decreasedValue, contains('اليوم ٢ من ٥.'));
      // المحور للمستعيرة يفتح الموسم (7.8).
      expect(
        data.hint,
        'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الموسم.',
      );
      handle.dispose();
    });

    testWidgets('منطقة بدرورها: الدَّرّ بعد التاريخ، والتلميح يفتح الدَّرّ', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city');
      final data = dialData(tester);
      expect(data.value, startsWith('الجمعة، ٢ أكتوبر ٢٠٢٦، '));
      final value = data.value;
      expect(value.indexOf('دَرّ '), lessThan(value.indexOf('النجم:')));
      expect(value.indexOf('النجم:'), lessThan(value.indexOf('موسم الجو:')));
      expect(
        data.hint,
        'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الدَّرّ.',
      );
      handle.dispose();
    });

    testWidgets('السحب لأعلى/أسفل يغيّر اليوم، و«التاريخ المعروض»', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city');
      final before = dialData(tester);
      expect(before.label, 'اليوم');

      perform(tester, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(selected(tester), DateTime(2026, 10, 3));
      final after = dialData(tester);
      expect(after.label, 'التاريخ المعروض');
      // قيمة اليوم الجديد = increasedValue المعلنة قبله.
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
      expect(data.increasedValue, isEmpty);
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.decreasedValue, startsWith('الأحد، ٣٠ ديسمبر ٢٠٤٠، '));

      containerOf(tester)
          .read(selectedDateProvider.notifier)
          .select(DateTime(2025, 1, 1));
      await tester.pumpAndSettle();
      data = dialData(tester);
      expect(data.decreasedValue, isEmpty);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.increasedValue, startsWith('الخميس، ٢ يناير ٢٠٢٥، '));
      handle.dispose();
    });

    testWidgets('إجراءات مخصصة: الدَّرّ التالي والعودة لليوم', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, city: 'kuwait_city');
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      final data = tester
          .getSemantics(find.byKey(DayDial.dialKey))
          .getSemanticsData();
      final labels = [
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(
        labels,
        containsAll([
          'افتح صفحة النجم',
          'افتح صفحة الموسم',
          'انتقل دَرّاً للأمام',
          'انتقل دَرّاً للخلف',
        ]),
      );
      final next = labels.indexOf('انتقل دَرّاً للأمام');
      final node = tester.getSemantics(find.byKey(DayDial.dialKey));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        data.customSemanticsActionIds![next],
      );
      await tester.pumpAndSettle();
      final end = info.dar.end;
      expect(selected(tester), DateTime(end.year, end.month, end.day + 1));
      handle.dispose();
    });

    testWidgets('خط 200% على شاشة 320dp بلا فيضان ولا قصّ', (tester) async {
      phone(tester, width: 320, height: 640);
      await openHome(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      await scrollHomeTo(
        tester,
        find.text('الجو المعتاد حسب التراث، وليس توقعاً للطقس'),
      );
      expect(tester.takeException(), isNull);
      // الدائرة تصغر إلى 75% من العرض عند تكبير الخط (DESIGN 7.6).
    });

    testWidgets('شاشة 320dp بخط عادي، وأهداف اللمس 48dp', (tester) async {
      phone(tester, width: 320, height: 640);
      final handle = tester.ensureSemantics();
      await openHome(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(DayDial.dialKey)).width,
        lessThanOrEqualTo(320),
      );
      for (final k in [
        HomeScreen.prevKey,
        HomeScreen.nextKey,
        HomeScreen.pickDateKey,
      ]) {
        expect(tester.getSize(find.byKey(k)).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
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
      // النص الظاهر (ونسخة مخفية تثبّت ارتفاع السطر).
      expect(
        findDatesLine('تعرض: السبت ٣ أكتوبر ٢٠٢٦م\u00a0— ٢٢ ربيع الآخر ١٤٤٨هـ'),
        findsWidgets,
      );
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
      expect(containerOf(tester).read(dayInfoProvider(s))!.dar.dayNumber, 1);
      expect(s.isAfter(DateTime(2026, 10, 2)), isTrue);
      expect(
        s,
        DateTime(info.dar.end.year, info.dar.end.month, info.dar.end.day + 1),
      );
    });

    testWidgets('السحب الدائري عكس عقارب الساعة يقدّم التاريخ ومعها يرجعه', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester);
      // من يمين الدائرة (90°) صعوداً إلى 60°: عكس عقارب الساعة ≈ 30 يوماً.
      var g = await tester.startGesture(dialPoint(tester, 116, 90));
      await tester.pump();
      for (var deg = 88; deg >= 60; deg -= 2) {
        await g.moveTo(dialPoint(tester, 116, deg.toDouble()));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      final forward = selected(tester);
      final days = forward.difference(DateTime(2026, 10, 2)).inDays;
      expect(days, inInclusiveRange(25, 32));
      expect(find.byKey(HomeScreen.todayButtonKey), findsOneWidget);

      // مع عقارب الساعة يرجع.
      g = await tester.startGesture(dialPoint(tester, 116, 60));
      await tester.pump();
      for (var deg = 62; deg <= 80; deg += 2) {
        await g.moveTo(dialPoint(tester, 116, deg.toDouble()));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(selected(tester).isBefore(forward), isTrue);
    });

    testWidgets('ضغطة على حلقة الأشهر تدير إلى أول الشهر', (tester) async {
      phone(tester);
      await openHome(tester);
      // 30 يوماً مع عقارب الساعة ≈ أول نوفمبر تقريباً.
      await tapDial(tester, dialPoint(tester, 160, 32));
      expect(selected(tester), DateTime(2026, 11, 1));
    });
  });

  group('المعيار 4: الضغط على جزء في الدائرة يفتح ورقته (الميزة 7)', () {
    testWidgets('النجم، والموسم، والمحور (الدَّرّ)', (tester) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city');
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      final sheet = find.byKey(ItemDetailSheet.sheetKey);

      await tapDial(tester, dialPoint(tester, 90, 0));
      expect(
        find.descendant(of: sheet, matching: find.text('نجم')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(tables.items[info.star.itemId]!.name.ar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining('في جدول الكويت'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      await tapDial(tester, dialPoint(tester, 138, 0));
      expect(
        find.descendant(of: sheet, matching: find.text('موسم')),
        findsOneWidget,
      );
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      await tapDial(tester, dialPoint(tester, 0, 0));
      expect(
        find.descendant(of: sheet, matching: find.text('دَرّ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(info.dar.name.ar)),
        findsOneWidget,
      );
    });

    testWidgets('دَرّ مستعار: الورقة بجدول المُعيرة', (tester) async {
      phone(tester);
      await openHome(tester);
      await tapDial(tester, dialPoint(tester, 116, 0));
      expect(
        find.descendant(
          of: find.byKey(ItemDetailSheet.sheetKey),
          matching: find.textContaining('في جدول الإمارات وعُمان'),
        ),
        findsOneWidget,
      );
    });

    // صفوف البطاقة تفتح صفحة كاملة بمسار: test/widgets/item_detail_test.dart.
  });

  testWidgets('التكبير: ضغطتان ← زر «إعادة الحجم»، والزر يعيد 1×', (
    tester,
  ) async {
    phone(tester);
    await openHome(tester);
    final at = dialPoint(tester, 116, 0);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byKey(DayDial.resetZoomKey), findsOneWidget);
    expect(find.byTooltip('إعادة الحجم'), findsOneWidget);
    // في التكبير السحب يحرّك الدائرة ولا يغيّر اليوم.
    await tester.dragFrom(at, const Offset(-60, 40));
    await tester.pumpAndSettle();
    expect(selected(tester), DateTime(2026, 10, 2));
    await tester.tap(find.byKey(DayDial.resetZoomKey));
    await tester.pumpAndSettle();
    expect(find.byKey(DayDial.resetZoomKey), findsNothing);
  });

  group('D24: عرض السعودية', () {
    testWidgets('الرياض: المواسم والطوالع أولاً، ثم الدَّرّ والسطر الثابت', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester);
      expect(find.byKey(HomeScreen.legendKey), findsOneWidget);
      expect(find.text('حلقة الدرور: حساب الإمارات وعُمان'), findsOneWidget);
      await scrollHomeTo(tester, find.byKey(DayCard.borrowNoteKey));
      final note = tables.regionTables['najd']!.dururBorrow!.note.ar;
      expect(find.text(note), findsOneWidget);
      expect(find.text('الدَّرّ حسب حساب الإمارات وعُمان'), findsOneWidget);
      final starY = tester.getTopLeft(find.text('النجم')).dy;
      final darY = tester
          .getTopLeft(find.text('الدَّرّ حسب حساب الإمارات وعُمان'))
          .dy;
      expect(starY, lessThan(darY));
    });

    testWidgets('محور الرياض: الموسم و«طالع النجم»، والضغط يفتح الموسم', (
      tester,
    ) async {
      phone(tester);
      // 20 أكتوبر في نجد التجريبية: موسم الجو «الوسم».
      await openHome(tester, now: DateTime(2026, 10, 20, 9));
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 20)))!;
      expect(info.weatherSeason?.itemId, 'wasm');
      final dial = find.byKey(DayDial.dialKey);
      final star = tables.items[info.star.itemId]!.name.ar;
      expect(
        find.descendant(of: dial, matching: find.text('الوسم')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dial, matching: find.text('طالع $star')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dial, matching: find.text(info.dar.name.ar)),
        findsNothing,
      );
      await tapDial(tester, dialPoint(tester, 0, 0));
      final sheet = find.byKey(ItemDetailSheet.sheetKey);
      expect(
        find.descendant(of: sheet, matching: find.text('موسم جو')),
        findsOneWidget,
      );
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      // البطاقة: الموسم أولاً، وصف موسم الجو محذوف لأنه في السطر الأول،
      // ثم قسم الدَّرّ مع السطر الثابت ورابط «أصل التقويم».
      expect(find.text('موسم الجو'), findsNothing);
      await scrollHomeTo(tester, find.byKey(DayCard.originLinkKey));
      expect(find.text('أصل التقويم'), findsOneWidget);
      final titleY = tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(DayCard.cardKey),
              matching: find.text('الوسم'),
            ),
          )
          .dy;
      final darY = tester
          .getTopLeft(find.text('الدَّرّ حسب حساب الإمارات وعُمان'))
          .dy;
      expect(titleY, lessThan(darY));
    });

    testWidgets('محور الرياض بلا موسم جو: الموسم الكبير', (tester) async {
      phone(tester);
      await openHome(tester);
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      expect(info.weatherSeason, isNull);
      expect(
        find.descendant(
          of: find.byKey(DayDial.dialKey),
          matching: find.text(tables.items[info.majorSeason.itemId]!.name.ar),
        ),
        findsOneWidget,
      );
      await tapDial(tester, dialPoint(tester, 0, 0));
      expect(
        find.descendant(
          of: find.byKey(ItemDetailSheet.sheetKey),
          matching: find.text('موسم'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('سطر التاريخين ينكسر إلى سطرين بلا فاصل إن لم يتسع', (
      tester,
    ) async {
      phone(tester, width: 320, height: 640);
      await openHome(tester, textScale: 2);
      expect(
        find.text('الجمعة ٢ أكتوبر ٢٠٢٦م\n٢١ ربيع الآخر ١٤٤٨هـ'),
        findsOneWidget,
      );
      expect(find.textContaining('—'), findsNothing);
    });

    testWidgets('مسقط (جدولها): بلا سطر استعارة', (tester) async {
      phone(tester);
      await openHome(tester, city: 'muscat');
      expect(find.byKey(HomeScreen.legendKey), findsNothing);
      expect(find.byKey(DayCard.borrowNoteKey), findsNothing);
    });
  });

  group('التحميل والخطأ', () {
    testWidgets('تحميل بطيء: لا شيء قبل 300ms، ثم هيكل رمادي', (tester) async {
      phone(tester);
      final pending = Completer<Tables>();
      await pumpScreen(
        tester,
        const HomeScreen(),
        prefs: await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'}),
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
        prefs: await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'}),
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
      prefs: await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'}),
      tables: tables,
      extra: [clockProvider.overrideWithValue(() => now)],
    );
    expect(selected(tester), DateTime(2026, 10, 2));
    now = DateTime(2026, 10, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(selected(tester), DateTime(2026, 10, 3));
    expect(
      findDatesLine('السبت ٣ أكتوبر ٢٠٢٦م\u00a0— ٢٢ ربيع الآخر ١٤٤٨هـ'),
      findsOneWidget,
    );
  });
}
