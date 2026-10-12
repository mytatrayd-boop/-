import 'dart:async';

import 'package:adeeb/audio/listening_player.dart';
import 'package:adeeb/audio/listening_providers.dart';
import 'package:adeeb/audio/mini_player.dart';
import 'package:adeeb/audio/player_sheets.dart';
import 'package:adeeb/audio/tts_engine.dart';
import 'package:adeeb/library/book_card.dart';
import 'package:adeeb/library/library_controller.dart';
import 'package:adeeb/library/library_screen.dart';
import 'package:adeeb/reader/continue_reading_card.dart';
import 'package:adeeb/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

const firstMini = 'هذه فقرة اختبار اصطناعية أولى، وليست من أي كتاب.';
const secondMini = 'فقرة اختبار ثانية فيها تشكيل تجريبي: الحِكْمَةُ والأَسَدُ.';

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

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(
      GoRouter.of(tester.element(find.byType(LibraryScreen))).push(location),
    );
    await tester.pumpAndSettle();
  }

  ListeningState stateOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(listeningStateProvider);

  /// ينهي المقطع الجاري في المحرك المُحاكى.
  Future<void> finishUtterance(
    WidgetTester tester, [
    SpeakResult r = SpeakResult.done,
  ]) async {
    env.tts.finish(r);
    // وقفات الشعر بين المقاطع مؤقتات حقيقية.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  /// ينقر عنصراً بعد تمريره إلى الظهور (المشغّل الكامل أطول من شاشة الاختبار).
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> listenFromBookPage(WidgetTester tester, String bookId) async {
    await push(tester, '/book/$bookId');
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'استمع'));
  }

  testWidgets(
    '«استمع» من صفحة الكتاب يبدأ من آخر موضع، والمشغّل المصغّر يتحكم ويحفظ الموضع',
    (tester) async {
      await env.preinstall(miniBook());
      await env.reading.savePosition('mini', 'mini-b001-p00002');
      await pumpApp(tester);
      await listenFromBookPage(tester, 'mini');

      expect(env.tts.currentText, secondMini);
      expect(env.media.active, isTrue);
      expect(env.media.last!.playing, isTrue);
      expect(
        env.media.last!.nowPlaying.chapterTitle,
        'الباب الأول: فقرات اختبار',
      );
      final mini = find.byType(MiniPlayer);
      expect(mini, findsOneWidget);
      expect(
        find.descendant(
          of: mini,
          matching: find.text('الباب الأول: فقرات اختبار'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mini, matching: find.text('كتاب اختبار اصطناعي')),
        findsWidgets,
      );

      // إيقاف مؤقت ثم تشغيل من المشغّل المصغّر.
      await tester.tap(find.bySemanticsLabel('إيقاف مؤقت'));
      await tester.pumpAndSettle();
      expect(stateOf(tester).status, ListeningStatus.paused);
      expect(env.tts.speaking, isFalse);
      expect(env.media.last!.playing, isFalse);
      await tester.tap(find.bySemanticsLabel('تشغيل القراءة الصوتية'));
      await tester.pumpAndSettle();
      expect(env.tts.currentText, secondMini);

      // ينتقل للباب التالي تلقائياً، والموضع يُحفظ كآخر موضع قراءة.
      await finishUtterance(tester);
      expect(env.tts.currentText, 'شطر اختبار أول');
      expect(
        (await env.reading.position('mini'))!.paragraphId,
        'mini-b002-p00001',
      );

      // ✕ ينهي الجلسة ويخفي المشغّل.
      await tester.tap(find.bySemanticsLabel('إيقاف الاستماع'));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsNothing);
      expect(env.media.deactivations, 1);
      expect(env.tts.speaking, isFalse);
    },
  );

  testWidgets('«استمع» بلا موضع محفوظ يبدأ من أول الكتاب', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    expect(env.tts.currentText, firstMini);
  });

  testWidgets(
    'القارئ: «استمع من هنا» يميّز الفقرة المقروءة ويتبعها، والتمرير اليدوي يُظهر «العودة»',
    (tester) async {
      await env.preinstall(syntheticBook());
      await pumpApp(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'افتح'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'استمع من هنا'));
      await tester.pumpAndSettle();
      expect(env.tts.currentText, contains('رقم 1 من الباب 1،'));
      // المشغّل المصغّر يحل محل الشريط السفلي.
      expect(find.widgetWithText(FilledButton, 'استمع من هنا'), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(
        tester.getSemantics(bigParagraph(1, 1)),
        isSemantics(value: 'يُقرأ الآن'),
      );

      for (var i = 0; i < 12; i++) {
        await finishUtterance(tester);
      }
      expect(env.tts.currentText, contains('رقم 13 من الباب 1،'));
      // الشاشة تتبع الفقرة المقروءة.
      expect(bigParagraph(1, 13).hitTestable(), findsOneWidget);
      expect(
        tester.getSemantics(bigParagraph(1, 13)),
        isSemantics(value: 'يُقرأ الآن'),
      );
      expect(
        tester.getSemantics(bigParagraph(1, 12)),
        isNot(isSemantics(value: 'يُقرأ الآن')),
      );

      // التمرير باليد يوقف التتبع ويُظهر زر العودة.
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 600),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.text('العودة إلى موضع الاستماع'), findsOneWidget);
      await finishUtterance(tester);
      expect(bigParagraph(1, 14).hitTestable(), findsNothing);
      await tester.tap(find.text('العودة إلى موضع الاستماع'));
      await tester.pumpAndSettle();
      expect(find.text('العودة إلى موضع الاستماع'), findsNothing);
      expect(bigParagraph(1, 14).hitTestable(), findsOneWidget);
    },
  );

  testWidgets('«استمع من هنا» من ورقة الفقرة: الشعر بالشطرين', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'افتح'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('شطر اختبار أول'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'استمع من هنا'));
    await tester.pumpAndSettle();
    expect(env.tts.currentText, 'شطر اختبار أول');
    await finishUtterance(tester);
    expect(env.tts.currentText, 'شطر اختبار ثانٍ');
  });

  testWidgets('نهاية الكتاب: يتوقف الصوت مع «انتهى الكتاب»', (tester) async {
    await env.preinstall(miniBook());
    await env.reading.savePosition('mini', 'mini-b002-p00001');
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    for (var i = 0; i < 4; i++) {
      await finishUtterance(tester);
    }
    expect(find.text('انتهى الكتاب'), findsOneWidget);
    expect(find.byType(MiniPlayer), findsNothing);
    expect(env.media.deactivations, 1);
  });

  testWidgets(
    'لا صوت عربي: ورقة الإرشادات مع «افتح إعدادات الصوت» و«لم تجد الخيار؟»',
    (tester) async {
      env.tts.voices = [];
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await listenFromBookPage(tester, 'mini');
      expect(find.text('لا يوجد صوت عربي على جهازك'), findsOneWidget);
      expect(
        find.textContaining('تحويل النص إلى كلام ← محرّك Google'),
        findsOneWidget,
      );
      expect(find.byType(MiniPlayer), findsNothing);

      await tester.tap(find.text('افتح إعدادات الصوت'));
      await tester.pumpAndSettle();
      expect(env.tts.settingsOpened, 1);
      // تعذّر الفتح (مثلاً آيفون): يظهر البديل العام.
      expect(
        find.textContaining('يختلف المسار حسب الشركة المصنّعة'),
        findsOneWidget,
      );
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد صوت عربي على جهازك'), findsNothing);
    },
  );

  testWidgets(
    'المشغّل الكامل: النص، التالي والسابق، السرعة تُحفظ، الصوت و«جرّب»، «اذهب إلى النص»',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await listenFromBookPage(tester, 'mini');

      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayer),
          matching: find.text('الباب الأول: فقرات اختبار'),
        ),
      );
      await tester.pumpAndSettle();
      final full = find.byType(FullPlayer);
      expect(full, findsOneWidget);
      expect(
        find.descendant(of: full, matching: find.text(firstMini)),
        findsOneWidget,
      );

      await tapVisible(tester, find.byTooltip('الفقرة التالية'));
      expect(env.tts.currentText, secondMini);
      await tapVisible(tester, find.byTooltip('الفقرة السابقة'));
      expect(env.tts.currentText, firstMini);

      // السرعة: شريحة «١٫٥×» تُطبّق فوراً وتُحفظ.
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '١×'))
            .selected,
        isTrue,
      );
      await tapVisible(tester, find.text('١٫٥×'));
      expect(env.tts.configured.last.speed, 1.5);
      expect(
        (await SharedPreferences.getInstance()).getDouble('audio.speed'),
        1.5,
      );
      expect(
        tester.getSemantics(find.text('١٫٥×')),
        isSemantics(label: 'السرعة ١٫٥ ضعف', isSelected: true),
      );

      // الصوت.
      await tapVisible(tester, find.text('الصوت: عربي (مصر) — صوت ١'));
      expect(find.byType(VoicePickerSheet), findsOneWidget);
      expect(find.text('عربي (مصر) — صوت ٢'), findsOneWidget);
      expect(find.text('عربي (السعودية) — صوت ١'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('جرّب عربي (مصر) — صوت ٢'));
      await tester.pumpAndSettle();
      expect(
        env.tts.currentText,
        'قال الجاحظ: البيان اسمٌ جامعٌ لكل شيء كشف لك قناع المعنى.',
      );
      expect(stateOf(tester).status, ListeningStatus.paused);
      env.tts.finish();
      await tester.pumpAndSettle();
      await tester.tap(find.text('عربي (السعودية) — صوت ١'));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getString('audio.voice'),
        'ar-sa-1',
      );
      expect(stateOf(tester).voice?.name, 'ar-sa-1');
      Navigator.of(tester.element(find.byType(VoicePickerSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('الصوت: عربي (السعودية) — صوت ١'), findsOneWidget);

      // «اذهب إلى النص» يفتح القارئ على الفقرة المقروءة.
      await tapVisible(tester, find.text('اذهب إلى النص'));
      expect(find.byType(FullPlayer), findsNothing);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(
        tester.getSemantics(find.text(firstMini)),
        isSemantics(value: 'يُقرأ الآن'),
      );
    },
  );

  testWidgets('السرعة والصوت المحفوظان يُطبّقان عند البدء', (tester) async {
    SharedPreferences.setMockInitialValues({
      'audio.speed': 1.25,
      'audio.voice': 'ar-eg-2',
    });
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    expect(env.tts.configured.last.speed, 1.25);
    expect(env.tts.configured.last.voice?.name, 'ar-eg-2');
  });

  testWidgets(
    'أوامر الإشعار: إيقاف وتشغيل، والضغط على الإشعار يفتح المشغّل الكامل',
    (tester) async {
      await env.preinstall(miniBook());
      await pumpApp(tester);
      await listenFromBookPage(tester, 'mini');
      env.media.send(MediaCommand.pause);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('تشغيل القراءة الصوتية'), findsOneWidget);
      env.media.send(MediaCommand.next);
      await tester.pumpAndSettle();
      expect(env.media.last!.nowPlaying.id, 'mini-b001-p00002');
      env.media.send(MediaCommand.openPlayer);
      await tester.pumpAndSettle();
      expect(find.byType(FullPlayer), findsOneWidget);
      // إيقاف الجلسة من الإشعار يغلق المشغّل الكامل.
      env.media.send(MediaCommand.stop);
      await tester.pumpAndSettle();
      expect(find.byType(FullPlayer), findsNothing);
      expect(find.byType(MiniPlayer), findsNothing);
    },
  );

  testWidgets('خطأ المحرك: رسالة في المشغّل و«إعادة المحاولة»', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    await finishUtterance(tester, SpeakResult.error);
    expect(find.text('توقّف الصوت بسبب خطأ في محرّك القراءة.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(env.tts.currentText, firstMini);
    expect(stateOf(tester).playing, isTrue);
  });

  testWidgets('قارئ الشاشة: تنبيه التداخل عند أول تشغيل فقط', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    const warning =
        'قد يتداخل صوت القراءة مع قارئ الشاشة. استخدم سماعة أو أوقف القراءة الصوتية مؤقتاً عند التنقل.';
    expect(find.text(warning), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('إيقاف الاستماع'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'استمع'));
    expect(find.text(warning), findsNothing);
  });

  testWidgets('أهداف اللمس 48dp في المشغّل المصغّر والكامل', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    for (final label in ['إيقاف مؤقت', 'إيقاف الاستماع']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: label);
    }
    env.media.send(MediaCommand.openPlayer);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('تكبير الخط 200%: صفحة الكتاب والمشغّلان بلا فيض', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    expect(tester.takeException(), isNull);
    expect(find.byType(MiniPlayer), findsOneWidget);
    env.media.send(MediaCommand.openPlayer);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('تصغير'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تابع القراءة'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('الإنجليزية: التسميات من ARB والأرقام غربية', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester, locale: const Locale('en'));
    await push(tester, '/book/mini');
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Listen'));
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    expect(find.bySemanticsLabel('Stop listening'), findsOneWidget);
    env.media.send(MediaCommand.openPlayer);
    await tester.pumpAndSettle();
    for (final text in [
      'Speed',
      '1.25×',
      'Voice: Arabic (Egypt) — voice 1',
      'Go to text',
    ]) {
      expect(find.text(text, skipOffstage: false), findsOneWidget);
    }
    expect(find.byTooltip('Next paragraph'), findsOneWidget);
  });

  testWidgets('«استمع» في بطاقة «تابع القراءة» يبدأ من آخر موضع', (
    tester,
  ) async {
    await env.preinstall(miniBook());
    await env.reading.savePosition('mini', 'mini-b001-p00002');
    await pumpApp(tester);
    final card = find.byType(ContinueReadingCard);
    expect(card, findsOneWidget);
    await tapVisible(
      tester,
      find.descendant(
        of: card,
        matching: find.widgetWithText(OutlinedButton, 'استمع'),
      ),
    );
    expect(env.tts.currentText, secondMini);
    expect(find.byType(MiniPlayer), findsOneWidget);
  });

  testWidgets('«استمع» في قائمة الضغط المطوّل على الكتاب', (tester) async {
    await env.preinstall(miniBook());
    await env.reading.savePosition('mini', 'mini-b002-p00001');
    await pumpApp(tester);
    await tester.longPress(
      find.byWidgetPredicate((w) => w is BookCard && w.item.id == 'mini'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'استمع'));
    await tester.pumpAndSettle();
    expect(env.tts.currentText, 'شطر اختبار أول');
    expect(find.byType(MiniPlayer), findsOneWidget);
  });

  testWidgets('أثناء التجهيز: زرّا السابق والتالي معطّلان', (tester) async {
    final gate = env.media.activateGate = Completer<void>();
    await env.preinstall(miniBook());
    await env.reading.savePosition('mini', 'mini-b001-p00002');
    await pumpApp(tester);
    await push(tester, '/book/mini');
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'استمع'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'استمع'));
    await tester.pump();
    await tester.pump();
    expect(stateOf(tester).status, ListeningStatus.preparing);
    env.media.send(MediaCommand.openPlayer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FullPlayer), findsOneWidget);
    for (final t in ['الفقرة السابقة', 'الفقرة التالية']) {
      final button = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip(t), matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNull, reason: t);
    }
    expect(find.text('يُجهَّز الصوت…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(env.tts.currentText, secondMini);
    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('الفقرة التالية'),
        matching: find.byType(IconButton),
      ),
    );
    expect(next.onPressed, isNotNull);
  });

  testWidgets('حذف الكتاب المسموع يوقف الاستماع', (tester) async {
    await env.preinstall(miniBook());
    await pumpApp(tester);
    await listenFromBookPage(tester, 'mini');
    expect(find.byType(MiniPlayer), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    unawaited(
      container.read(libraryControllerProvider.notifier).delete('mini'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsNothing);
    expect(env.tts.speaking, isFalse);
    expect(env.media.active, isFalse);
    expect((await env.books.installed()).map((b) => b.id), isEmpty);
  });
}
