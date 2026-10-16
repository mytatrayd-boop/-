import 'dart:async';

import 'package:adeeb/library/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv();
    env.server.catalog = catalogJson([env.server.addBook(miniBook())]);
  });
  tearDown(() => env.dispose());

  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
  }) async {
    await tester.pumpWidget(env.app(locale: locale));
    await tester.pumpAndSettle();
  }

  TextDirection directionOf(WidgetTester tester, Finder finder) =>
      Directionality.of(tester.element(finder));

  testWidgets('العربية افتراضياً: الواجهة RTL، والبطاقة بأرقام مشرقية', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('المكتبة'), findsOneWidget);
    expect(directionOf(tester, find.text('المكتبة')), TextDirection.rtl);
    expect(find.text('كتاب اختبار اصطناعي'), findsWidgets);
    expect(find.text('بيانات اختبار (ت ١٠٠هـ)'), findsOneWidget);
    expect(find.text('١ ك.ب'), findsOneWidget);
    expect(find.text('غير محمّل'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'تحميل'), findsOneWidget);
    // بداية البطاقة (الغلاف) على اليمين في RTL.
    final card = tester.getRect(find.byType(BookCard));
    final title = tester.getRect(find.text('بيانات اختبار (ت ١٠٠هـ)'));
    expect(title.right, lessThan(card.right - 72));
    // قارئ الشاشة يقرأ البطاقة وحدة واحدة.
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^كتاب اختبار اصطناعي، بيانات اختبار، متوفى ١٠٠ للهجرة، ١ كيلوبايت، غير محمّل\$',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('الإنجليزية LTR، ونص الكتاب يبقى RTL مع نقل لاتيني', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));
    expect(find.text('Library'), findsOneWidget);
    expect(directionOf(tester, find.text('Library')), TextDirection.ltr);
    // فهرس schema 2 بلا أسماء لاتينية: النقل من ملف الكتاب بعد تحميله.
    expect(find.text('Synthetic Test Book — Test Data'), findsNothing);
    expect(find.text('بيانات اختبار (d. 100 AH)'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Download'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Test Book — Test Data'), findsOneWidget);
    final titleText = tester.widget<Text>(
      find.text('كتاب اختبار اصطناعي').last,
    );
    expect(titleText.textDirection, TextDirection.rtl);
  });

  testWidgets('هيكل مؤقت أثناء جلب الفهرس', (tester) async {
    await tester.pumpWidget(env.app());
    expect(find.bySemanticsLabel('جارٍ التحميل'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('جارٍ التحميل'), findsNothing);
  });

  testWidgets('أول تشغيل دون إنترنت: رسالة واضحة وإعادة المحاولة تعمل', (
    tester,
  ) async {
    env.server.offline = true;
    await pumpApp(tester);
    expect(find.text('تحتاج اتصالاً لتحميل الكتب'), findsOneWidget);
    expect(
      find.text(
        'اتصل بالإنترنت مرة واحدة لتحميل قائمة الكتب، وبعدها تقرأ وتبحث وتستمع دون اتصال.',
      ),
      findsOneWidget,
    );
    env.server.offline = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.byType(BookCard), findsOneWidget);
  });

  testWidgets('فشل جلب الفهرس بلا نسخة محفوظة', (tester) async {
    env.server.catalogStatus = 500;
    await pumpApp(tester);
    expect(
      find.text('تعذّر تحميل قائمة الكتب. تحقّق من الاتصال وحاول مجدداً.'),
      findsOneWidget,
    );
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('فهرس فارغ', (tester) async {
    env.server.catalog = catalogJson([]);
    await pumpApp(tester);
    expect(find.text('لا توجد كتب متاحة بعد.'), findsOneWidget);
  });

  testWidgets('تحميل كامل: تقدّم ثم «محمّل» و«افتح»', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('تحميل'));
    await tester.pumpAndSettle();
    expect(find.text('محمّل'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'افتح'), findsOneWidget);
  });

  testWidgets('شريط التقدّم ونسبته، و«إلغاء» يعيد «تحميل»', (tester) async {
    final stream = StreamController<List<int>>();
    env.server.bookStream = stream;
    await pumpApp(tester);
    await tester.tap(find.text('تحميل'));
    await tester.pump();
    final size = env.server.files.values.single.length;
    stream.add(List.filled(size ~/ 2, 0));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining(RegExp(r'^يُحمَّل… [٠-٩]+٪$')), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('تحميل'), findsOneWidget);
    unawaited(stream.close());
  });

  testWidgets('التقدّم يُعلَن عند ٢٥ و٥٠ و١٠٠٪ فقط، وليس في تسمية البطاقة', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final stream = StreamController<List<int>>();
    env.server.bookStream = stream;
    final gz = env.server.files.values.single;
    await pumpApp(tester);
    tester.takeAnnouncements();
    await tester.tap(find.text('تحميل'));
    await tester.pump();
    var sent = 0;
    for (final percent in [10, 20, 30, 60, 100]) {
      final upTo = gz.length * percent ~/ 100;
      stream.add(gz.sublist(sent, upTo));
      sent = upTo;
      await tester.pump();
      if (percent == 30) {
        expect(find.bySemanticsLabel(RegExp('٪')), findsNothing);
        expect(find.bySemanticsLabel(RegExp('يُحمَّل…\$')), findsOneWidget);
      }
    }
    unawaited(stream.close());
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements().map((a) => a.message), [
      '«كتاب اختبار اصطناعي»: يُحمَّل… ٢٥٪',
      '«كتاب اختبار اصطناعي»: يُحمَّل… ٥٠٪',
      '«كتاب اختبار اصطناعي»: يُحمَّل… ١٠٠٪',
    ]);
    expect(find.text('محمّل'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'فشل الخادم بلا فهرس محفوظ مع كتاب محمّل: لافتة خطأ والكتاب متاح',
    (tester) async {
      await env.preinstall(miniBook());
      env.server.catalogStatus = 500;
      await pumpApp(tester);
      expect(
        find.text('تعذّر تحميل قائمة الكتب. تحقّق من الاتصال وحاول مجدداً.'),
        findsOneWidget,
      );
      expect(find.text('محمّل'), findsOneWidget);
    },
  );

  testWidgets('انقطاع أثناء التحميل: رسالة و«إعادة المحاولة»', (tester) async {
    final stream = StreamController<List<int>>();
    env.server.bookStream = stream;
    await pumpApp(tester);
    await tester.tap(find.text('تحميل'));
    await tester.pump();
    stream.addError(http.ClientException('reset'));
    await tester.pumpAndSettle();
    expect(find.text('انقطع الاتصال أثناء التحميل'), findsOneWidget);
    unawaited(stream.close());
    env.server.bookStream = null;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('محمّل'), findsOneWidget);
  });

  testWidgets('ملف تالف: «الملف غير سليم» و«إعادة التحميل»', (tester) async {
    env.server.files.updateAll((k, v) => [...v]..[10] ^= 0xff);
    await pumpApp(tester);
    await tester.tap(find.text('تحميل'));
    await tester.pumpAndSettle();
    expect(find.text('الملف غير سليم. أعد تحميله.'), findsOneWidget);
    expect(find.text('إعادة التحميل'), findsOneWidget);
  });

  testWidgets('حذف كتاب محمّل بعد التأكيد', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await tester.longPress(find.byType(BookCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف من الجهاز'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الكتاب من الجهاز؟'), findsOneWidget);
    expect(
      find.textContaining('سيُحذف «كتاب اختبار اصطناعي» من جهازك'),
      findsOneWidget,
    );
    // «إلغاء» لا يحذف.
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('محمّل'), findsOneWidget);

    await tester.longPress(find.byType(BookCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف من الجهاز'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(find.text('حُذف الكتاب'), findsOneWidget);
    expect(find.text('تحميل'), findsOneWidget);
    expect(await env.books.installed(), isEmpty);
  });

  testWidgets('دون إنترنت مع كتاب محمّل: لافتة، والكتاب غير المحمّل معطّل', (
    tester,
  ) async {
    env.server.catalog = catalogJson([
      env.server.addBook(miniBook()),
      env.server.addBook(miniBook(id: 'other')),
    ]);
    await pumpApp(tester); // يحفظ نسخة من الفهرس
    await env.preinstall(miniBook());
    env.server.offline = true;
    // بعد 6 ساعات يُعاد الجلب تلقائياً عند فتح المكتبة فيظهر الانقطاع.
    env.now = env.now.add(const Duration(hours: 7));
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    expect(find.text('أنت دون إنترنت — الكتب المحمّلة متاحة'), findsOneWidget);
    expect(find.text('محمّل'), findsOneWidget);
    expect(find.text('يحتاج اتصالاً'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('تحميل'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('تحديث متاح: شارة وزر، ثم رسالة «حُدّث الكتاب»', (tester) async {
    await env.preinstall(miniBook());
    env.server.catalog = catalogJson([
      env.server.addBook(miniBook(version: 2)),
    ]);
    await pumpApp(tester);
    expect(find.text('تحديث متاح'), findsOneWidget);
    await tester.tap(find.text('تحديث'));
    await tester.pumpAndSettle();
    expect(find.text('حُدّث الكتاب'), findsOneWidget);
    expect(find.text('محمّل'), findsOneWidget);
    expect((await env.books.installed()).single.version, 2);
  });

  testWidgets('صفحة الكتاب: غير محمّل ثم الأبواب بعد التحميل', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('بيانات اختبار (ت ١٠٠هـ)'));
    await tester.pumpAndSettle();
    expect(find.text('حمّل الكتاب لعرض أبوابه'), findsOneWidget);
    expect(find.text('المصدر: OpenITI — ملك عام'), findsOneWidget);
    await tester.tap(find.text('تحميل الكتاب (١ ك.ب)'));
    await tester.pumpAndSettle();
    expect(find.text('الأبواب'), findsOneWidget);
    expect(find.text('الباب الأول: فقرات اختبار'), findsOneWidget);
    expect(find.text('فصل اختبار فرعي'), findsOneWidget);
    expect(
      find.bySemanticsLabel('الباب ٢ من ٢: فصل اختبار فرعي'),
      findsOneWidget,
    );
    // سهم الرجوع في بداية الشريط (يمين في RTL).
    final back = tester.getRect(find.byType(BackButton));
    expect(
      back.center.dx,
      greaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      ),
    );
  });

  testWidgets('صفحة الكتاب: الحذف من القائمة يعود للمكتبة', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    // الضغط على البطاقة يفتح صفحة الكتاب، و«افتح» يفتح القارئ.
    await tester.tap(find.text('بيانات اختبار (ت ١٠٠هـ)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('خيارات أخرى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف من الجهاز'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(find.text('المكتبة'), findsOneWidget);
    expect(find.text('حُذف الكتاب'), findsOneWidget);
  });

  testWidgets('تكبير الخط 200%: بطاقة عمودية بلا قص ولا فيض', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    final cover = tester.getRect(find.byType(BookCard)).top;
    final button = tester.getRect(find.text('تحميل'));
    expect(button.top, greaterThan(cover + 128));
  });

  group('المكتبة الكبيرة (6.5)', () {
    Map<String, Object?> titled(String id, String title, String author) {
      final book = miniBook(id: id);
      (book['title']! as Map<String, Object?>)['ar'] = title;
      (book['author']! as Map<String, Object?>)['ar'] = author;
      return book;
    }

    testWidgets('البحث بالعنوان والمؤلف، وشرائح التصنيف والعصر', (
      tester,
    ) async {
      env.server.catalog = catalogJson([
        env.server.addBook(
          titled('o00001', 'كتاب البخلاء', 'الجاحظ')
            ..['author_death_hijri'] = 50,
        ),
        env.server.addBook(
          titled('o00002', 'ديوان اصطناعي', 'شاعر اختبار')
            ..['author_death_hijri'] = 60,
          category: 'poetry',
          era: 'jahili',
        ),
        env.server.addBook(
          titled('o00003', 'تاريخ اصطناعي', 'مؤرخ اختبار'),
          category: 'history',
          era: 'late',
        ),
      ]);
      await pumpApp(tester);
      expect(find.text('كتاب البخلاء'), findsWidgets);
      expect(find.text('ديوان اصطناعي'), findsWidgets);
      expect(find.text('تاريخ اصطناعي'), findsNothing); // خارج الشاشة بعد
      // الشرائح بأسمائها العربية من ملف الترجمة.
      expect(
        find.widgetWithText(ChoiceChip, 'الشعر والدواوين'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoiceChip, 'العباسي'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'بخلاء');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('كتاب البخلاء'), findsWidgets);
      expect(find.text('ديوان اصطناعي'), findsNothing);

      await tester.enterText(find.byType(TextField), 'غير موجود');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('لا كتب تطابق البحث أو التصفية.'), findsOneWidget);

      await tester.tap(find.byTooltip('مسح'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'الشعر والدواوين'));
      await tester.pumpAndSettle();
      expect(find.text('ديوان اصطناعي'), findsWidgets);
      expect(find.text('كتاب البخلاء'), findsNothing);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'الشعر والدواوين'),
      );
      expect(chip.selected, isTrue);

      // التصنيف «الكل» ثم العصر.
      await tester.tap(find.widgetWithText(ChoiceChip, 'الكل').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'المماليك والمتأخرون'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'المماليك والمتأخرون'));
      await tester.pumpAndSettle();
      expect(find.text('تاريخ اصطناعي'), findsWidgets);
      expect(find.text('ديوان اصطناعي'), findsNothing);
    });

    testWidgets('الترتيب بالحجم من قائمة الترتيب', (tester) async {
      env.server.catalog = catalogJson([
        env.server.addBook(titled('o00001', 'كتاب ألف', 'مؤلف')),
        env.server.addBook(
          titled('o00002', 'كتاب باء', 'مؤلف')
            ..['chapters'] = syntheticBook(id: 'o00002')['chapters'],
        ),
      ]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('الترتيب: سنة الوفاة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الحجم').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('الترتيب: الحجم'), findsOneWidget);
      final first = tester.getRect(find.text('كتاب ألف').first).top;
      final second = tester.getRect(find.text('كتاب باء').first).top;
      expect(first, lessThan(second));
    });

    testWidgets('صفحات من 50: القائمة كسولة وتجلب الصفحة التالية بالتمرير', (
      tester,
    ) async {
      final entries = [
        for (var i = 0; i < 120; i++)
          env.server.addBook(
            titled(
              'o${i.toString().padLeft(5, '0')}',
              'كتاب رقم ${i + 1}',
              'مؤلف',
            )..['author_death_hijri'] = i + 1,
          ),
      ];
      env.server.catalog = catalogJson(entries);
      await pumpApp(tester);
      // كسولة: لا تُبنى إلا البطاقات الظاهرة.
      expect(find.byType(BookCard).evaluate().length, lessThan(10));
      final list = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      for (
        var i = 0;
        i < 20 && find.text('كتاب رقم 120').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(list, const Offset(0, -3000));
        await tester.pumpAndSettle();
      }
      expect(find.text('كتاب رقم 120'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('تبويب «المحمّلة» يعرض الكتب المحمّلة فقط', (tester) async {
      env.server.catalog = catalogJson([
        env.server.addBook(miniBook()),
        env.server.addBook(titled('o00002', 'كتاب غير محمّل', 'مؤلف')),
      ]);
      await pumpApp(tester);
      await tester.tap(find.text('المحمّلة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لم تحمّل أي كتاب بعد'), findsOneWidget);
      await env.preinstall(miniBook());
      await tester.tap(find.text('الكتب'));
      await tester.pumpAndSettle();
      await tester.fling(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('المحمّلة'));
      await tester.pumpAndSettle();
      expect(find.text('كتاب اختبار اصطناعي'), findsWidgets);
      expect(find.text('كتاب غير محمّل'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'افتح'), findsOneWidget);
    });

    testWidgets('الإنجليزية: أسماء الشرائح والتبويب مترجمة', (tester) async {
      await pumpApp(tester, locale: const Locale('en'));
      expect(find.text('Downloaded'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Poetry & diwans'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoiceChip, 'Umayyad'), findsOneWidget);
      expect(find.text('Search by title or author'), findsOneWidget);
    });
  });
}
