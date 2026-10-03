import 'dart:async';

import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:durur/src/features/home/city_chip.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/onboarding/location_screen.dart';
import 'package:durur/src/features/onboarding/notifications_intro_screen.dart';
import 'package:durur/src/features/onboarding/welcome_screen.dart';
import 'package:durur/src/location/location_service.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_location_service.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  Future<SharedPreferences> openApp(
    WidgetTester tester,
    FakeLocationService location, {
    Map<String, Object> saved = const {},
    double textScale = 1,
  }) async {
    final prefs = await fakePrefs(saved);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDururApp(
      tester,
      prefs: prefs,
      tables: tables,
      extra: [locationServiceProvider.overrideWithValue(location)],
    );
    return prefs;
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    // مع تكبير الخط وشريط «بيانات تجريبية» قد يكون الزر تحت حافة الشاشة.
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// شرح التنبيهات بعد اختيار المدينة (الميزة 8) ← «ليس الآن» ← الرئيسية.
  Future<void> finishIntro(WidgetTester tester) async {
    expect(find.byType(NotificationsIntroScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tapKey(tester, NotificationsIntroScreen.notNowKey);
  }

  Future<void> toLocationScreen(WidgetTester tester) =>
      tapKey(tester, WelcomeScreen.startKey);

  String chipText(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(of: find.byType(CityChip), matching: find.byType(Text)),
      )
      .data!;

  Finder tile(String id) => find.byKey(CityPickerScreen.cityTileKey(id));

  String? noticeText(WidgetTester tester) {
    final f = find.descendant(
      of: find.byKey(CityPickerScreen.noticeKey),
      matching: find.byType(Text),
    );
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  /// يتأكد أن التخزين فيه معرّف المدينة فقط (ومعه علامة انتهاء الإعداد
  /// الأولي إن انتهى)، ولا أي إحداثيات.
  void expectOnlyCityIdStored(SharedPreferences prefs, String? cityId) {
    final keys = prefs.getKeys();
    if (cityId == null) {
      expect(keys, isEmpty);
    } else {
      expect(
        keys.difference({SettingsRepository.onboardingDoneKey}),
        {SettingsRepository.cityIdKey},
      );
    }
    expect(prefs.getString(SettingsRepository.cityIdKey), cityId);
    for (final key in keys) {
      final value = prefs.get(key);
      if (key == SettingsRepository.onboardingDoneKey) {
        expect(value, isTrue);
        continue;
      }
      expect(value, isA<String>(), reason: key);
      expect(value, isNot(contains('24.7')), reason: key);
      expect(value, isNot(contains('46.7')), reason: key);
      expect(value, isNot(contains('23.6')), reason: key);
    }
  }

  group('شاشات البداية', () {
    testWidgets(
      'أول تشغيل: الترحيب ثم شرح الموقع بسطر واحد، من اليمين لليسار',
      (tester) async {
        final location = FakeLocationService();
        await openApp(tester, location);

        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.text('أهلاً بك في دليل المواسم'), findsOneWidget);
        expect(
          find.text(
            'تعرف الدَّرّ والموسم والنجم اليوم في منطقتك، وما الجو '
            'المعتاد فيه. يعمل بلا إنترنت.',
          ),
          findsOneWidget,
        );
        expect(
          Directionality.of(tester.element(find.byType(WelcomeScreen))),
          TextDirection.rtl,
        );

        await toLocationScreen(tester);
        expect(find.byType(LocationScreen), findsOneWidget);
        expect(find.text('في أي منطقة أنت؟'), findsOneWidget);
        expect(
          find.text(
            'نستخدم موقعك التقريبي مرة واحدة لنعرف جدول درور منطقتك. '
            'لا نتتبعك ولا نرسل موقعك لأي جهة.',
          ),
          findsOneWidget,
        );
        expect(find.text('حدّد موقعي'), findsOneWidget);
        expect(find.text('اختر مدينتك يدوياً'), findsOneWidget);
        // لا يُطلب الإذن قبل الضغط على «حدّد موقعي».
        expect(location.totalCalls, 0);
      },
    );

    testWidgets(
      'معيار 2: نجاح ← قراءة واحدة، بطاقة أقرب مدينة، ويُحفظ معرّف المدينة '
      'فقط بلا إحداثيات، ثم الرئيسية',
      (tester) async {
        final location = FakeLocationService(permission: LocationAccess.denied);
        final prefs = await openApp(tester, location);
        await toLocationScreen(tester);
        await tapKey(tester, LocationScreen.allowKey);

        expect(location.permissionRequests, 1);
        expect(location.reads, 1);
        expect(find.byKey(LocationScreen.foundCardKey), findsOneWidget);
        expect(find.text('وجدنا أقرب مدينة لك: الرياض'), findsOneWidget);
        expect(find.text('جدول المنطقة: نجد'), findsOneWidget);
        expectOnlyCityIdStored(prefs, 'riyadh');

        await tapKey(tester, LocationScreen.continueKey);
        await finishIntro(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(chipText(tester), 'الرياض · نجد');
        // لا قراءة أخرى بعد الوصول للرئيسية (لا تتبع).
        await tester.pump(const Duration(minutes: 1));
        expect(location.reads, 1);
        expectOnlyCityIdStored(prefs, 'riyadh');
      },
    );

    testWidgets(
      '«ليست مدينتي» تفتح القائمة والمدينة الموجودة محددة، بلا رجوع',
      (tester) async {
        final prefs = await openApp(tester, FakeLocationService());
        await toLocationScreen(tester);
        await tapKey(tester, LocationScreen.allowKey);
        await tapKey(tester, LocationScreen.notMyCityKey);

        expect(find.byType(CityPickerScreen), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(tester.widget<ListTile>(tile('riyadh')).selected, isTrue);

        await tester.enterText(
          find.byKey(CityPickerScreen.searchFieldKey),
          'مسقط',
        );
        await tester.pumpAndSettle();
        await tester.tap(tile('muscat'));
        await tester.pumpAndSettle();
        await finishIntro(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(chipText(tester), 'مسقط · الإمارات وعُمان');
        expectOnlyCityIdStored(prefs, 'muscat');
      },
    );

    testWidgets('«اختر مدينتك يدوياً»: القائمة بلا طلب إذن ولا سطر خطأ', (
      tester,
    ) async {
      final location = FakeLocationService();
      final prefs = await openApp(tester, location);
      await toLocationScreen(tester);
      await tapKey(tester, LocationScreen.manualKey);

      expect(find.byType(CityPickerScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(noticeText(tester), isNull);
      expect(location.totalCalls, 0);

      await tester.tap(tile('riyadh'));
      await tester.pumpAndSettle();
      await finishIntro(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expectOnlyCityIdStored(prefs, 'riyadh');
    });

    for (final (name, service, notice) in [
      (
        'معيار 4: رفض الإذن',
        () => FakeLocationService(
          permission: LocationAccess.denied,
          afterRequest: LocationAccess.denied,
        ),
        'لا بأس، اختر مدينتك من القائمة.',
      ),
      (
        'رفض نهائي سابق',
        () => FakeLocationService(permission: LocationAccess.deniedForever),
        'خدمة الموقع غير متاحة. اختر مدينتك من القائمة.',
      ),
      (
        'خدمة الموقع مطفأة',
        () => FakeLocationService(serviceEnabled: false),
        'خدمة الموقع غير متاحة. اختر مدينتك من القائمة.',
      ),
      (
        'خطأ من النظام أثناء القراءة',
        () => FakeLocationService(error: const LocationUnavailableException()),
        'خدمة الموقع غير متاحة. اختر مدينتك من القائمة.',
      ),
      (
        'معيار 5: موقع خارج الخليج',
        () => FakeLocationService(position: FakeLocationService.london),
        'منطقتك خارج نطاق الجداول المتاحة. اختر أقرب مدينة خليجية إليك.',
      ),
    ]) {
      testWidgets('$name ← قائمة المدن مباشرة مع سطر السبب، ولا يُحفظ شيء', (
        tester,
      ) async {
        final prefs = await openApp(tester, service());
        await toLocationScreen(tester);
        await tapKey(tester, LocationScreen.allowKey);

        expect(find.byType(CityPickerScreen), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(noticeText(tester), notice);
        expectOnlyCityIdStored(prefs, null);

        await tester.tap(tile('riyadh'));
        await tester.pumpAndSettle();
        await finishIntro(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expectOnlyCityIdStored(prefs, 'riyadh');
      });
    }

    testWidgets(
      'معيار 4: لا نتيجة خلال 10 ثوانٍ ← القائمة مع «تأخر تحديد الموقع»، '
      'و«اختر يدوياً» ظاهر أثناء الانتظار',
      (tester) async {
        final pending = Completer<ApproximatePosition>();
        final prefs = await openApp(
          tester,
          FakeLocationService(pending: pending),
        );
        await toLocationScreen(tester);
        await tester.tap(find.byKey(LocationScreen.allowKey));
        await tester.pump();
        await tester.pump(const Duration(seconds: 9));

        expect(find.text('نحدد مدينتك…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.byKey(LocationScreen.manualWhileLoadingKey),
          findsOneWidget,
        );
        expect(find.byType(CityPickerScreen), findsNothing);

        await tester.pump(const Duration(seconds: 1, milliseconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(CityPickerScreen), findsOneWidget);
        expect(
          noticeText(tester),
          'تأخر تحديد الموقع. اختر مدينتك من القائمة.',
        );

        // نتيجة متأخرة بعد انتهاء المهلة لا تُحفظ.
        pending.complete(FakeLocationService.riyadh);
        await tester.pumpAndSettle();
        expectOnlyCityIdStored(prefs, null);
      },
    );

    testWidgets(
      '«اختر يدوياً» أثناء الانتظار: القائمة، والنتيجة المتأخرة تُهمل',
      (tester) async {
        final pending = Completer<ApproximatePosition>();
        final prefs = await openApp(
          tester,
          FakeLocationService(pending: pending),
        );
        await toLocationScreen(tester);
        await tester.tap(find.byKey(LocationScreen.allowKey));
        await tester.pump();
        await tapKey(tester, LocationScreen.manualWhileLoadingKey);
        expect(find.byType(CityPickerScreen), findsOneWidget);
        expect(noticeText(tester), isNull);

        pending.complete(FakeLocationService.muscat);
        await tester.pumpAndSettle();
        expect(find.byType(CityPickerScreen), findsOneWidget);
        expectOnlyCityIdStored(prefs, null);
      },
    );

    testWidgets('أهداف اللمس 48dp على الأقل في الترحيب والموقع والنتيجة', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final pending = Completer<ApproximatePosition>();
      final location = FakeLocationService(pending: pending);
      await openApp(tester, location);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(
        tester.getSize(find.byKey(WelcomeScreen.startKey)).height,
        greaterThanOrEqualTo(48),
      );

      await toLocationScreen(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      for (final k in [LocationScreen.allowKey, LocationScreen.manualKey]) {
        expect(tester.getSize(find.byKey(k)).height, greaterThanOrEqualTo(48));
      }

      await tester.tap(find.byKey(LocationScreen.allowKey));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(LocationScreen.manualWhileLoadingKey)).height,
        greaterThanOrEqualTo(48),
      );
      pending.complete(FakeLocationService.riyadh);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      for (final k in [
        LocationScreen.continueKey,
        LocationScreen.notMyCityKey,
      ]) {
        expect(tester.getSize(find.byKey(k)).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });

    testWidgets('خط الجهاز 200% بلا فيضان', (tester) async {
      await openApp(tester, FakeLocationService(), textScale: 2);
      expect(tester.takeException(), isNull);
      await toLocationScreen(tester);
      expect(tester.takeException(), isNull);
      await tapKey(tester, LocationScreen.allowKey);
      expect(tester.takeException(), isNull);
      expect(find.byKey(LocationScreen.continueKey), findsOneWidget);
    });
  });

  group('DESIGN 8.4: المدينة غائبة', () {
    testWidgets('مدينة محفوظة لم تعد في القائمة ← اختيار المدينة تلقائياً', (
      tester,
    ) async {
      final prefs = await openApp(
        tester,
        FakeLocationService(),
        saved: savedCity('removed_city'),
      );
      expect(find.byType(CityPickerScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(tile('riyadh'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(chipText(tester), 'الرياض · نجد');
      expectOnlyCityIdStored(prefs, 'riyadh');
    });

    testWidgets('مدينة محفوظة صالحة ← الرئيسية مباشرة بلا طلب موقع', (
      tester,
    ) async {
      final location = FakeLocationService();
      await openApp(
        tester,
        location,
        saved: savedCity('riyadh'),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(location.totalCalls, 0);
    });
  });
}
