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

  Future<void> pumpApp(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
    await tester.pumpWidget(env.app(locale: locale));
    await tester.pumpAndSettle();
  }

  TextDirection directionOf(WidgetTester tester, Finder finder) =>
      Directionality.of(tester.element(finder));

  testWidgets('العربية افتراضياً: الواجهة RTL، والبطاقة بأرقام مشرقية', (tester) async {
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
      find.bySemanticsLabel(RegExp('^كتاب اختبار اصطناعي، بيانات اختبار، متوفى ١٠٠ للهجرة، ١ كيلوبايت، غير محمّل\$')),
      findsOneWidget,
    );
  });

  testWidgets('الإنجليزية LTR، ونص الكتاب يبقى RTL مع نقل لاتيني', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    expect(find.text('Library'), findsOneWidget);
    expect(directionOf(tester, find.text('Library')), TextDirection.ltr);
    expect(find.text('Synthetic Test Book — Test Data'), findsOneWidget);
    expect(find.text('بيانات اختبار (d. 100 AH)'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Download'), findsOneWidget);
    final titleText = tester.widget<Text>(find.text('كتاب اختبار اصطناعي').last);
    expect(titleText.textDirection, TextDirection.rtl);
  });

  testWidgets('هيكل مؤقت أثناء جلب الفهرس', (tester) async {
    await tester.pumpWidget(env.app());
    expect(find.bySemanticsLabel('جارٍ التحميل'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('جارٍ التحميل'), findsNothing);
  });

  testWidgets('أول تشغيل دون إنترنت: رسالة واضحة وإعادة المحاولة تعمل', (tester) async {
    env.server.offline = true;
    await pumpApp(tester);
    expect(find.text('تحتاج اتصالاً لتحميل الكتب'), findsOneWidget);
    expect(
      find.text('اتصل بالإنترنت مرة واحدة لتحميل قائمة الكتب، وبعدها تقرأ وتبحث وتستمع دون اتصال.'),
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
    expect(find.text('تعذّر تحميل قائمة الكتب. تحقّق من الاتصال وحاول مجدداً.'), findsOneWidget);
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
    expect(find.textContaining('سيُحذف «كتاب اختبار اصطناعي» من جهازك'), findsOneWidget);
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

  testWidgets('دون إنترنت مع كتاب محمّل: لافتة، والكتاب غير المحمّل معطّل', (tester) async {
    env.server.catalog = catalogJson([
      env.server.addBook(miniBook()),
      env.server.addBook(miniBook(id: 'other')),
    ]);
    await pumpApp(tester); // يحفظ نسخة من الفهرس
    await env.preinstall(miniBook());
    env.server.offline = true;
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    expect(find.text('أنت دون إنترنت — الكتب المحمّلة متاحة'), findsOneWidget);
    expect(find.text('محمّل'), findsOneWidget);
    expect(find.text('يحتاج اتصالاً'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('تحميل'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('تحديث متاح: شارة وزر، ثم رسالة «حُدّث الكتاب»', (tester) async {
    await env.preinstall(miniBook());
    env.server.catalog = catalogJson([env.server.addBook(miniBook(version: 2))]);
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
    expect(find.text('المصدر: بيانات اختبار اصطناعية — ملك عام'), findsOneWidget);
    await tester.tap(find.text('تحميل الكتاب (١ ك.ب)'));
    await tester.pumpAndSettle();
    expect(find.text('الأبواب'), findsOneWidget);
    expect(find.text('الباب الأول: فقرات اختبار'), findsOneWidget);
    expect(find.text('فصل اختبار فرعي'), findsOneWidget);
    expect(find.bySemanticsLabel('الباب ٢ من ٢: فصل اختبار فرعي'), findsOneWidget);
    // سهم الرجوع في بداية الشريط (يمين في RTL).
    final back = tester.getRect(find.byType(BackButton));
    expect(back.center.dx, greaterThan(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2));
  });

  testWidgets('صفحة الكتاب: الحذف من القائمة يعود للمكتبة', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await tester.tap(find.text('افتح'));
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
}
