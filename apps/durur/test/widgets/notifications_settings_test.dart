import 'package:durur/src/app.dart';
import 'package:durur/src/features/about/origin_screen.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/item_detail/detail_data.dart';
import 'package:durur/src/features/item_detail/item_detail_page.dart';
import 'package:durur/src/features/item_detail/item_detail_view.dart';
import 'package:durur/src/features/onboarding/notifications_intro_screen.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/features/shell/app_shell.dart';
import 'package:durur/src/formatting/digits.dart';
import 'package:durur/src/location/location_service.dart';
import 'package:durur/src/notifications/notification_planner.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_location_service.dart';
import '../helpers/fake_notification_scheduler.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  void phone(WidgetTester tester, {double width = 411, double height = 900}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<SharedPreferences> openApp(
    WidgetTester tester,
    FakeNotificationScheduler scheduler, {
    Map<String, Object>? saved,
    double textScale = 1,
    List<Override> extra = const [],
  }) async {
    phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final prefs = await fakePrefs(saved ?? savedCity('kuwait_city'));
    await pumpDururApp(
      tester,
      prefs: prefs,
      tables: tables,
      extra: [
        fakeScheduler(scheduler),
        fixedClock(DateTime(2026, 10, 2, 10)),
        ...extra,
      ],
    );
    return prefs;
  }

  /// يمرّر القائمة حتى يُبنى العنصر (ListView يبني الظاهر فقط).
  Future<void> reveal(WidgetTester tester, Key key) async {
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(find.byKey(key));
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await reveal(tester, key);
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();
  }

  String currentPath(WidgetTester tester) => GoRouterState.of(
    tester.element(find.byKey(ItemDetailPage.pageKey).last),
  ).uri.toString();

  group('شرح التنبيهات في البداية (DESIGN 8.2 د، SPEC 8 معيار 8)', () {
    final afterCity = {SettingsRepository.cityIdKey: 'kuwait_city'};

    testWidgets('مدينة محفوظة بلا انتهاء الإعداد ← الشرح بسطر السبب، بلا طلب',
        (tester) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(tester, scheduler, saved: afterCity);
      expect(find.byType(NotificationsIntroScreen), findsOneWidget);
      expect(find.text('لا يفوتك الوسم'), findsOneWidget);
      expect(
        find.text(
          'نذكّرك الساعة ٨ صباحاً عند دخول المواسم المهمة: سهيل، والوسم، '
          'والمربعانية، وبرد العجايز، والثريا، وجمرة القيظ.',
        ),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(find.byType(NotificationsIntroScreen))),
        TextDirection.rtl,
      );
      expect(scheduler.permissionRequests, 0);
    });

    for (final grant in [true, false]) {
      testWidgets('«فعّل التنبيهات» ← طلب الإذن (${grant ? 'قبول' : 'رفض'}) '
          '← الرئيسية، وينتهي الإعداد الأولي', (tester) async {
        final scheduler = FakeNotificationScheduler(grantOnRequest: grant);
        final prefs = await openApp(tester, scheduler, saved: afterCity);
        await tapKey(tester, NotificationsIntroScreen.allowKey);
        expect(scheduler.permissionRequests, 1);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(prefs.getBool(SettingsRepository.onboardingDoneKey), isTrue);
        // المفتاح يبقى مفعّلاً في الحالتين؛ والملاحظة مع الرفض فقط.
        await openSettings(tester);
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(SettingsScreen.importantSwitchKey),
              )
              .value,
          isTrue,
        );
        expect(
          find.byKey(SettingsScreen.permissionNoteKey),
          grant ? findsNothing : findsOneWidget,
        );
      });
    }

    testWidgets('«ليس الآن» ← الرئيسية بلا طلب، والملاحظة في الإعدادات', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(tester, scheduler, saved: afterCity);
      await tapKey(tester, NotificationsIntroScreen.notNowKey);
      expect(scheduler.permissionRequests, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      await openSettings(tester);
      expect(find.text('التنبيهات متوقفة من إعدادات جهازك.'), findsOneWidget);
    });

    testWidgets('خط 200% على 320dp بلا فيضان، وأهداف 48dp', (tester) async {
      final handle = tester.ensureSemantics();
      await openApp(
        tester,
        FakeNotificationScheduler(),
        saved: afterCity,
        textScale: 2,
      );
      phone(tester, width: 320, height: 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final k in [
        NotificationsIntroScreen.allowKey,
        NotificationsIntroScreen.notNowKey,
      ]) {
        await tester.ensureVisible(find.byKey(k));
        expect(tester.getSize(find.byKey(k)).height, greaterThanOrEqualTo(48));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('الإعدادات: قسم التنبيهات (DESIGN 8.7)', () {
    testWidgets('المفتاحان بقيمهما الافتراضية ووصفهما وسطر الساعة', (
      tester,
    ) async {
      await openApp(tester, FakeNotificationScheduler(permitted: true));
      await openSettings(tester);
      final important = tester.widget<SwitchListTile>(
        find.byKey(SettingsScreen.importantSwitchKey),
      );
      final dar = tester.widget<SwitchListTile>(
        find.byKey(SettingsScreen.darSwitchKey),
      );
      expect(important.value, isTrue);
      expect(dar.value, isFalse);
      expect(find.text('المواسم المهمة'), findsOneWidget);
      expect(
        find.text('سهيل، الوسم، المربعانية، برد العجايز، الثريا، جمرة القيظ.'),
        findsOneWidget,
      );
      expect(find.text('بداية كل دَرّ'), findsOneWidget);
      expect(
        find.text('تصل التنبيهات الساعة ٨:٠٠ صباحاً بتوقيت جهازك.'),
        findsOneWidget,
      );
      expect(find.byKey(SettingsScreen.permissionNoteKey), findsNothing);
    });

    testWidgets('تشغيل «بداية كل دَرّ»: يُحفظ، ويعيد الجدولة، والآخر كما هو', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler(permitted: true);
      final prefs = await openApp(tester, scheduler);
      expect(scheduler.pending, hasLength(6));
      await openSettings(tester);
      await tapKey(tester, SettingsScreen.darSwitchKey);
      expect(prefs.getBool(SettingsRepository.notifyDarKey), isTrue);
      expect(scheduler.pending, hasLength(6 + 37));
      expect(scheduler.permissionRequests, 0); // الإذن ممنوح أصلاً

      await tapKey(tester, SettingsScreen.importantSwitchKey);
      expect(prefs.getBool(SettingsRepository.notifyImportantKey), isFalse);
      expect(
        scheduler.pending.every((n) => n.kind == NotificationKind.dar),
        isTrue,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(SettingsScreen.darSwitchKey))
            .value,
        isTrue,
      );
    });

    testWidgets('الإذن مرفوض: ملاحظة و«فتح إعدادات الجهاز»؛ تشغيل مفتاح يطلب '
        'الإذن مرة، والاختيار يُحفظ حتى مع الرفض', (tester) async {
      final scheduler = FakeNotificationScheduler(grantOnRequest: false);
      final prefs = await openApp(tester, scheduler);
      await openSettings(tester);
      expect(find.byKey(SettingsScreen.permissionNoteKey), findsOneWidget);
      await tapKey(tester, SettingsScreen.openDeviceSettingsKey);
      expect(scheduler.settingsOpened, 1);

      await tapKey(tester, SettingsScreen.darSwitchKey);
      expect(scheduler.permissionRequests, 1);
      expect(prefs.getBool(SettingsRepository.notifyDarKey), isTrue);
      expect(find.byKey(SettingsScreen.permissionNoteKey), findsOneWidget);

      // منح الإذن ثم تشغيل: تختفي الملاحظة.
      scheduler.grantOnRequest = true;
      await tapKey(tester, SettingsScreen.darSwitchKey); // إطفاء: بلا طلب
      expect(scheduler.permissionRequests, 1);
      await tapKey(tester, SettingsScreen.darSwitchKey); // تشغيل: طلب
      expect(scheduler.permissionRequests, 2);
      expect(find.byKey(SettingsScreen.permissionNoteKey), findsNothing);
    });

    testWidgets('فشل الجدولة ← «تعذّر ضبط التنبيهات…»', (tester) async {
      await openApp(
        tester,
        FakeNotificationScheduler(permitted: true, failSchedule: true),
      );
      await openSettings(tester);
      expect(
        find.text('تعذّر ضبط التنبيهات. أعد فتح التطبيق وحاول مرة أخرى.'),
        findsOneWidget,
      );
    });

    testWidgets('خط 200% على 320dp بلا فيضان، وأهداف 48dp', (tester) async {
      final handle = tester.ensureSemantics();
      await openApp(tester, FakeNotificationScheduler(), textScale: 2);
      phone(tester, width: 320, height: 640);
      await openSettings(tester);
      // بترتيب الظهور (التمرير لأسفل فقط).
      for (final k in [
        SettingsScreen.openDeviceSettingsKey,
        SettingsScreen.importantSwitchKey,
        SettingsScreen.darSwitchKey,
        SettingsScreen.digitsChipKey(DigitStyle.latin),
      ]) {
        await reveal(tester, k);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(k)).height, greaterThanOrEqualTo(48));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('قارئ الشاشة: المفتاح يُقرأ بعنوانه وحالته', (tester) async {
      final handle = tester.ensureSemantics();
      await openApp(tester, FakeNotificationScheduler(permitted: true));
      await openSettings(tester);
      expect(
        tester.getSemantics(find.byKey(SettingsScreen.importantSwitchKey)),
        matchesSemantics(
          label: 'المواسم المهمة\nسهيل، الوسم، المربعانية، برد العجايز، '
              'الثريا، جمرة القيظ.',
          hasToggledState: true,
          isToggled: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('الإعدادات: المظهر (DESIGN 8.7)', () {
    testWidgets('السمة داكنة فقط (D38): لا صف «السمة»، ووضع الجهاز يُتجاهل', (
      tester,
    ) async {
      await openApp(tester, FakeNotificationScheduler());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.theme!.brightness, Brightness.dark);
      expect(app.darkTheme!.brightness, Brightness.dark);
      await openSettings(tester);
      expect(find.text('المظهر'), findsOneWidget);
      for (final gone in ['السمة', 'تلقائي (حسب الجهاز)', 'فاتح', 'داكن']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('الأرقام: ١٢٣ افتراضياً، و123 تغيّر أرقام الرئيسية والإعدادات', (
      tester,
    ) async {
      final prefs = await openApp(tester, FakeNotificationScheduler());
      expect(find.textContaining('٢٠٢٦'), findsWidgets);
      await openSettings(tester);
      await tapKey(tester, SettingsScreen.digitsChipKey(DigitStyle.latin));
      expect(prefs.getString(SettingsRepository.digitsKey), 'latin');
      expect(
        find.text('تصل التنبيهات الساعة 8:00 صباحاً بتوقيت جهازك.'),
        findsOneWidget,
      );
      await openTab(tester, AppTab.wheel);
      expect(find.textContaining('2026'), findsWidgets);
      expect(find.textContaining('٢٠٢٦'), findsNothing);
    });
  });

  group('الضغط على التنبيه (SPEC 8 معيار 4، DESIGN 8.9)', () {
    testWidgets('حمولة موسم ← صفحته فوق الرئيسية، والرجوع للرئيسية', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(tester, scheduler);
      // من الإعدادات: التنبيه يفتح الصفحة فوق الرئيسية لا فوق الإعدادات.
      await openSettings(tester);
      expect(scheduler.onTap, isNotNull);
      scheduler.onTap!('/item/wasm?from=2026-10-19');
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
      expect(currentPath(tester), '/item/wasm?from=2026-10-19');
      expect(find.text('الوسم'), findsWidgets);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('حمولة الدَّرّ من الخطة الفعلية تفتح صفحة الدَّرّ', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(
        tester,
        scheduler,
        saved: {
          ...savedCity('kuwait_city'),
          SettingsRepository.notifyDarKey: true,
        },
      );
      final dar = scheduler.pending.firstWhere(
        (n) => n.kind == NotificationKind.dar,
      );
      scheduler.onTap!(dar.payload);
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
      expect(find.byKey(ItemDetailView.rangeKey), findsOneWidget);
      expect(currentPath(tester), dar.payload);
    });

    testWidgets('كل حمولات الخطة تفتح صفحة (لا رجوع للرئيسية لعنصر مفقود)', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(
        tester,
        scheduler,
        saved: {
          ...savedCity('riyadh'),
          SettingsRepository.notifyDarKey: true,
        },
      );
      final payloads = scheduler.pending.map((n) => n.payload).toSet();
      expect(payloads, isNotEmpty);
      for (final payload in payloads.take(12)) {
        scheduler.onTap!(payload);
        await tester.pumpAndSettle();
        expect(find.byKey(ItemDetailView.rangeKey), findsOneWidget,
            reason: payload);
      }
    });

    testWidgets('فتح التطبيق من تنبيه (حالة الإغلاق) يفتح الصفحة', (
      tester,
    ) async {
      await openApp(
        tester,
        FakeNotificationScheduler(launch: '/item/suhail?from=2027-08-21'),
      );
      expect(find.byKey(ItemDetailPage.pageKey), findsOneWidget);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('أثناء الإعداد الأولي تُهمل الحمولة', (tester) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(
        tester,
        scheduler,
        saved: {SettingsRepository.cityIdKey: 'kuwait_city'},
      );
      expect(find.byType(NotificationsIntroScreen), findsOneWidget);
      scheduler.onTap!('/item/wasm?from=2026-10-19');
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsIntroScreen), findsOneWidget);
      expect(find.byKey(ItemDetailPage.pageKey), findsNothing);
    });

    testWidgets('آيفون بلا إذن: لا رسالة «تعذّر ضبط التنبيهات» مضللة', (
      tester,
    ) async {
      await openApp(
        tester,
        FakeNotificationScheduler(failWithoutPermission: true),
      );
      await openSettings(tester);
      expect(find.byKey(SettingsScreen.permissionNoteKey), findsOneWidget);
      expect(find.byKey(SettingsScreen.scheduleErrorKey), findsNothing);
    });

    testWidgets('حمولة غير صالحة تُهمل', (tester) async {
      final scheduler = FakeNotificationScheduler();
      await openApp(tester, scheduler);
      for (final bad in ['/settings', 'https://x.y/item/wasm', '', '/item/']) {
        scheduler.onTap!(bad);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byKey(ItemDetailPage.pageKey), findsNothing);
      }
    });
  });

  group('إصلاحات مؤجلة', () {
    test('urlOpenerProvider يرفض أي رابط ليس https', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final open = c.read(urlOpenerProvider);
      for (final uri in [
        'http://www.geonames.org',
        'mailto:a@b.c',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'https:///nohost',
        '/relative',
      ]) {
        expect(isOpenableUrl(Uri.parse(uri)), isFalse, reason: uri);
        expect(await open(Uri.parse(uri)), isFalse, reason: uri);
      }
      expect(isOpenableUrl(Uri.parse('https://www.geonames.org')), isTrue);
    });

    testWidgets('زر «اختيار المدينة» في الرسالة يعمل بعد مغادرة الإعدادات', (
      tester,
    ) async {
      await openApp(
        tester,
        FakeNotificationScheduler(),
        extra: [
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              permission: LocationAccess.denied,
              afterRequest: LocationAccess.denied,
            ),
          ),
        ],
      );
      await openSettings(tester);
      await tester.tap(find.byKey(SettingsScreen.relocateRowKey));
      await tester.pump();
      await tester.pump();
      // الرسالة ظاهرة، ثم يغادر المستخدم الإعدادات إلى تبويب آخر.
      await tester.tap(find.byKey(AppShell.tabKey(AppTab.wheel.index)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SettingsScreen), findsNothing);
      await tester.tap(find.widgetWithText(SnackBarAction, 'اختيار المدينة'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CityPickerScreen), findsOneWidget);
    });

    testWidgets('_relocate يلتقط أي خطأ (Error لا Exception فقط)', (
      tester,
    ) async {
      await openApp(
        tester,
        FakeNotificationScheduler(),
        extra: [
          locationServiceProvider.overrideWithValue(
            FakeLocationService(error: StateError('غير متوقع')),
          ),
        ],
      );
      await openSettings(tester);
      await tester.tap(find.byKey(SettingsScreen.relocateRowKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('نحدد مدينتك…'), findsNothing);
    });

    testWidgets('صفحة العنصر: فشل تحميل الجداول ← رسالة وإعادة المحاولة', (
      tester,
    ) async {
      phone(tester);
      var calls = 0;
      await pumpScreen(
        tester,
        const ItemDetailPage(target: ItemTarget('wasm')),
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: null,
        extra: [
          fixedClock(DateTime(2026, 10, 2, 9)),
          tablesProvider.overrideWith((ref) async {
            calls++;
            throw const FormatException('تالف');
          }),
        ],
      );
      expect(find.byKey(ItemDetailPage.loadErrorKey), findsOneWidget);
      expect(find.text('تعذّر فتح بيانات الدرور'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(ItemDetailPage.loadErrorKey), findsOneWidget);
    });

    testWidgets('صفحة العنصر: إعادة المحاولة الناجحة تعرض المحتوى', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      phone(tester);
      var calls = 0;
      final prefs = await fakePrefs(savedCity('kuwait_city'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(prefs, null, [
            fakeScheduler(scheduler),
            fixedClock(DateTime(2026, 10, 2, 9)),
            tablesProvider.overrideWith((ref) async {
              calls++;
              if (calls == 1) throw const FormatException('تالف');
              return tables;
            }),
          ]),
          child: const DururApp(),
        ),
      );
      await tester.pumpAndSettle();
      scheduler.onTap!('/item/wasm');
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailPage.loadErrorKey), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(ItemDetailPage.loadErrorKey),
          matching: find.text('إعادة المحاولة'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ItemDetailView.rangeKey), findsOneWidget);
    });
  });

  group('أصل التقويم: عبارة المقارنة (DESIGN 8.10)', () {
    for (final (cityId, borrows) in [('riyadh', true), ('kuwait_city', false)]) {
      testWidgets('$cityId: العبارة ${borrows ? 'تظهر' : 'لا تظهر'}', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const OriginScreen(),
          prefs: await fakePrefs(savedCity(cityId)),
          tables: tables,
        );
        const body = 'حساب عشري (٣٦ دَرّاً × ١٠ أيام) لأهل الساحل الخليجي.';
        expect(
          find.text(borrows ? '$body معروض هنا للمقارنة.' : body),
          findsOneWidget,
        );
        expect(find.textContaining('للمقارنة'), borrows ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('تغيير المدينة والصفحة مفتوحة يحذف العبارة', (tester) async {
      await pumpScreen(
        tester,
        const OriginScreen(),
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: tables,
      );
      expect(find.textContaining('للمقارنة'), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(OriginScreen)),
      );
      await c.read(settingsProvider.notifier).selectCity('muscat');
      await tester.pumpAndSettle();
      expect(find.textContaining('للمقارنة'), findsNothing);
    });
  });
}
