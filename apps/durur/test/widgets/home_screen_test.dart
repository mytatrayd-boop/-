import 'dart:async';
import 'dart:math' as math;

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/domain/weather_symbol.dart';
import 'package:durur/src/features/common/draft_banner.dart';
import 'package:durur/src/features/home/dial/day_dial.dart';
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

/// الميزة 6 و16: الشاشة الرئيسية والدائرة التفاعلية (SPEC 6 و16، DESIGN R2.5–R2.8
/// و7.4 و7.7).
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

  SemanticsData dialData(WidgetTester tester) =>
      tester.getSemantics(find.byKey(DayDial.dialKey)).getSemanticsData();

  void perform(WidgetTester tester, SemanticsAction action) {
    final node = tester.getSemantics(find.byKey(DayDial.dialKey));
    node.owner!.performAction(node.id, action);
  }

  /// نقطة على الدائرة: [fraction] من نصف القطر R (R2.5)، و[degrees] مع عقارب
  /// الساعة من الإبرة. منتصفات الحلقات: A 0.935، الأشهر 0.80، الدرور 0.655،
  /// الطوالع 0.505، المركز 0.28، المقبض 0.
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

  group('المعيار 1 و2: الدائرة واليوم بنظرة', () {
    testWidgets('تظهر الدائرة والبطاقات لليوم، والشاشة RTL', (tester) async {
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
      // بطاقة الطالع: النجم والموسم وموسم الجو (لا يوجد).
      final star = find.byKey(HomeCardKeys.starCard);
      for (final text in [
        tables.items[info.star.itemId]!.name.ar,
        'الموسم: ${tables.items[info.majorSeason.itemId]!.name.ar}',
        'موسم الجو: لا يوجد',
      ]) {
        expect(
          find.descendant(of: star, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      // الجو المعتاد: شرائح الرموز والسطر الثابت.
      final weather = find.byKey(HomeCardKeys.weatherCard);
      expect(
        find.descendant(of: weather, matching: find.text('حر')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: weather,
          matching: find.text('حسب التراث، وليس توقعاً للطقس.'),
        ),
        findsOneWidget,
      );
      // اسم المدينة في الشريحة، والتاريخان مع اسم اليوم.
      expect(find.text('مسقط · الإمارات وعُمان'), findsOneWidget);
      expect(
        findDatesLine('الجمعة ٢ أكتوبر ٢٠٢٦م\u00a0— ٢١ ربيع الآخر ١٤٤٨هـ'),
        findsOneWidget,
      );
      // شريط الدَّرّ: الاسم واليوم داخله.
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.darStrip));
      final dar = find.byKey(HomeCardKeys.darStrip);
      expect(
        find.descendant(of: dar, matching: find.text('دَرّ ${info.dar.name.ar}')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dar, matching: find.text('اليوم ٣ من ١٠')),
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

    testWidgets('منطقة بدرورها: الدَّرّ بعد التاريخ، والتلميح يفتح الموسم (المركز)', (
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
      // المركز يعرض الموسم في كل المناطق (R2.5 F)، فالنقر المزدوج يفتحه.
      expect(
        data.hint,
        'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الموسم.',
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
          'اقرأ رموز الجو حول اليوم',
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
      // الدائرة تصغر إلى 75% من العرض عند تكبير الخط (DESIGN 7.6)، والبطاقات
      // عمود واحد (R2.10).
      final starBox = tester.getRect(find.byKey(HomeCardKeys.starCard));
      final weatherBox = tester.getRect(find.byKey(HomeCardKeys.weatherCard));
      expect(weatherBox.top, greaterThanOrEqualTo(starBox.bottom));
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
      for (final k in [HomeScreen.prevKey, HomeScreen.nextKey]) {
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
      var g = await tester.startGesture(dialPoint(tester, 0.655, 90));
      await tester.pump();
      for (var deg = 88; deg >= 60; deg -= 2) {
        await g.moveTo(dialPoint(tester, 0.655, deg.toDouble()));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      final forward = selected(tester);
      final days = forward.difference(DateTime(2026, 10, 2)).inDays;
      expect(days, inInclusiveRange(25, 32));
      expect(find.byKey(HomeScreen.todayButtonKey), findsOneWidget);

      // مع عقارب الساعة يرجع.
      g = await tester.startGesture(dialPoint(tester, 0.655, 60));
      await tester.pump();
      for (var deg = 62; deg <= 80; deg += 2) {
        await g.moveTo(dialPoint(tester, 0.655, deg.toDouble()));
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
      await tapDial(tester, dialPoint(tester, 0.80, 32));
      expect(selected(tester), DateTime(2026, 11, 1));
    });
  });

  group('المعيار 4: الضغط على جزء في الدائرة يفتح ورقته (الميزة 7)', () {
    testWidgets('الطالع، والمركز (الموسم)، والدَّرّ، والمقبض', (tester) async {
      phone(tester);
      await openHome(tester, city: 'kuwait_city');
      final info = containerOf(tester)
          .read(dayInfoProvider(DateTime(2026, 10, 2)))!;
      final sheet = find.byKey(ItemDetailSheet.sheetKey);

      await tapDial(tester, dialPoint(tester, 0.505, 0));
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

      await tapDial(tester, dialPoint(tester, 0.28, 0));
      expect(
        find.descendant(of: sheet, matching: find.text('موسم')),
        findsOneWidget,
      );
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      await tapDial(tester, dialPoint(tester, 0.655, 0));
      expect(
        find.descendant(of: sheet, matching: find.text('دَرّ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(info.dar.name.ar)),
        findsOneWidget,
      );
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      // المقبض = ما يعرضه المركز: موسم الجو المسمّى أو الموسم الكبير.
      await tapDial(tester, dialPoint(tester, 0, 0));
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(
            info.weatherSeason == null ? 'موسم' : 'موسم جو',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('دَرّ مستعار: الورقة بجدول المُعيرة', (tester) async {
      phone(tester);
      await openHome(tester);
      await tapDial(tester, dialPoint(tester, 0.655, 0));
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
    final at = dialPoint(tester, 0.655, 0);
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
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.borrowNote));
      final note = tables.regionTables['najd']!.dururBorrow!.note.ar;
      expect(find.text(note), findsOneWidget);
      final strip = find.byKey(HomeCardKeys.darStrip);
      expect(
        find.descendant(
          of: strip,
          matching: find.text('حسب حساب الإمارات وعُمان'),
        ),
        findsOneWidget,
      );
      // الطالع والموسم قبل الدَّرّ المستعار.
      final starY = tester.getTopLeft(find.byKey(HomeCardKeys.starCard)).dy;
      expect(starY, lessThan(tester.getTopLeft(strip).dy));
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

      // بطاقة الطالع (قبل شريط الدَّرّ): موسم الجو باسمه.
      expect(
        find.descendant(
          of: find.byKey(HomeCardKeys.starCard),
          matching: find.text('موسم الجو: الوسم'),
        ),
        findsOneWidget,
      );
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.borrowNote));
      expect(
        tester.getTopLeft(find.byKey(HomeCardKeys.starCard)).dy,
        lessThan(tester.getTopLeft(find.byKey(HomeCardKeys.darStrip)).dy),
      );
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
      expect(find.byKey(HomeCardKeys.borrowNote), findsNothing);
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.darStrip));
      expect(find.textContaining('حسب حساب'), findsNothing);
    });
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
    expect(
      findDatesLine('السبت ٣ أكتوبر ٢٠٢٦م\u00a0— ٢٢ ربيع الآخر ١٤٤٨هـ'),
      findsOneWidget,
    );
  });

  group('R2.8: العدّاد والبطاقات', () {
    testWidgets('العدّاد بالأيام: «باقي ٩ أيام على دخول الوسم» وقارئ الشاشة', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final counter = find.byKey(HomeCardKeys.countdown);
      await scrollHomeTo(tester, counter);
      for (final text in [
        'باقي',
        '٩',
        'أيام',
        'على دخول الوسم',
        'الجمعة ١٦ أكتوبر',
      ]) {
        expect(
          find.descendant(of: counter, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        tester.getSemantics(counter).label,
        'باقي ٩ أيام على دخول الوسم، الجمعة ١٦ أكتوبر',
      );
      // الضغط يفتح صفحة العنصر: test/widgets/item_detail_test.dart.
      handle.dispose();
    });

    testWidgets('يوم البداية نفسه: «دخل الوسم اليوم»، وتاريخ آخر ← «من …»', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 16, 9));
      await scrollHomeTo(tester, find.byKey(HomeCardKeys.countdown));
      expect(find.text('دخل الوسم اليوم'), findsOneWidget);
      await tester.tap(find.byKey(HomeScreen.nextKey));
      await tester.pumpAndSettle();
      expect(find.text('من ١٧ أكتوبر ٢٠٢٦م'), findsOneWidget);
    });

    testWidgets('القادم: الدَّرّ التالي والموسم الكبير وأقرب موسم جو بالأيام', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final card = find.byKey(HomeCardKeys.upcomingCard);
      await scrollHomeTo(tester, card);
      for (final (i, name, after) in [
        (0, 'دَرّ السبعين', 'بعد ٣ أيام'),
        (1, 'الشتاء', 'بعد ٤٧ يوماً'),
        (2, 'المربعانية', 'بعد ٦١ يوماً'),
      ]) {
        final row = find.byKey(HomeCardKeys.upcomingRow(i));
        expect(find.descendant(of: row, matching: find.text(name)), findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text(after)),
          findsOneWidget,
        );
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      }
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

  group('الميزة 16: رموز الجو على الدائرة', () {
    DayDialState dialState(WidgetTester tester) =>
        tester.state<DayDialState>(find.byType(DayDial));

    testWidgets('الرموز ظاهرة بلا تكبير، والضغط يفتح فقاعة واحدة بالاسم والشرح '
        'والفترة، وتُغلق بالضغط خارجها', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final marks = dialState(tester).visibleMarks;
      // 4 مواسم جو + 4 مقاطع درور (نجد، R2.6).
      expect(marks.length, greaterThanOrEqualTo(8));
      final screen = tester.getRect(find.byType(HomeScreen));
      final visible = marks
          .where((m) => screen.deflate(30).contains(m.center))
          .toList();
      expect(visible, isNotEmpty);
      final mark = visible.first;

      // منطقة اللمس 48: الضغط على بعد 20 نقطة من المركز يكفي.
      await tapDial(tester, mark.center + const Offset(14, 14));
      final bubble = find.byKey(SymbolBubbleContent.contentKey);
      expect(bubble, findsOneWidget);
      final name = AppLocalizations.of(
        tester.element(bubble),
      ).weatherSymbolName(mark.symbol.code);
      expect(find.descendant(of: bubble, matching: find.text(name)), findsOneWidget);
      expect(
        find.descendant(of: bubble, matching: find.textContaining('يتبع: ')),
        findsOneWidget,
      );
      expect(tester.getSemantics(bubble).label, startsWith('$name. '));
      // داخل الشاشة دائماً.
      final rect = tester.getRect(bubble);
      expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight), isTrue);
      // لا تفتح صفحة ولا ورقة.
      expect(find.byKey(ItemDetailSheet.sheetKey), findsNothing);

      // ضغطة خارجها تغلقها.
      await tester.tapAt(screen.bottomLeft + const Offset(10, -10));
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);
      expect(selected(tester), DateTime(2026, 10, 7));
      handle.dispose();
    });

    testWidgets('السحب على الدائرة والفقاعة مفتوحة يغلقها', (tester) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final screen = tester.getRect(find.byType(HomeScreen));
      final mark = dialState(tester).visibleMarks.firstWhere(
        (m) => screen.deflate(30).contains(m.center),
      );
      await tapDial(tester, mark.center);
      final bubble = find.byKey(SymbolBubbleContent.contentKey);
      expect(bubble, findsOneWidget);
      // سحب دائري على حلقة الدرور في الجهة المقابلة للفقاعة: أول لمس يغلقها.
      final upper =
          mark.center.dy < tester.getCenter(find.byKey(DayDial.dialKey)).dy;
      final base = upper ? 180.0 : 0.0;
      expect(
        tester.getRect(bubble).contains(dialPoint(tester, 0.655, base)),
        isFalse,
      );
      final g = await tester.startGesture(dialPoint(tester, 0.655, base));
      await tester.pump();
      for (var deg = base - 4; deg >= base - 16; deg -= 4) {
        await g.moveTo(dialPoint(tester, 0.655, deg));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);
      // ولا تُفتح فقاعة أو ورقة بعد السحب.
      expect(find.byKey(ItemDetailSheet.sheetKey), findsNothing);
      // والدائرة تدور بعد الإغلاق.
      final g2 = await tester.startGesture(dialPoint(tester, 0.655, 90));
      await tester.pump();
      for (var deg = 86; deg >= 60; deg -= 2) {
        await g2.moveTo(dialPoint(tester, 0.655, deg.toDouble()));
        await tester.pump();
      }
      await g2.up();
      await tester.pumpAndSettle();
      expect(selected(tester).isAfter(DateTime(2026, 10, 7)), isTrue);
    });

    testWidgets('الضغط على رمز آخر والفقاعة مفتوحة يفتح فقاعته (واحدة فقط)', (
      tester,
    ) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final screen = tester.getRect(find.byType(HomeScreen));
      final marks = dialState(tester).visibleMarks
          .where((m) => screen.deflate(30).contains(m.center))
          .toList();
      expect(marks.length, greaterThanOrEqualTo(2));
      await tapDial(tester, marks[0].center);
      await tester.tapAt(marks[1].center);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final bubble = find.byKey(SymbolBubbleContent.contentKey);
      expect(bubble, findsOneWidget);
      final name = AppLocalizations.of(
        tester.element(bubble),
      ).weatherSymbolName(marks[1].symbol.code);
      expect(find.descendant(of: bubble, matching: find.text(name)), findsOneWidget);
    });

    testWidgets('الرمز له الأولوية على حلقة الأشهر تحته', (tester) async {
      phone(tester);
      await openHome(tester, now: DateTime(2026, 10, 7, 9));
      final dialCenter = tester.getCenter(find.byKey(DayDial.dialKey));
      final mark = dialState(tester).visibleMarks.firstWhere(
        (m) => m.center.dy < dialCenter.dy - 100,
      );
      // 15 نقطة نحو المركز: داخل حلقة الأشهر وضمن منطقة لمس الرمز.
      final inward = mark.center + (dialCenter - mark.center) / (dialCenter - mark.center).distance * 15;
      await tapDial(tester, inward);
      expect(find.byKey(SymbolBubbleContent.contentKey), findsOneWidget);
      expect(selected(tester), DateTime(2026, 10, 7));
    });

    testWidgets('شريحة الجو في البطاقة تفتح فقاعة الرمز', (tester) async {
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
