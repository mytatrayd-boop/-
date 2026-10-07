import 'dart:io';
import 'dart:math' as math;

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/app.dart';
import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:durur/src/features/home/dial/day_dial.dart';
import 'package:durur/src/features/home/home_cards.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/item_detail/item_detail_page.dart';
import 'package:durur/src/features/item_detail/item_detail_sheet.dart';
import 'package:durur/src/features/onboarding/location_screen.dart';
import 'package:durur/src/features/onboarding/notifications_intro_screen.dart';
import 'package:durur/src/features/onboarding/welcome_screen.dart';
import 'package:durur/src/features/report/report_sheet.dart';
import 'package:durur/src/features/settings/data_update_section.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/features/settings/sources_screen.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:durur/src/updates/update_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_location_service.dart';

/// الميزة 10 (SPEC معيار 1–3، 5–6): المرور بالتطبيق كاملاً **بلا شبكة**:
/// البداية ← اختيار مدينة ← الرئيسية والدائرة ← صفحة نجم ← الإعدادات ←
/// المصادر ← البلاغ (نسخ). المحجوب هنا فعلاً: كل `HttpClient` (عبر
/// `HttpOverrides`) و`Socket.connect`/`Socket.startConnect` (عبر `IOOverrides`)،
/// وكلاهما يرمي ويُسجَّل. لا يُحجب هنا: RawSocket وSecureSocket
/// وRawSecureSocket وRawDatagramSocket وWebSocket وInternetAddress.lookup
/// ولا ما تفعله البلجنات الأصلية؛ غياب الأولى من lib/ يثبته الفحص الثابت
/// `test/compliance/network_apis_test.dart`، والبلجنات تُختبر على جهاز
/// (TESTERS.md). يثبت: لا طلب شبكة إطلاقاً في البناء الافتراضي
/// (التحديث معطّل بلا رابط ومفتاح)، ومع تفعيل التحديث لا طلب إلا
/// `GET <base>/v1/manifest.json`، وفشله صامت، ولا يتعطل شيء. وفي كل شاشة:
/// الاتجاه من اليمين لليسار ولا نص إنجليزي ظاهر أو مسموع (قارئ الشاشة).
///
/// ما يبقى مستبدلاً هو ما لا يعمل بلا جهاز أصلاً: المُجدوِل (بلجن التنبيهات)
/// وخدمة الموقع (GPS، لا تحتاج إنترنت). الجداول تُحمَّل بالمحمّل الحقيقي
/// `tablesProvider` (المضمّن مقروءاً من assets/tables، ومخزن التحديث الحقيقي
/// بلا مجلد دعم كما على جهاز لم يُحدَّث قط).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final now = DateTime(2026, 10, 2, 9, 30);

  /// نصوص لاتينية مسموحة لأنها **بيانات أو إسناد** لا نصوص واجهة: عناوين
  /// المصادر المنشورة (قد تكون بلغتها)، ونسخة البيانات التقنية، وإسناد رخصة
  /// GeoNames (CC BY 4.0 يشترط ذكر الاسم والرخصة) وجداول van Gent.
  final allowedLatin = <String>{
    ...sourceTitles(),
    tables.meta.dataVersion,
    // تُعرض بأرقام المستخدم (١٢٣ افتراضياً).
    tables.meta.dataVersion.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
    ),
    'GeoNames',
    'geonames.org',
    'CC BY 4.0',
    'R. H. van Gent',
  }.toList()..sort((a, b) => b.length.compareTo(a.length));

  late NetworkLog network;
  final pathCalls = <String>[];
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late List<String> clipboard;

  setUp(() {
    network = NetworkLog();
    clipboard = [];
    PackageInfo.setMockInitialValues(
      appName: 'durur',
      packageName: 'com.durur.durur',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  /// يحجب الشبكة ويلتقط الحافظة طوال الاختبار.
  void blockNetwork(WidgetTester tester) {
    final previousHttp = HttpOverrides.current;
    final previousIo = IOOverrides.current;
    HttpOverrides.global = BlockedHttpOverrides(network);
    IOOverrides.global = BlockedIOOverrides(network);
    addTearDown(() {
      HttpOverrides.global = previousHttp;
      IOOverrides.global = previousIo;
    });
    // مجلد دعم التطبيق: فارغ، كجهاز لم يُنزّل أي تحديث.
    final support = Directory.systemTemp.createTempSync('durur_offline_');
    addTearDown(() => support.deleteSync(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async {
        pathCalls.add(call.method);
        return support.path;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        null,
      ),
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
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
  }

  void tallPhone(WidgetTester tester) {
    // طويلة لتُبنى قوائم الإعدادات والمصادر كاملة فيُفحص كل نصها.
    tester.view.physicalSize = const Size(411, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<SharedPreferences> openApp(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    List<Override> extra = const [],
  }) async {
    final prefs = await fakePrefs(saved);
    await tester.pumpWidget(
      ProviderScope(
        // tablesProvider غير مستبدل: المحمّل الحقيقي مع المضمّن.
        overrides: appOverrides(prefs, null, [
          embeddedTablesLoaderProvider.overrideWithValue(() async => tables),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          fixedClock(now),
          ...extra,
        ]),
        child: const DururApp(),
      ),
    );
    // الجداول تُحمَّل بإدخال وإخراج حقيقيين (مخزن التحديث)، خارج الوقت الوهمي.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DururApp)),
    );
    await settleIo(tester, () => container.read(tablesProvider).hasValue);
    return prefs;
  }

  /// كل ما يُرى أو يُسمع الآن: نصوص الشاشة وكل نصوص شجرة قارئ الشاشة.
  List<String> visibleTexts(WidgetTester tester) {
    final texts = <String>[
      for (final w in tester.allWidgets)
        if (w is RichText) w.text.toPlainText(),
      for (final w in tester.allWidgets)
        if (w is EditableText) w.controller.text,
    ];
    void visit(SemanticsNode node) {
      final d = node.getSemanticsData();
      texts.addAll([
        d.label,
        d.value,
        d.hint,
        d.increasedValue,
        d.decreasedValue,
        d.tooltip,
      ]);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    for (final view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    return texts.where((t) => t.trim().isNotEmpty).toList();
  }

  /// فحص الشاشة الحالية: الاتجاه RTL في كل الشجرة، ولا حرف لاتيني خارج
  /// المسموح، ولا خطأ.
  void checkScreen(WidgetTester tester, String screen) {
    expect(tester.takeException(), isNull, reason: screen);
    final directions = tester
        .widgetList<Directionality>(find.byType(Directionality))
        .map((d) => d.textDirection)
        .toSet();
    expect(directions, {TextDirection.rtl}, reason: '$screen: الاتجاه');
    final texts = visibleTexts(tester);
    expect(texts, isNotEmpty, reason: screen);
    for (final text in texts) {
      var rest = text;
      for (final allowed in allowedLatin) {
        rest = rest.replaceAll(allowed, '');
      }
      expect(
        RegExp('[A-Za-z]').hasMatch(rest),
        isFalse,
        reason: '$screen: نص لاتيني ظاهر للمستخدم: "$text"',
      );
    }
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// [fraction] من نصف القطر (DESIGN R2.5)؛ الطوالع 0.505.
  Offset dialPoint(WidgetTester tester, double fraction, double degrees) {
    final c = tester.getCenter(find.byKey(DayDial.dialKey));
    final r = tester.getSize(find.byKey(DayDial.dialKey)).width / 2;
    final rr = fraction * r;
    final a = degrees * math.pi / 180;
    return c + Offset(rr * math.sin(a), -rr * math.cos(a));
  }

  /// الرئيسية والدائرة ← ورقة النجم من الدائرة ← صفحة النجم الكاملة من
  /// البطاقة ← الإعدادات ← المصادر ← البلاغ (نسخ).
  Future<void> walkFromHome(WidgetTester tester, String cityId) async {
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(DayDial.dialKey), findsOneWidget);
    expect(find.byKey(HomeScreen.datesLineKey), findsOneWidget);
    expect(find.byKey(HomeScreen.loadErrorKey), findsNothing);
    expect(find.byKey(HomeScreen.calcErrorKey), findsNothing);
    final dial = tester
        .getSemantics(find.byKey(DayDial.dialKey))
        .getSemanticsData();
    expect(dial.value, contains(l10n.wheelA11yStar('').split(':').first));
    checkScreen(tester, 'الرئيسية');

    // الدائرة: حلقة النجم ← ورقته.
    await tester.tapAt(dialPoint(tester, 0.505, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final sheet = find.byKey(ItemDetailSheet.sheetKey);
    expect(sheet, findsOneWidget);
    checkScreen(tester, 'ورقة النجم');
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    // صفحة النجم الكاملة من البطاقة.
    await scrollHomeTo(tester, find.byKey(HomeCardKeys.starCard));
    await tester.tap(find.byKey(HomeCardKeys.starCard));
    await tester.pumpAndSettle();
    expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
    expect(find.byKey(ItemDetailPage.loadErrorKey), findsNothing);
    checkScreen(tester, 'صفحة النجم');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // الإعدادات.
    await tester.tap(find.byTooltip(l10n.settingsTitle));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    checkScreen(tester, 'الإعدادات');

    // المصادر.
    await tapKey(tester, SettingsScreen.sourcesRowKey);
    expect(find.byKey(SourcesScreen.screenKey), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(SourcesScreen.screenKey)),
    );
    await settleIo(tester, () => container.read(dataOriginProvider).hasValue);
    expect(container.read(dataOriginProvider).value, isA<BundledData>());
    expect(find.byKey(SourcesScreen.dataCardKey), findsOneWidget);
    checkScreen(tester, 'المصادر');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // البلاغ: «نسخ تفاصيل البلاغ» (لا رابط نموذج في البناء الافتراضي).
    await tapKey(tester, SettingsScreen.reportRowKey);
    expect(find.byKey(ReportSheet.sheetKey), findsOneWidget);
    expect(find.byKey(ReportSheet.openFormKey), findsNothing);
    checkScreen(tester, 'البلاغ');
    await tapKey(tester, ReportSheet.copyKey);
    expect(find.text(l10n.reportDetailsCopied), findsOneWidget);
    expect(clipboard, hasLength(1));
    expect(
      clipboard.single,
      contains(l10n.reportRegion(
        tables.region(tables.city(cityId)!.regionId)!.name.ar,
      )),
    );
    checkScreen(tester, 'البلاغ بعد النسخ');
  }

  testWidgets(
    'البناء الافتراضي بلا شبكة: من أول تشغيل حتى البلاغ، بلا أي طلب شبكة',
    (tester) async {
      tallPhone(tester);
      final handle = tester.ensureSemantics();
      blockNetwork(tester);
      final prefs = await openApp(tester);

      // البداية.
      expect(find.byType(WelcomeScreen), findsOneWidget);
      checkScreen(tester, 'الترحيب');
      await tapKey(tester, WelcomeScreen.startKey);
      expect(find.byType(LocationScreen), findsOneWidget);
      checkScreen(tester, 'الموقع');

      // اختيار مدينة يدوياً.
      await tapKey(tester, LocationScreen.manualKey);
      expect(find.byType(CityPickerScreen), findsOneWidget);
      checkScreen(tester, 'قائمة المدن');
      await tester.enterText(
        find.byKey(CityPickerScreen.searchFieldKey),
        tables.city('kuwait_city')!.name.ar,
      );
      await tester.pumpAndSettle();
      checkScreen(tester, 'البحث في المدن');
      await tapKey(tester, CityPickerScreen.cityTileKey('kuwait_city'));

      // شرح التنبيهات ← «ليس الآن».
      expect(find.byType(NotificationsIntroScreen), findsOneWidget);
      checkScreen(tester, 'شرح التنبيهات');
      await tapKey(tester, NotificationsIntroScreen.notNowKey);
      expect(prefs.getBool(SettingsRepository.onboardingDoneKey), isTrue);

      // بعد الإعداد الأولي: لا شيء ينتظر الشبكة.
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      await walkFromHome(tester, 'kuwait_city');

      // قسم «تحديث البيانات» مخفي: لا رابط ولا مفتاح موثوق.
      expect(find.byKey(DataUpdateSection.autoSwitchKey), findsNothing);
      expect(find.byKey(DataUpdateSection.checkNowKey), findsNothing);

      // العودة للواجهة (موعد التحقق التلقائي) بلا أي طلب أيضاً.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(network.httpClients, 0, reason: '${network.requests}');
      expect(network.requests, isEmpty);
      expect(network.sockets, isEmpty);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets(
    'التحديث مفعّل والشبكة محجوبة: الطلب الوحيد GET للبيان، وفشله صامت، '
    'والتطبيق يعمل كاملاً',
    (tester) async {
      tallPhone(tester);
      final handle = tester.ensureSemantics();
      blockNetwork(tester);
      const base = 'https://example.test/durur-data';
      final manifest = Uri.parse('$base/v1/manifest.json');
      // updateFetcherProvider غير مستبدل: HttpUpdateFetcher الحقيقي.
      await openApp(
        tester,
        saved: savedCity('kuwait_city'),
        extra: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(baseUrl: base),
          ),
          trustedKeysProvider.overrideWithValue({
            'test': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          }),
        ],
      );

      // التحقق بعد أول إطار: طلب واحد للبيان، فشل شبكة بلا أي رسالة.
      await tester.pumpAndSettle();
      expect(network.requests, [('GET', manifest)]);
      expect(find.byType(SnackBar), findsNothing);
      await walkFromHome(tester, 'kuwait_city');

      // «تحقق الآن» في الإعدادات: طلب صريح للبيان نفسه ورسالة الشبكة.
      Navigator.of(tester.element(find.byKey(ReportSheet.sheetKey))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byKey(DataUpdateSection.autoSwitchKey), findsOneWidget);
      await tapKey(tester, DataUpdateSection.checkNowKey);
      expect(find.text(l10n.settingsUpdateNetworkError), findsOneWidget);
      checkScreen(tester, 'الإعدادات بعد «تحقق الآن» بلا إنترنت');

      expect(network.requests, [('GET', manifest), ('GET', manifest)]);
      expect(network.sockets, isEmpty);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );
}

/// ينتظر إدخالاً وإخراجاً حقيقيين (ملفات مخزن التحديث) خارج الوقت الوهمي
/// حتى يتحقق [done].
Future<void> settleIo(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
  await tester.pumpAndSettle();
}

/// كل عناوين المصادر في assets/tables (بيانات، قد تكون بلغة المصدر).
Set<String> sourceTitles() {
  final titles = <String>{};
  final files = Directory('assets/tables')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'));
  final re = RegExp(r'"title"\s*:\s*"((?:[^"\\]|\\.)*)"');
  for (final f in files) {
    for (final m in re.allMatches(f.readAsStringSync())) {
      titles.add(m.group(1)!);
    }
  }
  return titles;
}

/// سجل كل محاولة شبكة.
class NetworkLog {
  int httpClients = 0;
  final requests = <(String, Uri)>[];
  final sockets = <String>[];
}

class BlockedHttpOverrides extends HttpOverrides {
  BlockedHttpOverrides(this.log);

  final NetworkLog log;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    log.httpClients++;
    return _BlockedHttpClient(log);
  }
}

/// `HttpClient` بلا شبكة: كل طلب يُسجَّل ويفشل كما في وضع الطيران.
class _BlockedHttpClient implements HttpClient {
  _BlockedHttpClient(this.log);

  final NetworkLog log;

  Future<HttpClientRequest> _fail(String method, Uri url) {
    log.requests.add((method, url));
    return Future.error(
      SocketException('وضع الطيران (اختبار)', address: null),
    );
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _fail(method, url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _fail('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _fail('POST', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _fail('HEAD', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _fail('PUT', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter || invocation.isGetter) return null;
    // أي طريقة طلب أخرى (get/open/…) محجوبة أيضاً وتُسجَّل.
    log.requests.add((invocation.memberName.toString(), Uri()));
    throw const SocketException('وضع الطيران (اختبار)');
  }
}

/// يحجب أي اتصال `Socket` مباشر خارج HttpClient.
final class BlockedIOOverrides extends IOOverrides {
  BlockedIOOverrides(this.log);

  final NetworkLog log;

  @override
  Future<Socket> socketConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    log.sockets.add('$host:$port');
    return Future.error(const SocketException('وضع الطيران (اختبار)'));
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
  }) {
    log.sockets.add('$host:$port');
    return Future.error(const SocketException('وضع الطيران (اختبار)'));
  }
}
