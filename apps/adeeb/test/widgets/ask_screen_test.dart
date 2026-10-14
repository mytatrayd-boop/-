import 'dart:async';
import 'dart:convert';

import 'package:adeeb/ask/ask_providers.dart';
import 'package:adeeb/ask/ask_screen.dart';
import 'package:adeeb/library/library_screen.dart';
import 'package:adeeb/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

/// الاختبارات بكتاب اصطناعي (test/fixtures/mini_book.json)، وخادم وهمي بعقد
/// worker/src/app.ts. لا نصوص تراثية.
void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv();
    env.server.catalog = catalogJson([env.server.addBook(miniBook())]);
  });
  tearDown(() => env.dispose());

  void confirmed() =>
      SharedPreferences.setMockInitialValues({ageConfirmedKey: true});

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

  Future<void> askQuestion(WidgetTester tester, String q) async {
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), q);
    await tester.pump();
    await tester.ensureVisible(find.text('اسأل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اسأل'));
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

  /// رد بنص اقتباس ثابت من الفقرة الثانية في الكتاب الصغير.
  (int, String) quoteHikma(Map<String, Object?> body) {
    env.ask.remaining--;
    return (
      200,
      jsonEncode({
        'found': true,
        'answer': 'إجابة اختبار موجزة عن الحكمة.',
        'citations': [
          {'paragraph_id': 'mini-b001-p00002', 'quote': 'تجريبي الحكمه والاسد'},
        ],
        'remaining': env.ask.remaining,
      }),
    );
  }

  testWidgets(
    'أول استخدام: تأكيد العمر مرة واحدة، والرفض يغلق الشاشة بلا طلب',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await push(tester, askLocation());
      expect(find.text('قبل أن تسأل'), findsOneWidget);
      expect(find.text('هذه الميزة لمن هم 18 سنة فأكثر.'), findsOneWidget);
      await tester.tap(find.text('ليس الآن'));
      await tester.pumpAndSettle();
      expect(find.byType(AskScreen), findsNothing);
      expect(env.ask.requests, isEmpty);

      await push(tester, askLocation());
      await tester.tap(find.text('عمري 18 سنة فأكثر، فهمت'));
      await tester.pumpAndSettle();
      expect(find.text('قبل أن تسأل'), findsNothing);
      // الرصيد يُطلب بعد التأكيد فقط.
      expect(env.ask.requests.map((r) => r.url.path), ['/v1/quota']);
      expect(find.text('باقٍ لك ١٠ من ١٠ اليوم'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await push(tester, askLocation());
      expect(find.text('قبل أن تسأل'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ageConfirmedKey), isTrue);
    },
  );

  testWidgets(
    'إجابة: الاقتباس من النص المحلي بتشكيله، والنقر يفتح القارئ مظلّلاً',
    (tester) async {
      confirmed();
      env.ask.onAsk = quoteHikma;
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await push(tester, askLocation());
      expect(find.text('لا تكتب معلومات شخصية في سؤالك'), findsOneWidget);
      await askQuestion(tester, 'ما الحكمة؟');

      expect(
        find.text('إجابة مولَّدة آلياً من نص الكتاب — راجع الاقتباس'),
        findsOneWidget,
      );
      expect(find.text('إجابة اختبار موجزة عن الحكمة.'), findsOneWidget);
      expect(find.text('«تجريبي: الحِكْمَةُ والأَسَدُ»'), findsOneWidget);
      expect(
        find.text('كتاب اختبار اصطناعي ‹ الباب الأول: فقرات اختبار'),
        findsOneWidget,
      );
      expect(find.text('باقٍ لك ٩ من ١٠ اليوم'), findsWidgets);

      // الطلب: معرّف جهاز UUID v4 محفوظ، والفقرة المسترجعة محلياً.
      final request = env.ask.requests.last;
      final id = request.headers['X-Device-Id']!;
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(id) && id[14] == '4', isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(deviceIdKey), id);
      final body = env.ask.askBodies.single;
      expect(
        (body['passages']! as List).map((p) => (p as Map)['id']),
        contains('mini-b001-p00002'),
      );

      await tester.tap(find.text('«تجريبي: الحِكْمَةُ والأَسَدُ»'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(highlighted(tester, find.byType(ReaderScreen)), [
        'تجريبي: الحِكْمَةُ والأَسَدُ',
      ]);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(AskScreen), findsOneWidget);
    },
  );

  testWidgets('آخر إجابة فقط تُحفظ وتُعرض عند العودة', (tester) async {
    confirmed();
    env.ask.onAsk = quoteHikma;
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    await askQuestion(tester, 'ما الحكمة؟');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await push(tester, askLocation());
    expect(find.text('سؤالك: ما الحكمة؟'), findsOneWidget);
    expect(find.text('«تجريبي: الحِكْمَةُ والأَسَدُ»'), findsOneWidget);

    // «سؤال جديد» يمسح الشاشة؛ وسؤال لا يُجاب يحذف المحفوظ. (تنتظر رسالة
    // الرصيد العابرة حتى لا تغطي الزر.)
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('سؤال جديد'));
    await tester.tap(find.text('سؤال جديد'));
    await tester.pumpAndSettle();
    expect(find.text('سؤالك: ما الحكمة؟'), findsNothing);
    await askQuestion(tester, 'ما عاصمة فرنسا؟');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(lastAnswerKey), isNull);
  });

  testWidgets('اقتباس مختلق: لا تُعرض الإجابة وتُعرض النصوص المطابقة', (
    tester,
  ) async {
    confirmed();
    env.ask.onAsk = (body) =>
        env.ask.quoteFirst(body, quote: 'الحكمة ضالة المؤمن أينما وجدها');
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    await askQuestion(tester, 'ما الحكمة؟');
    expect(
      find.text('لم نتمكن من التحقق من الإجابة، فإليك النصوص المطابقة مباشرة.'),
      findsOneWidget,
    );
    expect(find.text('إجابة اختبار موجزة.'), findsNothing);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('سؤال خارج الكتب: «لم أجد» محلياً بلا طلب، ومن الخادم', (
    tester,
  ) async {
    confirmed();
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    await askQuestion(tester, 'ما عاصمة فرنسا؟');
    expect(find.text('لم أجد هذا في الكتب المتاحة.'), findsOneWidget);
    expect(
      find.text('يجيب الأديب عن محتوى الكتب فقط، ولا يقدّم فتاوى.'),
      findsOneWidget,
    );
    expect(env.ask.askBodies, isEmpty);

    env.ask.onAsk = (_) => (
      200,
      jsonEncode({
        'found': false,
        'answer': '',
        'citations': [],
        'reason': 'NOT_FOUND',
        'remaining': 9,
      }),
    );
    await askQuestion(tester, 'ما رأي الأسد في الفتوى؟');
    expect(find.text('لم أجد هذا في الكتب المتاحة.'), findsOneWidget);
    expect(find.text('أقرب النصوص إلى سؤالك'), findsOneWidget);
    expect(find.text('باقٍ لك ٩ من ١٠ اليوم'), findsOneWidget);
  });

  final failures = <(String, void Function(TestEnv), String, bool)>[
    (
      'دون إنترنت',
      (e) => e.ask.offline = true,
      'أنت دون إنترنت. الإجابة الذكية تحتاج اتصالاً، وهذه النصوص المطابقة من كتبك المحمّلة:',
      true,
    ),
    (
      'UNAVAILABLE',
      (e) => e.ask.onAsk = (_) => (503, '{"code":"UNAVAILABLE"}'),
      'الخدمة غير متاحة الآن. حاول لاحقاً. إليك النصوص المطابقة:',
      true,
    ),
    (
      'رد غير JSON (Cloudflare 1027)',
      (e) => e.ask.onAsk = (_) => (500, '<html>error code: 1027</html>'),
      'الخدمة غير متاحة الآن. حاول لاحقاً. إليك النصوص المطابقة:',
      true,
    ),
    (
      'RATE_LIMIT',
      (e) => e.ask.onAsk = (_) => (429, '{"code":"RATE_LIMIT"}'),
      'أرسلت أسئلة كثيرة بسرعة. انتظر دقيقة ثم حاول.',
      false,
    ),
    (
      'UPGRADE_REQUIRED',
      (e) => e.ask.onAsk = (_) => (426, '{"code":"UPGRADE_REQUIRED"}'),
      'حدّث التطبيق لتستخدم «اسأل الأديب». إليك النصوص المطابقة:',
      false,
    ),
  ];
  for (final (name, arrange, message, retry) in failures) {
    testWidgets('$name: رسالة السبب مع النصوص المطابقة', (tester) async {
      confirmed();
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await push(tester, askLocation());
      arrange(env);
      await askQuestion(tester, 'ما الحكمة؟');
      expect(find.text(message), findsOneWidget);
      expect(find.text('النصوص المطابقة'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AskScreen),
          matching: find.byType(Card),
        ),
        findsWidgets,
      );
      expect(
        find.text('إعادة المحاولة'),
        retry ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('انتهاء الحصة: لافتة، والزر يصير «ابحث في النصوص» بلا طلب', (
    tester,
  ) async {
    confirmed();
    env.ask.onAsk = (_) => (429, '{"code":"DAILY_LIMIT","remaining":0}');
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    await askQuestion(tester, 'ما الحكمة؟');
    expect(
      find.text(
        'انتهت أسئلة اليوم (١٠ من ١٠). يتجدد رصيدك غداً. إليك النصوص المطابقة لسؤالك من الكتب:',
      ),
      findsOneWidget,
    );
    expect(find.text('انتهت أسئلة اليوم'), findsOneWidget);
    expect(find.text('ابحث في النصوص'), findsOneWidget);
    final before = env.ask.askBodies.length;
    await tester.tap(find.text('ابحث في النصوص'));
    await tester.pumpAndSettle();
    expect(env.ask.askBodies.length, before);
    expect(find.text('النصوص المطابقة'), findsOneWidget);
  });

  testWidgets('الانتظار: المراحل و«إلغاء» و«أطول من المعتاد» بعد 15 ثانية', (
    tester,
  ) async {
    confirmed();
    env.ask.gate = Completer<void>();
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    await tester.enterText(find.byType(TextField), 'ما الحكمة؟');
    await tester.pump();
    await tester.tap(find.text('اسأل'));
    await tester.pump();
    await tester.pump();
    expect(find.text('يصوغ الإجابة…'), findsOneWidget);
    expect(find.text('قد يُحتسب السؤال إذا وصل إلى الخادم'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('يستغرق الأمر وقتاً أطول من المعتاد…'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pump();
    expect(find.text('اسأل'), findsOneWidget);
    expect(find.text('يصوغ الإجابة…'), findsNothing);
    env.ask.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('إجابة اختبار موجزة.'), findsNothing);
  });

  testWidgets('الحقل: أقل من 3 أحرف معطّل، وأكثر من 500 خطأ', (tester) async {
    confirmed();
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    FilledButton button() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('اسأل'), matching: find.byType(FilledButton)),
    );
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'مم');
    await tester.pump();
    expect(find.text('اكتب سؤالاً أوضح'), findsOneWidget);
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'ح' * 450);
    await tester.pump();
    expect(find.text('٤٥٠ / ٥٠٠'), findsOneWidget);
    expect(button().onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'ح' * 501);
    await tester.pump();
    expect(find.text('السؤال أطول من ٥٠٠ حرف'), findsOneWidget);
    expect(button().onPressed, isNull);
    // الأمثلة تملأ الحقل.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('ماذا قال ابن المقفع عن الصديق؟'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ماذا قال ابن المقفع عن الصديق؟',
    );
  });

  testWidgets('بلا كتب محمّلة: الرسالة و«اذهب إلى المكتبة»', (tester) async {
    confirmed();
    await pumpApp(tester);
    await push(tester, askLocation());
    expect(
      find.text('حمّل كتاباً واحداً على الأقل ليجيبك الأديب من نصه.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('اذهب إلى المكتبة'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('«اسأل الأديب عن هذا» من ورقة الفقرة يفتحها بنطاق الكتاب', (
    tester,
  ) async {
    confirmed();
    await env.preinstall(miniBook());
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await push(tester, '/read/mini?p=mini-b001-p00002');
    await tester.longPress(find.textContaining('فقرة اختبار ثانية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اسأل الأديب عن هذا'));
    await tester.pumpAndSettle();
    expect(find.byType(AskScreen), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('كتاب اختبار اصطناعي'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('القارئ: كتاب غير محمّل من اقتباس يعرض نص الاقتباس', (
    tester,
  ) async {
    await pumpApp(tester);
    await push(
      tester,
      Uri(
        path: '/read/mini',
        queryParameters: {
          'p': 'mini-b001-p00002',
          'quote': 'الحِكْمَةُ والأَسَدُ',
        },
      ).toString(),
    );
    expect(find.text('«الحِكْمَةُ والأَسَدُ»'), findsOneWidget);
  });

  testWidgets('قارئ الشاشة: المراحل و«وصلت الإجابة» تُعلن، والمصدر زر بتسمية', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    confirmed();
    env.ask.onAsk = quoteHikma;
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    tester.takeAnnouncements();
    await askQuestion(tester, 'ما الحكمة؟');
    expect(tester.takeAnnouncements().map((a) => a.message), [
      'يبحث في الكتب…',
      'يصوغ الإجابة…',
      'يتحقق من الاقتباس…',
      'وصلت الإجابة',
    ]);
    expect(
      find.bySemanticsLabel(
        'افتح المصدر: كتاب اختبار اصطناعي، الباب الأول: فقرات اختبار',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('باقٍ لك ٩ من ١٠ اليوم'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('أهداف اللمس 48dp', (tester) async {
    confirmed();
    env.ask.onAsk = quoteHikma;
    await env.preinstall(miniBook());
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await askQuestion(tester, 'ما الحكمة؟');
    // الفحص الآلي يقيس الجزء الظاهر فقط، فيُفحص بعد العودة إلى أعلى الشاشة،
    // وتُقاس أزرار الإجابة مباشرة.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    for (final label in ['نسخ', 'مشاركة', 'سؤال جديد']) {
      final size = tester.getSize(
        find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final chip = tester.getSize(find.byType(ActionChip).first);
    expect(chip.height, greaterThanOrEqualTo(48));
    final quote = tester.getSize(
      find
          .ancestor(
            of: find.text('«تجريبي: الحِكْمَةُ والأَسَدُ»'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(quote.height, greaterThanOrEqualTo(48));
  });

  testWidgets('تكبير الخط 200%: بلا فيض، والشارة في سطر مستقل', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    confirmed();
    env.ask.onAsk = quoteHikma;
    await env.preinstall(miniBook());
    await env.preinstall(syntheticBook());
    await pumpApp(tester);
    await push(tester, askLocation());
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('باقٍ لك ١٠ من ١٠ اليوم'),
      ),
      findsNothing,
    );
    expect(find.text('باقٍ لك ١٠ من ١٠ اليوم'), findsOneWidget);
    await askQuestion(tester, 'ما الحكمة؟');
    expect(tester.takeException(), isNull);
    env.ask.onAsk = (_) => (503, '{"code":"UNAVAILABLE"}');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('سؤال جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سؤال جديد'));
    await tester.pumpAndSettle();
    await askQuestion(tester, 'ما الحكمة؟');
    expect(tester.takeException(), isNull);
  });

  testWidgets('الإنجليزية: نصوص مترجمة، والإجابة والاقتباس RTL', (
    tester,
  ) async {
    confirmed();
    env.ask.onAsk = quoteHikma;
    await env.preinstall(miniBook());
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.byTooltip('Ask Adeeb'));
    await tester.pumpAndSettle();
    expect(
      find.text("Don't include personal information in your question"),
      findsOneWidget,
    );
    expect(find.text('10 of 10 left today'), findsOneWidget);
    expect(
      find.text('Answers are in Arabic, quoted from the books'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'ما الحكمة؟');
    await tester.pump();
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(env.ask.askBodies.single['lang'], 'en');
    expect(
      find.text('AI-generated from the book text — check the quote'),
      findsOneWidget,
    );
    final quote = tester.widget<Text>(
      find.text('«تجريبي: الحِكْمَةُ والأَسَدُ»'),
    );
    expect(quote.textDirection, TextDirection.rtl);
  });
}
