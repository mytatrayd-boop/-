import 'dart:async';

import 'package:adeeb/library/book_page.dart';
import 'package:adeeb/library/library_screen.dart';
import 'package:adeeb/reader/reader_screen.dart';
import 'package:adeeb/search/search_screen.dart';
import 'package:adeeb/storage/search_repository.dart';
import 'package:adeeb/text/search_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

/// مستودع بحث يفشل دائماً (محاكاة قاعدة تالفة).
class FailingSearch implements SearchRepository {
  int calls = 0;

  @override
  Future<SearchPage> search(
    SearchQuery query, {
    String? bookId,
    int offset = 0,
    int limit = 50,
  }) async {
    calls++;
    throw StateError('محاكاة فشل البحث');
  }
}

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

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(
      GoRouter.of(tester.element(find.byType(LibraryScreen))).push(location),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byTooltip('البحث'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
  }

  /// نصوص المقاطع المظلّلة (خلفية + خط سفلي) داخل [scope].
  List<String> highlighted(WidgetTester tester, Finder scope) {
    final out = <String>[];
    for (final rt in tester.widgetList<RichText>(
      find.descendant(of: scope, matching: find.byType(RichText)),
    )) {
      rt.text.visitChildren((span) {
        final style = span.style;
        if (span is TextSpan &&
            style?.backgroundColor != null &&
            style?.decoration == TextDecoration.underline) {
          out.add(span.text!);
        }
        return true;
      });
    }
    return out;
  }

  testWidgets(
    'من المكتبة: اقتراحات، ثم «الحكمه» بعد 300ms تجد «الحِكْمَةُ» مظلّلة بتشكيلها',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await openSearch(tester);

      // قبل الكتابة: سطر المساعدة والاقتراحات وشريحة «كل الكتب» مختارة.
      expect(find.text('البحث يتجاهل التشكيل واختلاف الهمزات'), findsOneWidget);
      expect(find.text('اقتراحات'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'الأسد'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'كل الكتب المحمّلة'),
            )
            .selected,
        isTrue,
      );
      // لوحة المفاتيح تُفتح تلقائياً عند الدخول من المكتبة.
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isTrue,
      );

      await tester.enterText(find.byType(TextField), 'ح');
      await tester.pump();
      expect(find.text('اكتب حرفين على الأقل'), findsOneWidget);

      // التأخير: لا بحث قبل 300ms من التوقف عن الكتابة.
      await tester.enterText(find.byType(TextField), 'الحكمه');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('نتيجة واحدة في كتاب واحد'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('نتيجة واحدة في كتاب واحد'), findsOneWidget);
      expect(find.text('الباب الأول: فقرات اختبار'), findsOneWidget);
      expect(highlighted(tester, find.byType(Card)), ['الحِكْمَةُ']);

      // زر المسح يعيد الاقتراحات.
      await tester.tap(find.byTooltip('مسح'));
      await tester.pumpAndSettle();
      expect(find.text('اقتراحات'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    },
  );

  testWidgets('اقتراح بالنقر يبحث فوراً، و«اسد» يجد «الأَسَدُ»', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openSearch(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'الأسد'));
    await tester.pumpAndSettle();
    expect(highlighted(tester, find.byType(Card)), ['والأَسَدُ']);
    await type(tester, 'اسد');
    expect(highlighted(tester, find.byType(Card)), ['والأَسَدُ']);
  });

  testWidgets(
    'النقر على نتيجة يفتح القارئ على الفقرة مع تظليل الكلمة، والرجوع يعيد النتائج',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await openSearch(tester);
      await type(tester, 'الحكمه');
      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(highlighted(tester, find.byType(ReaderScreen)), ['الحِكْمَةُ']);
      // التظليل يبقى بعد انتهاء وميض الفقرة.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(highlighted(tester, find.byType(ReaderScreen)), ['الحِكْمَةُ']);

      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.text('نتيجة واحدة في كتاب واحد'), findsOneWidget);
    },
  );

  testWidgets('كل الكتب: العدد حسب الكتاب، و«عرض المزيد» بعد 50', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await env.preinstall(miniBook());
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await openSearch(tester);
    await type(tester, 'اختبار');
    // 3 في الكتاب الصغير و60 في الاصطناعي.
    expect(find.text('٦٣ نتيجة في كتابين'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'كتاب اختبار اصطناعي، ٣ نتائج',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('كتاب اصطناعي طويل، ٦٠ نتيجة', skipOffstage: false),
      findsOneWidget,
    );
    semantics.dispose();

    // «عرض المزيد» يجلب الباقي ثم يختفي.
    await tester.scrollUntilVisible(
      find.text('عرض المزيد'),
      600,
      scrollable: find
          .descendant(
            of: find.byType(SearchScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('عرض المزيد'));
    await tester.pumpAndSettle();
    expect(find.text('عرض المزيد', skipOffstage: false), findsNothing);
  });

  testWidgets('رأس مجموعة الكتاب يطوي نتائجه ويوسّعها', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openSearch(tester);
    await type(tester, 'اختبار');
    final cards = find.descendant(
      of: find.byType(SearchScreen),
      matching: find.byType(Card, skipOffstage: false),
      skipOffstage: false,
    );
    expect(cards, findsNWidgets(3));
    final header = find.byKey(const ValueKey('search-group-mini'));
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(cards, findsNothing);
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(cards, findsNWidgets(3));
  });

  testWidgets(
    'من صفحة الكتاب: النطاق كتاب واحد، ولا نتائج تعرض «ابحث في كل الكتب»',
    (tester) async {
      await env.preinstall(miniBook());
      await env.preinstall(syntheticBook());
      await pumpApp(tester);
      await push(tester, '/book/mini');
      expect(find.byType(BookPage), findsOneWidget);
      await tester.tap(find.byTooltip('ابحث في هذا الكتاب'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'كتاب اختبار اصطناعي'),
            )
            .selected,
        isTrue,
      );
      // لا تُفتح لوحة المفاتيح تلقائياً عند الدخول من كتاب.
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isFalse,
      );

      await type(tester, 'اختبار');
      expect(find.text('٣ نتائج في كتاب واحد'), findsOneWidget);

      await type(tester, 'مكرر');
      expect(find.text('لا توجد نتائج لـ «مكرر»'), findsOneWidget);
      expect(
        find.text('جرّب كلمة أقصر أو مرادفاً، أو وسّع البحث إلى كل الكتب.'),
        findsOneWidget,
      );
      await tester.tap(find.text('ابحث في كل الكتب'));
      await tester.pumpAndSettle();
      expect(find.text('٦٠ نتيجة في كتاب واحد'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'كل الكتب المحمّلة'),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('من القارئ: «ابحث في هذا الكتاب» يفتح البحث بنطاق الكتاب', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, '/read/mini');
    await tester.tap(find.byTooltip('ابحث في هذا الكتاب'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'كتاب اختبار اصطناعي'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('لا كتب محمّلة: رسالة وزر «اذهب إلى المكتبة»', (tester) async {
    await pumpApp(tester);
    await openSearch(tester);
    expect(find.text('لا توجد كتب على جهازك للبحث فيها.'), findsOneWidget);
    await tester.tap(find.text('اذهب إلى المكتبة'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('خطأ في البحث: رسالة وزر «إعادة المحاولة»', (tester) async {
    final failing = FailingSearch();
    env.searchOverride = failing;
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openSearch(tester);
    await type(tester, 'الحكمه');
    expect(find.text('حدث خطأ أثناء البحث.'), findsOneWidget);
    expect(failing.calls, 1);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(failing.calls, 2);
    expect(find.text('حدث خطأ أثناء البحث.'), findsOneWidget);
  });

  testWidgets('قارئ الشاشة: البطاقة عنصر واحد بالكلمة المطابقة، والعدد يُعلَن', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await openSearch(tester);
    tester.takeAnnouncements();
    await type(tester, 'الحكمه');
    expect(tester.takeAnnouncements().map((a) => a.message), [
      'نتيجة واحدة في كتاب واحد',
    ]);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^الباب الأول: فقرات اختبار، كتاب اختبار اصطناعي\. .*الحِكْمَةُ.*\. '
          r'الكلمة المطابقة: الحِكْمَةُ$',
        ),
      ),
      findsOneWidget,
    );
    await type(tester, 'غائبة');
    expect(tester.takeAnnouncements().map((a) => a.message), [
      'لا توجد نتائج لـ «غائبة»',
    ]);
    semantics.dispose();
  });

  testWidgets('أهداف اللمس 48dp في شاشة البحث', (tester) async {
    await env.preinstall(miniBook());
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await openSearch(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await type(tester, 'الحكمه');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('تكبير الخط 200%: بلا فيض في الحقل والشرائح والنتائج', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await env.preinstall(miniBook());
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await openSearch(tester);
    expect(tester.takeException(), isNull);
    await type(tester, 'اختبار');
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(SearchScreen),
        matching: find.byType(Card, skipOffstage: false),
        skipOffstage: false,
      ),
      findsWidgets,
    );
  });

  testWidgets('الإنجليزية: نصوص مترجمة وأرقام غربية ونص الكتاب RTL', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('All downloaded books'), findsOneWidget);
    expect(
      find.text('Search ignores diacritics and hamza variations'),
      findsOneWidget,
    );
    await type(tester, 'اختبار');
    expect(find.text('3 results in 1 book'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.rtl);
    final snippet = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(Card).first,
            matching: find.byType(RichText),
          )
          .last,
    );
    expect(snippet.textDirection, TextDirection.rtl);
  });
}
