import 'package:adeeb/ask/ask_providers.dart';
import 'package:adeeb/ask/ask_service.dart';
import 'package:adeeb/ask/last_answer.dart';
import 'package:adeeb/ask/quote_verifier.dart';
import 'package:adeeb/audio/listening_providers.dart';
import 'package:adeeb/reader/display_settings_sheet.dart';
import 'package:adeeb/reader/reader_settings.dart';
import 'package:adeeb/settings/about_screen.dart';
import 'package:adeeb/settings/app_settings.dart';
import 'package:adeeb/settings/downloaded_books_screen.dart';
import 'package:adeeb/settings/privacy_screen.dart';
import 'package:adeeb/settings/settings_screen.dart';
import 'package:adeeb/settings/sources_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

/// الإعدادات والمصادر والخصوصية وعن التطبيق (الميزة 8). كتاب اصطناعي فقط.
void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv();
    env.server.catalog = catalogJson([env.server.addBook(miniBook())]);
  });
  tearDown(() => env.dispose());

  Future<void> openSettings(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    bool followSettings = false,
  }) async {
    await tester.pumpWidget(
      env.app(locale: locale, followSettings: followSettings),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(locale.languageCode == 'en' ? 'Settings' : 'الإعدادات'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      // من أعلى القائمة ثم نزولاً.
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 3000),
        3000,
      );
      await tester.pumpAndSettle();
    }
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('تبديل اللغة فوري: الواجهة تنقلب LTR مع رسالة بالإنجليزية', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppSettingsController.languageKey: 'ar',
    });
    await openSettings(tester, followSettings: true);
    expect(
      Directionality.of(tester.element(find.byType(SettingsScreen))),
      TextDirection.rtl,
    );
    await tapText(tester, 'اللغة');
    await tapText(tester, 'English');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('The app is now in English'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(SettingsScreen))),
      TextDirection.ltr,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettingsController.languageKey), 'en');

    // والعودة إلى العربية.
    await tapText(tester, 'Language');
    await tapText(tester, 'العربية');
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('صارت الواجهة بالعربية'), findsOneWidget);
  });

  testWidgets('المظهر الداكن يُطبَّق فوراً ويُحفظ', (tester) async {
    await openSettings(tester);
    await tapText(tester, 'المظهر');
    await tapText(tester, 'داكن');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettingsController.themeKey), 'dark');
  });

  testWidgets('حجم الخط من الإعدادات يغيّر المستوى الافتراضي للقارئ', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.text('المستوى ٣ من ٦'), findsOneWidget);
    await tapText(tester, 'حجم الخط ولون الصفحة');
    expect(find.byType(DisplaySettingsSheet), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('تكبير الخط'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ReaderSettingsController.levelKey), 4);
  });

  testWidgets('الصوت والسرعة: محفوظان من الإعدادات', (tester) async {
    await openSettings(tester);
    expect(find.text('تلقائي'), findsOneWidget);
    await tester.ensureVisible(find.text('١٫٥×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('١٫٥×'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(AudioSettingsController.speedKey), 1.5);

    await tapText(tester, 'الصوت');
    expect(find.text('عربي (مصر) — صوت ٢'), findsOneWidget);
    await tester.tap(find.text('عربي (مصر) — صوت ٢'));
    await tester.pumpAndSettle();
    expect(prefs.getString(AudioSettingsController.voiceKey), 'ar-eg-2');
    Navigator.of(tester.element(find.text('عربي (مصر) — صوت ٢').last)).pop();
    await tester.pumpAndSettle();
    expect(find.text('عربي (مصر) — صوت ٢'), findsOneWidget);
  });

  testWidgets('إعادة ضبط تأكيد العمر بعد حوار تأكيد', (tester) async {
    SharedPreferences.setMockInitialValues({ageConfirmedKey: true});
    await openSettings(tester);
    await tapText(tester, 'إعادة ضبط تأكيد العمر');
    expect(find.text('إعادة ضبط تأكيد العمر؟'), findsOneWidget);
    await tester.tap(find.text('إعادة الضبط'));
    await tester.pumpAndSettle();
    expect(find.text('أُعيد ضبط تأكيد العمر'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ageConfirmedKey), isNull);
  });

  testWidgets('مسح آخر إجابة، والصف معطّل حين لا إجابة', (tester) async {
    const answer = AskAnswer(
      question: 'سؤال',
      remaining: null,
      answer: 'إجابة',
      citations: [
        VerifiedCitation(
          paragraphId: 'mini-p0001',
          bookId: 'mini',
          bookTitle: 'كتاب',
          chapterTitle: 'باب',
          quote: 'اقتباس',
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      lastAnswerKey: encodeLastAnswer(answer),
    });
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('آخر إجابة فقط محفوظة على جهازك'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tapText(tester, 'مسح آخر إجابة');
    expect(find.text('مُسحت آخر إجابة'), findsOneWidget);
    expect(find.text('لا إجابة محفوظة'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(lastAnswerKey), isNull);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('مسح آخر إجابة'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets('المصادر: OpenITI والترخيص، وتفاصيل الطبعة من ملف الكتاب', (
    tester,
  ) async {
    final book = miniBook();
    (book['source']! as Map<String, Object?>)['original'] =
        'المكتبة الشاملة، الكتاب رقم 123';
    env.server.catalog = catalogJson([env.server.addBook(book)]);
    await env.preinstall(book);
    await openSettings(tester);
    await tapText(tester, 'المصادر والتراخيص');
    expect(find.byType(SourcesScreen), findsOneWidget);
    expect(find.textContaining('OpenITI'), findsWidgets);
    expect(find.textContaining('CC BY-NC-SA 4.0'), findsWidgets);
    expect(find.text('كتاب اختبار اصطناعي'), findsOneWidget);
    expect(find.text('المكتبة الشاملة، الكتاب رقم 123'), findsOneWidget);
    expect(find.text('لا توجد'), findsOneWidget); // الطبعة
    expect(
      find.text('لا شيء — كتاب اصطناعي للاختبارات فقط، ليس نصاً تراثياً'),
      findsOneWidget,
    );
    expect(find.text('ملك عام'), findsOneWidget);

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
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
    expect(find.text('https://openiti.org'), findsOneWidget);
    expect(
      find.text('https://creativecommons.org/licenses/by-nc-sa/4.0/'),
      findsOneWidget,
    );
    final copyButtons = find.widgetWithText(TextButton, 'انسخ الرابط');
    await tester.tap(copyButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(copyButtons.at(1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('https://example.invalid/mini'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(copyButtons.last);
    await tester.pumpAndSettle();
    expect(copied, [
      'https://openiti.org',
      'https://creativecommons.org/licenses/by-nc-sa/4.0/',
      'https://example.invalid/mini',
    ]);
    expect(find.text('نُسخ الرابط'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Amiri'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('IBM Plex Sans Arabic'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'عرض الترخيص').first);
    await tester.pumpAndSettle();
    expect(find.byType(FontLicenseScreen), findsOneWidget);
    expect(find.textContaining('SIL OPEN FONT LICENSE'), findsOneWidget);
    await back(tester);
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(SourcesScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tapText(tester, 'عرض تراخيص المكتبات');
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets(
    'كتاب غير محمّل: المصدر من الفهرس وتنبيه بأن الطبعة بعد التحميل',
    (tester) async {
      await openSettings(tester);
      await tapText(tester, 'المصادر والتراخيص');
      expect(find.text('كتاب اختبار اصطناعي'), findsOneWidget);
      expect(find.text('OpenITI'), findsOneWidget);
      expect(
        find.text('تظهر الطبعة وما حُذف بعد تحميل الكتاب.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('سياسة الخصوصية: Gemini والمراجعة البشرية و18+ ولا تتبع', (
    tester,
  ) async {
    await openSettings(tester);
    await tapText(tester, 'سياسة الخصوصية');
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.text('لا حساب'), findsOneWidget);
    expect(find.textContaining('Gemini'), findsWidgets);
    expect(find.textContaining('مراجعون بشريون'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('HMAC'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('ليوم واحد فقط'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('لا إعلانات ولا تتبع'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('18'), findsWidgets);
  });

  testWidgets('ورقة أول استخدام لاسأل الأديب تفتح سياسة الخصوصية', (
    tester,
  ) async {
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('اسأل الأديب'));
    await tester.pumpAndSettle();
    expect(find.text('قبل أن تسأل'), findsOneWidget);
    await tapText(tester, 'اقرأ سياسة الخصوصية');
    expect(find.byType(PrivacyScreen), findsOneWidget);
    await back(tester);
    await tester.pumpAndSettle();
    expect(find.text('قبل أن تسأل'), findsOneWidget);
  });

  testWidgets('عن التطبيق: الشعار الكامل بتسمية لقارئ الشاشة', (tester) async {
    await openSettings(tester);
    await tapText(tester, 'عن الأديب الذكي');
    expect(find.byType(AboutScreen), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).imageProvider, isA<AssetImage>());
    expect(image.semanticLabel, 'شعار الأديب الذكي');
    expect(
      find.text('مجاني بلا إعلانات ولا اشتراكات ولا حساب.'),
      findsOneWidget,
    );
  });

  testWidgets('الإنجليزية: كل الشاشات مترجمة', (tester) async {
    await openSettings(tester, locale: const Locale('en'));
    for (final t in [
      'General',
      'Appearance',
      'Reading',
      'Listening',
      'Ask Adeeb',
      'About',
    ]) {
      await tester.scrollUntilVisible(
        find.text(t),
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tapText(tester, 'Sources & licenses');
    expect(find.text('Books'), findsOneWidget);
    await back(tester);
    await tester.pumpAndSettle();
    await tapText(tester, 'Privacy policy');
    expect(find.text('No account'), findsOneWidget);
    await back(tester);
    await tester.pumpAndSettle();
    await tapText(tester, 'About Adeeb AI');
    expect(find.text('Adeeb AI logo'), findsNothing); // تسمية دلالية فقط
    expect(
      find.text('Free, with no ads, no subscriptions and no account.'),
      findsOneWidget,
    );
  });

  testWidgets('روابط OpenITI والترخيص موصوفة لقارئ الشاشة', (tester) async {
    final semantics = tester.ensureSemantics();
    await openSettings(tester);
    await tapText(tester, 'المصادر والتراخيص');
    expect(find.bySemanticsLabel('انسخ رابط مشروع OpenITI'), findsOneWidget);
    expect(
      find.bySemanticsLabel('انسخ رابط نص ترخيص CC BY-NC-SA 4.0'),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('أهداف اللمس 48dp وتسميات قارئ الشاشة في الإعدادات', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openSettings(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      tester.getSemantics(find.text('المظهر')),
      matchesSemantics(
        label: 'المظهر\nحسب الجهاز',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasFocusAction: true,
        hasSelectedState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('تكبير الخط 200%: بلا فيض في الشاشات الأربع', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await env.preinstall(miniBook());
    await openSettings(tester);
    expect(tester.takeException(), isNull);
    for (final row in [
      'المصادر والتراخيص',
      'سياسة الخصوصية',
      'عن الأديب الذكي',
    ]) {
      await tapText(tester, row);
      expect(tester.takeException(), isNull);
      await back(tester);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('إدارة الكتب المحمّلة: المساحة الكلية والحذف بعد التأكيد', (
    tester,
  ) async {
    final other = miniBook(id: 'other');
    env.server.catalog = catalogJson([
      env.server.addBook(miniBook()),
      env.server.addBook(other),
    ]);
    await env.preinstall(miniBook());
    await env.preinstall(other);
    final total = (await env.books.installed()).fold<int>(
      0,
      (n, b) => n + b.bytes,
    );
    expect(total, greaterThan(0));
    await openSettings(tester);
    await tapText(tester, 'إدارة الكتب المحمّلة');
    expect(find.byType(DownloadedBooksScreen), findsOneWidget);
    expect(find.text('تستخدم الكتب ١ ك.ب'), findsOneWidget);
    expect(find.text('كتاب اختبار اصطناعي'), findsNWidgets(2));

    await tester.tap(
      find.byTooltip('حذف «كتاب اختبار اصطناعي» من الجهاز').first,
    );
    await tester.pumpAndSettle();
    expect(find.text('حذف الكتاب من الجهاز؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await tester.pumpAndSettle();
    expect(find.text('حُذف الكتاب'), findsOneWidget);
    expect(find.text('كتاب اختبار اصطناعي'), findsOneWidget);
    expect(await env.books.installed(), hasLength(1));
  });
}
