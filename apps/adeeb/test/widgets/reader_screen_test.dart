import 'dart:async';

import 'package:adeeb/library/library_screen.dart';
import 'package:adeeb/reader/reader_book.dart';
import 'package:adeeb/reader/reader_providers.dart';
import 'package:adeeb/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

const firstMini = 'هذه فقرة اختبار اصطناعية أولى، وليست من أي كتاب.';

Finder bigParagraph(int chapter, int paragraph) =>
    find.textContaining('رقم $paragraph من الباب $chapter،');

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv();
    env.server.catalog = catalogJson([
      env.server.addBook(miniBook()),
      env.server.addBook(syntheticBook()),
    ]);
  });
  tearDown(() => env.dispose());

  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
  }) async {
    await tester.pumpWidget(env.app(locale: locale));
    await tester.pumpAndSettle();
  }

  /// يفتح القارئ من زر «افتح» في بطاقة الكتاب (كتاب محمّل واحد في كل اختبار).
  Future<void> openReader(WidgetTester tester, String title) async {
    await scrollLibraryTo(tester, find.widgetWithText(FilledButton, 'افتح'));
    expect(find.text(title), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'افتح'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(
      GoRouter.of(tester.element(find.byType(LibraryScreen))).push(location),
    );
    await tester.pumpAndSettle();
  }

  Text textOf(WidgetTester tester, Finder finder) =>
      tester.widget<Text>(finder);

  testWidgets(
    'القارئ: نص أميري RTL بالحجم الافتراضي، وعنوان الباب، وتقدّم بأرقام مشرقية',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await openReader(tester, 'كتاب اختبار اصطناعي');

      expect(find.byType(ReaderScreen), findsOneWidget);
      final text = textOf(tester, find.text(firstMini));
      expect(text.textDirection, TextDirection.rtl);
      expect(text.style!.fontFamily, 'Amiri');
      expect(text.style!.fontSize, 22);
      expect(text.style!.height, 2.0);
      // لا تباعد بين الحروف ولا مائل: لا تتقطع الحروف ولا تنفصل الحركات.
      expect(text.style!.letterSpacing, isNull);
      expect(text.style!.fontStyle, isNot(FontStyle.italic));
      // الفقرة نص واحد كامل بتشكيلها.
      expect(
        find.text('فقرة اختبار ثانية فيها تشكيل تجريبي: الحِكْمَةُ والأَسَدُ.'),
        findsOneWidget,
      );
      // الشعر: الشطران منفصلان.
      expect(find.text('شطر اختبار أول'), findsOneWidget);
      expect(find.text('شطر رابع'), findsOneWidget);

      expect(
        tester.getSemantics(find.text('الباب الأول: فقرات اختبار')),
        isSemantics(isHeader: true),
      );
      expect(
        find.text('كتاب اختبار اصطناعي ‹ الباب الأول: فقرات اختبار'),
        findsOneWidget,
      );
      expect(find.text('الباب ١ من ٢ · ٣٣٪'), findsOneWidget);
      // بداية السطر يمين: النص ملاصق للحافة اليمنى (هامش 20).
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getRect(find.text(firstMini)).right,
        closeTo(width - 20, 1),
      );
    },
  );

  testWidgets('الإنجليزية: الواجهة LTR بأرقام غربية ونص الكتاب يبقى RTL', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1 of 2 · 33%'), findsOneWidget);
    expect(
      textOf(tester, find.text(firstMini)).textDirection,
      TextDirection.rtl,
    );
    expect(find.byTooltip('Contents'), findsOneWidget);
    expect(find.byTooltip('Display settings'), findsOneWidget);
  });

  testWidgets('حجم الخط: ستة مستويات تُطبَّق فوراً وتُحفظ بعد إعادة التشغيل', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    await tester.tap(find.byTooltip('إعدادات العرض'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('المستوى ٣ من ٦'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('تكبير الخط'));
    await tester.pumpAndSettle();
    expect(textOf(tester, find.text(firstMini)).style!.fontSize, 25);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.bySemanticsLabel('تكبير الخط'));
      await tester.pumpAndSettle();
    }
    expect(textOf(tester, find.text(firstMini)).style!.fontSize, 32);
    expect(find.bySemanticsLabel('المستوى ٦ من ٦'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'أ+'))
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.bySemanticsLabel('تصغير الخط'));
      await tester.pumpAndSettle();
    }
    expect(textOf(tester, find.text(firstMini)).style!.fontSize, 20);
    expect(
      (await SharedPreferences.getInstance()).getInt('reader.font_level'),
      2,
    );

    // إعادة تشغيل التطبيق.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    expect(textOf(tester, find.text(firstMini)).style!.fontSize, 20);
  });

  testWidgets('لون الصفحة: «ورق» يغيّر خلفية القارئ ويُحفظ، والمختار عليه ✓', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    Color background() =>
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor!;
    expect(background(), const Color(0xFFFBF8F1));

    await tester.tap(find.byTooltip('إعدادات العرض'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('فاتح')),
      isSemantics(isSelected: true),
    );
    await tester.tap(find.text('ورق'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('ورق')),
      isSemantics(isSelected: true),
    );
    expect(
      textOf(tester, find.text(firstMini)).style!.color,
      const Color(0xFF3B2F20),
    );
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, find.text(firstMini)).style!.color,
      const Color(0xFFEDE6D8),
    );
    await tester.tap(find.text('ورق'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('ورق'))).pop();
    await tester.pumpAndSettle();
    expect(background(), const Color(0xFFF3E9D2));

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    expect(background(), const Color(0xFFF3E9D2));
  });

  testWidgets('الفهرس يفتح أي باب بنقرة ويعلّم الباب الحالي', (tester) async {
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اصطناعي طويل');
    expect(bigParagraph(3, 1), findsNothing);

    await tester.tap(find.byTooltip('الفهرس'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('الباب ١ من ٣: باب اختبار رقم 1، أنت هنا'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('الباب ٣ من ٣: باب اختبار رقم 3'));
    await tester.pumpAndSettle();

    expect(bigParagraph(3, 1), findsOneWidget);
    expect(find.text('كتاب اصطناعي طويل ‹ باب اختبار رقم 3'), findsOneWidget);
    expect(find.text('الباب ٣ من ٣ · ٦٨٪'), findsOneWidget);
    // عنوان الباب أسفل الشريط العلوي مباشرة.
    final heading = tester.getRect(find.text('باب اختبار رقم 3').first);
    expect(heading.top, inInclusiveRange(kToolbarHeight, kToolbarHeight + 40));
    // التمرير للخلف يعرض نهاية الباب السابق.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(bigParagraph(2, 20), findsOneWidget);
  });

  testWidgets('حفظ آخر موضع واستعادته بعد إغلاق التطبيق، و«من البداية»', (
    tester,
  ) async {
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اصطناعي طويل');
    await tester.tap(find.byTooltip('الفهرس'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('الباب ٢ من ٣: باب اختبار رقم 2'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final saved = (await env.reading.position('big'))!;
    expect(saved.chapterNumber, 2);
    expect(saved.paragraphNumber, greaterThan(21));
    final number = int.parse(
      saved.paragraphId.substring(saved.paragraphId.length - 5),
    );

    // إغلاق التطبيق كاملاً ثم فتحه.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اصطناعي طويل');
    expect(find.text('تابعت من حيث توقفت'), findsOneWidget);
    // الفقرة المحفوظة (±١) أعلى منطقة القراءة.
    final top = tester.getRect(bigParagraph(2, number)).top;
    expect(top, inInclusiveRange(kToolbarHeight - 200, kToolbarHeight + 40));
    expect(find.text('كتاب اصطناعي طويل ‹ باب اختبار رقم 2'), findsOneWidget);

    await tester.tap(find.text('من البداية'));
    await tester.pumpAndSettle();
    expect(bigParagraph(1, 1), findsOneWidget);
    expect((await env.reading.position('big'))!.paragraphId, 'big-b001-p00001');
  });

  testWidgets(
    'المفضلة: إضافة بالضغط المطوّل، وتبويب المفضلة ينقل إليها، ثم إزالة وتراجع',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await tester.tap(find.text('المفضلة'));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد فقرات في المفضلة بعد.'), findsOneWidget);
      await tester.tap(find.text('الكتب'));
      await tester.pumpAndSettle();

      await openReader(tester, 'كتاب اختبار اصطناعي');
      await tester.longPress(find.textContaining('شطر اختبار أول'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أضف إلى المفضلة'));
      await tester.pumpAndSettle();
      expect(find.text('أُضيفت إلى المفضلة'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('شطر اختبار أول')),
        isSemantics(value: 'في المفضلة'),
      );

      await back(tester);
      await tester.tap(find.text('المفضلة'));
      await tester.pumpAndSettle();
      expect(
        find.text('كتاب اختبار اصطناعي ‹ فصل اختبار فرعي'),
        findsOneWidget,
      );
      expect(find.textContaining('شطر اختبار أول'), findsOneWidget);

      // النقر يفتح الفقرة في القارئ مظلّلة.
      await tester.tap(find.textContaining('شطر اختبار أول'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReaderScreen), findsOneWidget);
      BoxDecoration decorationOf(String text) =>
          tester
                  .widget<AnimatedContainer>(
                    find
                        .ancestor(
                          of: find.text(text),
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decorationOf('شطر اختبار أول').color, const Color(0xFFE6F0EC));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(decorationOf('شطر اختبار أول').color!.a, 0);
      await back(tester);

      await tester.tap(find.text('إزالة'));
      await tester.pumpAndSettle();
      expect(find.text('أُزيلت من المفضلة'), findsOneWidget);
      expect(find.text('لا توجد فقرات في المفضلة بعد.'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(find.textContaining('شطر اختبار أول'), findsOneWidget);

      // السحب يزيل أيضاً.
      await tester.drag(
        find.textContaining('شطر اختبار أول'),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا توجد فقرات في المفضلة بعد.'), findsOneWidget);
      expect(await env.reading.favorites(), isEmpty);
    },
  );

  testWidgets(
    'قارئ الشاشة: كل فقرة عنصر، والمفضلة إجراء مخصص، والأشرطة ثابتة',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final handle = tester.ensureSemantics();
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await openReader(tester, 'كتاب اختبار اصطناعي');

      const add = CustomSemanticsAction(label: 'أضف إلى المفضلة');
      final node = tester.getSemantics(find.text(firstMini));
      const copy = CustomSemanticsAction(label: 'نسخ');
      const listen = CustomSemanticsAction(label: 'استمع من هنا');
      expect(
        node,
        isSemantics(label: firstMini, customActions: [add, copy, listen]),
      );
      tester.semantics.customAction(find.semantics.byLabel(firstMini), add);
      await tester.pumpAndSettle();
      expect(
        (await env.reading.favorites()).single.paragraphId,
        'mini-b001-p00001',
      );
      final after = tester.getSemantics(find.text(firstMini));
      expect(after, isSemantics(value: 'في المفضلة'));
      expect(
        after
            .getSemanticsData()
            .customSemanticsActionIds!
            .map((id) => CustomSemanticsAction.getAction(id)!.label)
            .toSet(),
        {'أزل من المفضلة', 'نسخ', 'استمع من هنا'},
      );

      // النقر لا يخفي الأشرطة مع قارئ الشاشة.
      await tester.tap(find.text(firstMini));
      await tester.pump(const Duration(seconds: 4));
      expect(find.byTooltip('الفهرس'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('بلا قارئ شاشة: النقر يُخفي الأشرطة ويُظهرها', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    await tester.tap(find.text(firstMini));
    await tester.pumpAndSettle();
    expect(find.byTooltip('الفهرس'), findsNothing);
    await tester.tap(find.text(firstMini));
    await tester.pumpAndSettle();
    expect(find.byTooltip('الفهرس'), findsOneWidget);
  });

  testWidgets('أهداف اللمس 48dp على الأقل في القارئ وورقة العرض', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    for (final icon in [Icons.toc, Icons.text_fields]) {
      final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$icon');
    }
    expect(
      tester.getSize(find.byType(BackButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byTooltip('إعدادات العرض'));
    await tester.pumpAndSettle();
    for (final label in ['أ+', 'أ−']) {
      final size = tester.getSize(find.widgetWithText(OutlinedButton, label));
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: label);
    }
    for (final label in ['فاتح', 'ورق', 'داكن']) {
      final size = tester.getSize(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      );
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: label);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('تكبير الخط 200%: الحجم يتضاعف بحد 64 بلا فيض', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await scrollLibraryTo(tester, find.widgetWithText(FilledButton, 'افتح'));
    await tester.tap(find.widgetWithText(FilledButton, 'افتح'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, find.text(firstMini)).style!.fontSize, 44);
    await tester.tap(find.byTooltip('إعدادات العرض'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('تكبير الخط'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    // الفقرة الأولى صارت أسفل الشاشة (في ذاكرة التمرير) لكبر الخط.
    expect(
      textOf(tester, find.text(firstMini, skipOffstage: false)).style!.fontSize,
      64,
    );
    // عنوان الباب (×١٫٣) لا يتجاوز الحد ٦٤ أيضاً.
    expect(
      textOf(
        tester,
        find.text('الباب الأول: فقرات اختبار', skipOffstage: false).first,
      ).style!.fontSize,
      64,
    );
    Navigator.of(tester.element(find.text('ورق'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('الفهرس'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'الفتح إلى فقرة بمعرّفها، وبمعرّف قديم عبر redirects، وبمعرّف مفقود',
    (tester) async {
      await env.preinstall(syntheticBook());
      await pumpApp(tester);
      await push(tester, '/read/big?p=big-b003-p00010');
      expect(bigParagraph(3, 10), findsOneWidget);
      expect(
        tester.getRect(bigParagraph(3, 10)).top,
        inInclusiveRange(kToolbarHeight, kToolbarHeight + 40),
      );
      await back(tester);

      await push(tester, '/read/big?p=big-b002-p00099');
      expect(
        find.text('لم نجد الفقرة نفسها، فتحنا الباب الذي كانت فيه'),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text('باب اختبار رقم 2').first).top,
        inInclusiveRange(kToolbarHeight, kToolbarHeight + 40),
      );
    },
  );

  testWidgets('معرّف قديم بعد التحديث يفتح الفقرة الجديدة', (tester) async {
    final v2 = miniBook(version: 2);
    final paragraphs =
        ((v2['chapters']! as List<Object?>).first!
                as Map<String, Object?>)['paragraphs']!
            as List<Object?>;
    (paragraphs.first! as Map<String, Object?>)['id'] = 'mini-b001-p00005';
    v2['redirects'] = {'mini-b001-p00001': 'mini-b001-p00005'};
    await env.preinstall(v2);
    await pumpApp(tester);
    await push(tester, '/read/mini?p=mini-b001-p00001');
    expect(
      find.text('لم نجد الفقرة نفسها، فتحنا الباب الذي كانت فيه'),
      findsNothing,
    );
    expect(
      (await env.reading.position('mini'))!.paragraphId,
      'mini-b001-p00005',
    );
  });

  testWidgets('كتاب غير محمّل: رسالة وزر «تحميل» ثم يُفتح النص', (
    tester,
  ) async {
    await pumpApp(tester);
    await push(tester, '/read/mini');
    expect(find.text('هذا الكتاب غير محمّل على جهازك.'), findsOneWidget);
    await tester.tap(find.text('تحميل (١ ك.ب)'));
    await tester.pumpAndSettle();
    expect(find.text(firstMini), findsOneWidget);
  });

  testWidgets('بطاقة «تابع القراءة» وزر صفحة الكتاب و«أنت هنا»', (
    tester,
  ) async {
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    expect(find.widgetWithText(FilledButton, 'تابع القراءة'), findsNothing);

    // صفحة الكتاب قبل القراءة: «ابدأ القراءة».
    await tester.tap(find.text('مولّد الاختبار (ت ٢٠٠هـ)'));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ القراءة'), findsOneWidget);
    // الضغط على باب يفتح القارئ عليه.
    await tester.tap(find.bySemanticsLabel('الباب ٢ من ٣: باب اختبار رقم 2'));
    await tester.pumpAndSettle();
    expect(find.text('كتاب اصطناعي طويل ‹ باب اختبار رقم 2'), findsOneWidget);
    await back(tester);
    expect(find.text('تابع القراءة'), findsOneWidget);
    expect(find.text('وصلت إلى: باب اختبار رقم 2 — ٣٥٪'), findsOneWidget);
    expect(
      find.bySemanticsLabel('الباب ٢ من ٣: باب اختبار رقم 2، أنت هنا'),
      findsOneWidget,
    );

    await back(tester);
    expect(find.text('كتاب اصطناعي طويل ‹ باب اختبار رقم 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'تابع القراءة'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(bigParagraph(2, 1), findsOneWidget);
  });

  testWidgets('تحديث الكتاب من المكتبة يُبقي المفضلة وآخر موضع عبر redirects', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await env.reading.addFavorite('mini', 'mini-b001-p00002');
    await env.reading.savePosition('mini', 'mini-b001-p00002');
    final v2 = miniBook(version: 2);
    final paragraphs =
        ((v2['chapters']! as List<Object?>).first!
                as Map<String, Object?>)['paragraphs']!
            as List<Object?>;
    (paragraphs[1]! as Map<String, Object?>)['id'] = 'mini-b001-p00003';
    v2['redirects'] = {'mini-b001-p00002': 'mini-b001-p00003'};
    env.server.catalog = catalogJson([env.server.addBook(v2)]);
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'تحديث'));
    await tester.pumpAndSettle();
    expect(find.text('حُدّث الكتاب'), findsOneWidget);

    expect(
      (await env.reading.favorites()).single.paragraphId,
      'mini-b001-p00003',
    );
    expect(
      (await env.reading.position('mini'))!.paragraphId,
      'mini-b001-p00003',
    );
    expect(find.widgetWithText(FilledButton, 'تابع القراءة'), findsOneWidget);
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الحِكْمَةُ'), findsOneWidget);
  });

  testWidgets('المفضلة لكتاب محذوف: «الكتاب غير محمّل» وزر «تحميل»', (
    tester,
  ) async {
    await env.reading.addFavorite('mini', 'mini-b001-p00001');
    await pumpApp(tester);
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();
    expect(find.text('الكتاب غير محمّل'), findsOneWidget);
    expect(find.text('كتاب اختبار اصطناعي'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'تحميل'));
    await tester.pumpAndSettle();
    expect(find.text(firstMini), findsOneWidget);
  });

  /// يلتقط ما يُنسخ إلى الحافظة.
  String? Function() mockClipboard(WidgetTester tester) {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return () => clipboard;
  }

  testWidgets('نسخ الفقرة ومشاركتها مع الكتاب والمؤلف والباب', (tester) async {
    final clipboard = mockClipboard(tester);
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');

    await tester.longPress(find.text(firstMini));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسخ'));
    await tester.pumpAndSettle();
    expect(find.text('نُسخ النص'), findsOneWidget);
    expect(
      clipboard(),
      '$firstMini\n— كتاب اختبار اصطناعي، بيانات اختبار، الباب الأول: فقرات اختبار',
    );

    // الشعر: الشطران بمسافات لا بعلامة جدولة.
    await tester.longPress(find.text('شطر اختبار أول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشاركة'));
    await tester.pumpAndSettle();
    expect(env.shared, [
      (
        'شطر اختبار أول    شطر اختبار ثانٍ\nشطر ثالث    شطر رابع\n'
            '— كتاب اختبار اصطناعي، بيانات اختبار، فصل اختبار فرعي',
        'كتاب اختبار اصطناعي',
      ),
    ]);
  });

  testWidgets('النسخ إجراء مخصص لقارئ الشاشة، وبالإنجليزية تبقى الأسماء عربية', (
    tester,
  ) async {
    final clipboard = mockClipboard(tester);
    final handle = tester.ensureSemantics();
    await env.preinstall(miniBook());
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await tester.pumpAndSettle();
    tester.semantics.customAction(
      find.semantics.byLabel(firstMini),
      const CustomSemanticsAction(label: 'Copy'),
    );
    await tester.pumpAndSettle();
    expect(
      clipboard(),
      '$firstMini\n— كتاب اختبار اصطناعي, بيانات اختبار, الباب الأول: فقرات اختبار',
    );
    expect(find.text('Text copied'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'فشل حفظ المفضلة في القارئ: رسالة «تعذّر الحفظ» ولا تتغير الحالة',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await openReader(tester, 'كتاب اختبار اصطناعي');
      env.failFavoriteWrites = true;
      await tester.longPress(find.text(firstMini));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أضف إلى المفضلة'));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر الحفظ، حاول مجدداً'), findsOneWidget);
      expect(find.text('أُضيفت إلى المفضلة'), findsNothing);
      expect(await env.reading.favorites(), isEmpty);
    },
  );

  testWidgets('«تراجع» بعد الإزالة في القارئ يعيد الفقرة بتاريخها الأصلي', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await env.reading.addFavorite('mini', 'mini-b001-p00001', createdAt: 1000);
    await env.reading.addFavorite('mini', 'mini-b002-p00001', createdAt: 2000);
    await pumpApp(tester);
    await openReader(tester, 'كتاب اختبار اصطناعي');
    await tester.longPress(find.text(firstMini));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أزل من المفضلة'));
    await tester.pumpAndSettle();
    expect(find.text('أُزيلت من المفضلة'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    final favorites = await env.reading.favorites();
    expect(favorites.map((f) => (f.paragraphId, f.createdAt)), [
      ('mini-b002-p00001', 2000),
      ('mini-b001-p00001', 1000),
    ]);
  });

  testWidgets('فشل الإزالة من تبويب المفضلة يعيد العنصر مع رسالة خطأ', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await env.reading.addFavorite('mini', 'mini-b001-p00001');
    await pumpApp(tester);
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();
    env.failFavoriteWrites = true;

    await tester.tap(find.text('إزالة'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الحفظ، حاول مجدداً'), findsOneWidget);
    expect(find.text(firstMini), findsOneWidget);

    // السحب أيضاً: يعود العنصر.
    await tester.drag(find.text(firstMini), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الحفظ، حاول مجدداً'), findsOneWidget);
    expect(find.text(firstMini), findsOneWidget);
    expect(await env.reading.favorites(), hasLength(1));
  });

  testWidgets('فقرة مفضلة لم تعد في كتاب محمّل: وصفها الصحيح', (tester) async {
    await env.preinstall(miniBook());
    await env.reading.addFavorite('mini', 'mini-b001-p00099');
    await pumpApp(tester);
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();
    expect(find.text('لم تعد هذه الفقرة موجودة في الكتاب'), findsOneWidget);
    expect(find.text('الكتاب غير محمّل'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'تحميل'), findsNothing);
  });

  testWidgets('فشل حفظ الموضع يُعاد عند إخفاء التطبيق', (tester) async {
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    env.failPositionWrites = true;
    await push(tester, '/read/big?p=big-b002-p00003');
    expect(await env.reading.position('big'), isNull);

    env.failPositionWrites = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect((await env.reading.position('big'))!.paragraphId, 'big-b002-p00003');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('تثبيت كتاب آخر لا يعيد تحميل الكتاب المفتوح', () async {
    await env.preinstall(miniBook());
    final container = env.container();
    addTearDown(container.dispose);
    final sub = container.listen(readerBookProvider('mini'), (_, _) {});
    addTearDown(sub.close);
    final first = await container.read(readerBookProvider('mini').future);
    container.read(installRevisionProvider.notifier).bump('big');
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(readerBookProvider('mini')),
      isA<AsyncData<ReaderBook?>>(),
    );
    expect(container.read(readerBookProvider('mini')).value, same(first));

    container.read(installRevisionProvider.notifier).bump('mini');
    final second = await container.read(readerBookProvider('mini').future);
    expect(second, isNot(same(first)));
  });
}
