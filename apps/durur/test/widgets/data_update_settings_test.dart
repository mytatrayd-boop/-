import 'dart:async';

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/app.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/settings/data_update_section.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/features/settings/sources_screen.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:durur/src/routing/app_router.dart';
import 'package:durur/src/updates/update_config.dart';
import 'package:durur/src/updates/update_fetcher.dart';
import 'package:durur/src/updates/update_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../updates/update_test_kit.dart';

/// واجهة تحديث البيانات (الميزة 11ب، DESIGN 8.7 و8.11، ARCHITECTURE §16.5):
/// قسم الإعدادات بحالاته، ورسالة «حُدّثت البيانات» مرة واحدة على أي شاشة،
/// وبطاقة نسخة البيانات في صفحة المصادر.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final embedded = await loadAssetTables();
  final signer = await TestSigner.generate();
  final release1 = await buildRelease(signer, 1);
  final otherSigner = await TestSigner.generate();
  final badRelease = await buildRelease(otherSigner, 1);
  final now = DateTime(2026, 10, 2, 10);

  late FakeFetcher fetcher;
  late MemoryUpdateStore store;

  setUp(() {
    fetcher = FakeFetcher();
    store = MemoryUpdateStore();
  });

  /// التحديث متاح (رابط ومفتاح)، والجداول تُحمَّل فعلاً (المضمّن + المثبّت).
  List<Override> enabled({
    UpdateFetcher? using,
    Map<String, String>? keys,
    DateTime Function()? clock,
  }) => [
    embeddedTablesLoaderProvider.overrideWithValue(() async => embedded),
    updateStoreProvider.overrideWithValue(store),
    updateFetcherProvider.overrideWithValue(using ?? fetcher),
    trustedKeysProvider.overrideWithValue(keys ?? signer.trustedKeys),
    updateConfigProvider.overrideWithValue(
      const UpdateConfig(baseUrl: 'https://example.test/durur-data'),
    ),
    appBuildProvider.overrideWith((ref) async => 1),
    appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
    clockProvider.overrideWithValue(clock ?? () => now),
  ];

  Future<void> pumpSettings(
    WidgetTester tester,
    SharedPreferences prefs, {
    List<Override>? extra,
    double textScale = 1,
  }) => pumpScreen(
    tester,
    const SettingsScreen(),
    prefs: prefs,
    tables: null,
    extra: extra ?? enabled(),
    textScale: textScale,
  );

  /// يمرّر قائمة الإعدادات حتى [finder].
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCheckNow(WidgetTester tester) async {
    await scrollTo(tester, find.byKey(DataUpdateSection.checkNowKey));
    await tester.tap(find.byKey(DataUpdateSection.checkNowKey));
    await tester.pumpAndSettle();
  }

  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(DataUpdateSection.statusKey)).data!;

  group('الإعدادات', () {
    testWidgets('غير متاح (البناء الافتراضي بلا رابط) ← القسم مخفي كاملاً', (
      tester,
    ) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      await pumpScreen(
        tester,
        const SettingsScreen(),
        prefs: prefs,
        tables: embedded,
        extra: [updateFetcherProvider.overrideWithValue(fetcher)],
      );
      expect(find.text(l10n.settingsSectionUpdate), findsNothing);
      expect(find.byKey(DataUpdateSection.autoSwitchKey), findsNothing);
      expect(find.byKey(DataUpdateSection.checkNowKey), findsNothing);
      expect(find.byKey(DataUpdateSection.statusKey), findsNothing);
      // بقية الإعدادات كما هي.
      await scrollTo(tester, find.text(l10n.settingsSectionHelp));
      expect(find.text(l10n.settingsSectionHelp), findsOneWidget);
      expect(find.text(l10n.settingsSectionUpdate), findsNothing);
    });

    testWidgets('بلا مفتاح موثوق (ثابت الإنتاج الحالي) ← مخفي', (tester) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      await pumpSettings(tester, prefs, extra: enabled(keys: const {}));
      expect(find.text(l10n.settingsSectionUpdate), findsNothing);
    });

    testWidgets(
      'متاح: العنوان بين «المظهر» و«البيانات والمساعدة»، المفتاح مفعّل، '
      'و«لم نتحقق بعد»',
      (tester) async {
        final prefs = await fakePrefs(savedCity('riyadh'));
        await pumpSettings(tester, prefs);
        await scrollTo(tester, find.byKey(DataUpdateSection.checkNowKey));
        final title = find.text(l10n.settingsSectionUpdate);
        expect(title, findsOneWidget);
        expect(
          tester.getTopLeft(title).dy,
          greaterThan(tester.getTopLeft(find.text(l10n.settingsDigits)).dy),
        );
        final sw = tester.widget<SwitchListTile>(
          find.byKey(DataUpdateSection.autoSwitchKey),
        );
        expect(sw.value, isTrue);
        expect(find.text(l10n.settingsUpdateAutoDesc), findsOneWidget);
        // نسخة البيانات المستخدمة بأرقام الإعداد (١٢٣ افتراضياً).
        expect(status(tester), 'نسخة البيانات: sample-١ — لم نتحقق بعد');
        expect(find.text(l10n.settingsUpdateCheckNow), findsOneWidget);
        expect(find.byKey(DataUpdateSection.resultKey), findsNothing);
        expect(fetcher.requests, isEmpty);
      },
    );

    testWidgets('إطفاء المفتاح يُحفظ بلا رسالة، ولا طلب', (tester) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      await pumpSettings(tester, prefs);
      await scrollTo(tester, find.byKey(DataUpdateSection.autoSwitchKey));
      await tester.tap(find.byKey(DataUpdateSection.autoSwitchKey));
      await tester.pumpAndSettle();
      expect(prefs.getBool(SettingsRepository.autoUpdateKey), isFalse);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(DataUpdateSection.autoSwitchKey))
            .value,
        isFalse,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(fetcher.requests, isEmpty);
    });

    testWidgets('«تحقق الآن» ← لا جديد: «بياناتك محدّثة.» والتاريخ «اليوم»', (
      tester,
    ) async {
      final prefs = await fakePrefs({
        ...savedCity('riyadh'),
        UpdateState.highestSeqKey: 1,
        UpdateState.lastCheckOkKey: DateTime(
          2026,
          9,
          1,
          9,
        ).millisecondsSinceEpoch,
        UpdateState.lastAttemptKey: DateTime(
          2026,
          9,
          1,
          9,
        ).millisecondsSinceEpoch,
      });
      fetcher.publish(release1, 1);
      await pumpSettings(tester, prefs);
      await scrollTo(tester, find.byKey(DataUpdateSection.statusKey));
      expect(
        status(tester),
        'نسخة البيانات: sample-١ — آخر تحقق: ١ سبتمبر ٢٠٢٦',
      );

      await tapCheckNow(tester);
      expect(fetcher.requests, hasLength(1)); // البيان فقط.
      expect(find.text(l10n.settingsUpdateUpToDate), findsOneWidget);
      expect(status(tester), 'نسخة البيانات: sample-١ — آخر تحقق: اليوم');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('آخر تحقق أمس ← «أمس»، وبأرقام 123 حسب الإعداد', (
      tester,
    ) async {
      final prefs = await fakePrefs({
        ...savedCity('riyadh'),
        SettingsRepository.digitsKey: 'latin',
        UpdateState.lastCheckOkKey: DateTime(
          2026,
          10,
          1,
          23,
        ).millisecondsSinceEpoch,
      });
      await pumpSettings(tester, prefs);
      await scrollTo(tester, find.byKey(DataUpdateSection.statusKey));
      expect(status(tester), 'نسخة البيانات: sample-1 — آخر تحقق: أمس');
    });

    testWidgets('تعذّر الاتصال ← سطر الخطأ، والحالة لا تتغير', (tester) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      fetcher.failure = FetchFailure.network;
      await pumpSettings(tester, prefs);
      await tapCheckNow(tester);
      expect(find.text(l10n.settingsUpdateNetworkError), findsOneWidget);
      expect(status(tester), 'نسخة البيانات: sample-١ — لم نتحقق بعد');
    });

    testWidgets('حزمة مرفوضة ← «تعذّر التحقق من التحديث…»', (tester) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      fetcher.publish(badRelease, 1);
      await pumpSettings(tester, prefs);
      await tapCheckNow(tester);
      expect(find.text(l10n.settingsUpdateVerifyError), findsOneWidget);
      expect(find.text(l10n.settingsUpdateNetworkError), findsNothing);
      expect(store.stored, isNull);
    });

    testWidgets('المفتاح مطفأ ← «تحقق الآن» يبقى متاحاً (طلب صريح)', (
      tester,
    ) async {
      final prefs = await fakePrefs({
        ...savedCity('riyadh'),
        SettingsRepository.autoUpdateKey: false,
      });
      fetcher.publish(release1, 1);
      await pumpSettings(tester, prefs);
      expect(fetcher.requests, isEmpty);
      await tapCheckNow(tester);
      expect(fetcher.requests, hasLength(2));
    });

    testWidgets(
      'جارٍ التحقق: مؤشر ونص «جارٍ التحقق…»، الزر لا يستجيب، ويُمسح السطر السابق',
      (tester) async {
        final prefs = await fakePrefs(savedCity('riyadh'));
        final gated = GatedFetcher(fetcher)
          ..inner.failure = FetchFailure.network;
        await pumpSettings(tester, prefs, extra: enabled(using: gated));
        gated.gate.complete();
        await tapCheckNow(tester);
        expect(find.text(l10n.settingsUpdateNetworkError), findsOneWidget);

        gated.gate = Completer<void>();
        fetcher.failure = null;
        await tester.tap(find.byKey(DataUpdateSection.checkNowKey));
        await tester.pump();
        expect(find.text(l10n.settingsUpdateChecking), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(DataUpdateSection.resultKey), findsNothing);
        final button = find.byKey(DataUpdateSection.checkNowKey);
        expect(tester.widget<ButtonStyleButton>(button).enabled, isFalse);
        await tester.tap(button, warnIfMissed: false);
        await tester.pump();

        gated.gate.complete();
        await tester.pumpAndSettle();
        // الضغطة الثانية لم ترسل طلباً: محاولة أولى (1) + الثانية (بيان 404).
        expect(fetcher.requests, hasLength(2));
        expect(find.text(l10n.settingsUpdateCheckNow), findsOneWidget);
      },
    );

    testWidgets('مغادرة الإعدادات تمسح سطر النتيجة', (tester) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      fetcher.failure = FetchFailure.network;
      await pumpSettings(tester, prefs);
      await tapCheckNow(tester);
      expect(find.byKey(DataUpdateSection.resultKey), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // مغادرة الشاشة.
      await pumpSettings(tester, prefs);
      await scrollTo(tester, find.byKey(DataUpdateSection.checkNowKey));
      expect(find.byKey(DataUpdateSection.resultKey), findsNothing);
    });

    testWidgets('قارئ الشاشة و48dp: المفتاح عنصر واحد بعنوانه ووصفه وحالته', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final prefs = await fakePrefs(savedCity('riyadh'));
      fetcher.failure = FetchFailure.network;
      await pumpSettings(tester, prefs);
      await tapCheckNow(tester);
      await scrollTo(tester, find.byKey(DataUpdateSection.autoSwitchKey));
      final sw = tester.getSemantics(
        find.byKey(DataUpdateSection.autoSwitchKey),
      );
      expect(sw.label, contains(l10n.settingsUpdateAuto));
      expect(sw.label, contains(l10n.settingsUpdateAutoDesc));
      expect(sw.flagsCollection.isToggled, isNotNull);
      expect(
        tester.getSize(find.byKey(DataUpdateSection.autoSwitchKey)).height,
        greaterThanOrEqualTo(64),
      );
      expect(
        tester.getSize(find.byKey(DataUpdateSection.checkNowKey)).height,
        greaterThanOrEqualTo(52),
      );
      // سطر النتيجة منطقة حيّة.
      expect(
        find.ancestor(
          of: find.text(l10n.settingsUpdateNetworkError),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.liveRegion ?? false),
          ),
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('تكبير الخط 200% بلا قص ولا تداخل', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final prefs = await fakePrefs(savedCity('riyadh'));
      fetcher.failure = FetchFailure.network;
      await pumpSettings(tester, prefs, textScale: 2);
      await tapCheckNow(tester);
      await scrollTo(tester, find.byKey(DataUpdateSection.resultKey));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settingsUpdateNetworkError), findsOneWidget);
    });
  });

  group('رسالة «حُدّثت البيانات» (على أي شاشة، مرة واحدة)', () {
    Future<ProviderContainer> pumpApp(
      WidgetTester tester,
      SharedPreferences prefs,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(prefs, null, enabled()),
          child: const DururApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    }

    /// تحقق سابق قبل يوم (لا تحقق تلقائي عند الفتح).
    Map<String, Object> checkedYesterday() => {
      ...savedCity('riyadh'),
      UpdateState.lastCheckOkKey: DateTime(
        2026,
        10,
        1,
        10,
      ).millisecondsSinceEpoch,
      UpdateState.lastAttemptKey: DateTime(
        2026,
        10,
        1,
        10,
      ).millisecondsSinceEpoch,
    };

    Finder updatedMessage() => find.text(l10n.settingsUpdateUpdated);

    testWidgets('التحقق التلقائي عند الفتح ← الرسالة على الرئيسية مرة واحدة', (
      tester,
    ) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      fetcher.publish(release1, 1);
      final c = await pumpApp(tester, prefs);
      expect(fetcher.requests, hasLength(2));
      expect(c.read(tablesProvider).value!.meta.dataSeq, 1);
      expect(updatedMessage(), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, greaterThanOrEqualTo(const Duration(seconds: 6)));
      expect(bar.action, isNull);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(updatedMessage(), findsNothing);
      // تحقق لاحق بلا جديد لا يعيدها.
      await c.read(dataUpdateProvider.notifier).checkNow();
      await tester.pumpAndSettle();
      expect(updatedMessage(), findsNothing);
    });

    testWidgets(
      '«تحقق الآن» ← رسالة واحدة بلا سطر نتيجة، والحالة بالنسخة الجديدة و«اليوم»',
      (tester) async {
        final prefs = await fakePrefs(checkedYesterday());
        fetcher.publish(release1, 1);
        await pumpApp(tester, prefs);
        expect(fetcher.requests, isEmpty);
        GoRouter.of(tester.element(find.byType(HomeScreen)))
            .push(AppRoutes.settings);
        await tester.pumpAndSettle();
        await scrollTo(tester, find.byKey(DataUpdateSection.statusKey));
        expect(status(tester), 'نسخة البيانات: sample-١ — آخر تحقق: أمس');

        await tapCheckNow(tester);
        expect(updatedMessage(), findsOneWidget);
        expect(find.byKey(DataUpdateSection.resultKey), findsNothing);
        await scrollTo(tester, find.byKey(DataUpdateSection.statusKey));
        expect(status(tester), 'نسخة البيانات: test-١ — آخر تحقق: اليوم');
      },
    );

    testWidgets('حوار مفتوح ← تنتظر حتى يُغلق', (tester) async {
      final prefs = await fakePrefs(checkedYesterday());
      fetcher.publish(release1, 1);
      final c = await pumpApp(tester, prefs);
      final context = tester.element(find.byType(HomeScreen));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('حوار')),
      );
      await tester.pumpAndSettle();

      await c.read(dataUpdateProvider.notifier).checkNow();
      await tester.pumpAndSettle();
      expect(c.read(dataUpdateProvider).acceptedCount, 1);
      expect(updatedMessage(), findsNothing);

      Navigator.of(tester.element(find.text('حوار'))).pop();
      await tester.pumpAndSettle();
      expect(updatedMessage(), findsOneWidget);
    });

    testWidgets('التطبيق في الخلفية لحظة القبول ← لا تظهر لاحقاً', (
      tester,
    ) async {
      final prefs = await fakePrefs(checkedYesterday());
      fetcher.publish(release1, 1);
      final c = await pumpApp(tester, prefs);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await c.read(dataUpdateProvider.notifier).checkNow();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(c.read(dataUpdateProvider).acceptedCount, 1);
      expect(updatedMessage(), findsNothing);
    });

    testWidgets(
      '§16.9 المفتاح مطفأ ← لا طلب شبكة عند الفتح ولا عند العودة بعد شهر',
      (tester) async {
        var clock = now;
        final prefs = await fakePrefs({
          ...savedCity('riyadh'),
          SettingsRepository.autoUpdateKey: false,
        });
        fetcher.publish(release1, 1);
        await tester.pumpWidget(
          ProviderScope(
            overrides: appOverrides(prefs, null, enabled(clock: () => clock)),
            child: const DururApp(),
          ),
        );
        await tester.pumpAndSettle();
        clock = clock.add(const Duration(days: 30));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(fetcher.requests, isEmpty);
        expect(UpdateState(prefs).lastAttempt, isNull);
        expect(updatedMessage(), findsNothing);
      },
    );
  });

  group('صفحة المصادر: بطاقة نسخة البيانات', () {
    String cardText(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(SourcesScreen.dataCardKey),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join('\n');

    testWidgets('المضمّنة ← «البيانات المرفقة مع نسخة التطبيق …» ثم النسخة', (
      tester,
    ) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      await pumpScreen(
        tester,
        const SourcesScreen(),
        prefs: prefs,
        tables: null,
        extra: enabled(),
      );
      expect(
        cardText(tester),
        'البيانات المرفقة مع نسخة التطبيق ١.٠.٠+١\n'
        'نسخة البيانات: sample-١ (٠)',
      );
    });

    testWidgets('المنزّلة ← «آخر تحديث للبيانات: {publishedAt}»، وعنصر واحد', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final prefs = await fakePrefs({
        ...savedCity('riyadh'),
        UpdateState.highestSeqKey: 1,
      });
      await store.install(1, release1.manifest, release1.bundle);
      await pumpScreen(
        tester,
        const SourcesScreen(),
        prefs: prefs,
        tables: null,
        extra: enabled(),
      );
      expect(
        cardText(tester),
        'آخر تحديث للبيانات: ٢ أكتوبر ٢٠٢٦\nنسخة البيانات: test-١ (١)',
      );
      final node = tester.getSemantics(
        find.text('آخر تحديث للبيانات: ٢ أكتوبر ٢٠٢٦'),
      );
      expect(node.label, contains('نسخة البيانات: test-١ (١)'));
      handle.dispose();
    });

    testWidgets('تعذّر تحديد المصدر ← سطر النسخة وحده (والتحديث غير متاح)', (
      tester,
    ) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      await pumpScreen(
        tester,
        const SourcesScreen(),
        prefs: prefs,
        tables: embedded,
        extra: [
          updateStoreProvider.overrideWithValue(
            UpdateStore(() async => throw UnsupportedError('x')),
          ),
        ],
      );
      expect(cardText(tester), 'نسخة البيانات: sample-١ (٠)');
    });
  });
}
