import 'dart:async';

import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
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

  Future<SharedPreferences> openSettings(
    WidgetTester tester,
    FakeLocationService location, {
    String cityId = 'riyadh',
  }) async {
    final prefs = await fakePrefs({SettingsRepository.cityIdKey: cityId});
    await pumpDururApp(
      tester,
      prefs: prefs,
      tables: tables,
      extra: [locationServiceProvider.overrideWithValue(location)],
    );
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> relocate(WidgetTester tester) async {
    await tester.tap(find.byKey(SettingsScreen.relocateRowKey));
    await tester.pumpAndSettle();
  }

  testWidgets('معيار 6: الصف موجود ولا يطلب شيئاً قبل الضغط، وهدفه 48dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final location = FakeLocationService();
    await openSettings(tester, location);
    expect(find.text('تحديد موقعي مرة أخرى'), findsOneWidget);
    expect(location.totalCalls, 0);
    expect(
      tester.getSize(find.byKey(SettingsScreen.relocateRowKey)).height,
      greaterThanOrEqualTo(48),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('مدينة جديدة: تُحفظ (المعرّف فقط) والعرض يتحدث ورسالة التحديث', (
    tester,
  ) async {
    final location = FakeLocationService(position: FakeLocationService.muscat);
    final prefs = await openSettings(tester, location);
    await relocate(tester);

    expect(location.reads, 1);
    expect(
      find.text('تم تحديث مدينتك إلى مسقط — جدول الإمارات وعُمان'),
      findsOneWidget,
    );
    expect(find.text('مسقط — جدول الإمارات وعُمان'), findsOneWidget);
    expect(prefs.getKeys(), {SettingsRepository.cityIdKey});
    expect(prefs.getString(SettingsRepository.cityIdKey), 'muscat');
  });

  testWidgets('المدينة نفسها: «مدينتك كما هي»', (tester) async {
    await openSettings(tester, FakeLocationService());
    await relocate(tester);
    expect(find.text('مدينتك كما هي: الرياض'), findsOneWidget);
  });

  testWidgets('أثناء القراءة: «نحدد مدينتك…» والصف معطّل (لا قراءة ثانية)', (
    tester,
  ) async {
    final pending = Completer<ApproximatePosition>();
    final location = FakeLocationService(pending: pending);
    await openSettings(tester, location);
    await tester.tap(find.byKey(SettingsScreen.relocateRowKey));
    await tester.pump();
    expect(find.text('نحدد مدينتك…'), findsOneWidget);
    await tester.tap(find.byKey(SettingsScreen.relocateRowKey));
    await tester.pump();
    expect(location.reads, 1);

    pending.complete(FakeLocationService.riyadh);
    await tester.pumpAndSettle();
    expect(find.text('نحدد مدينتك…'), findsNothing);
  });

  for (final (name, service) in [
    (
      'رفض الإذن',
      () => FakeLocationService(
        permission: LocationAccess.denied,
        afterRequest: LocationAccess.denied,
      ),
    ),
    ('خدمة الموقع مطفأة', () => FakeLocationService(serviceEnabled: false)),
    (
      'رفض نهائي سابق',
      () => FakeLocationService(permission: LocationAccess.deniedForever),
    ),
  ]) {
    testWidgets('$name: رسالة الفشل مع زر «اختيار المدينة»، والمدينة كما هي', (
      tester,
    ) async {
      final prefs = await openSettings(tester, service());
      await relocate(tester);
      expect(
        find.text('لم نتمكن من الوصول لموقعك. يمكنك اختيار مدينتك يدوياً.'),
        findsOneWidget,
      );
      expect(prefs.getString(SettingsRepository.cityIdKey), 'riyadh');

      await tester.tap(find.widgetWithText(SnackBarAction, 'اختيار المدينة'));
      await tester.pumpAndSettle();
      expect(find.byType(CityPickerScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });
  }

  testWidgets('تأخر 10 ثوانٍ: رسالة الفشل', (tester) async {
    final pending = Completer<ApproximatePosition>();
    await openSettings(tester, FakeLocationService(pending: pending));
    await tester.tap(find.byKey(SettingsScreen.relocateRowKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10, milliseconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.text('لم نتمكن من الوصول لموقعك. يمكنك اختيار مدينتك يدوياً.'),
      findsOneWidget,
    );
    pending.complete(FakeLocationService.muscat);
    await tester.pumpAndSettle();
  });

  testWidgets('خارج الخليج: «منطقتك خارج نطاق الجداول» والمدينة كما هي', (
    tester,
  ) async {
    final prefs = await openSettings(
      tester,
      FakeLocationService(position: FakeLocationService.london),
    );
    await relocate(tester);
    expect(
      find.text(
        'منطقتك خارج نطاق الجداول المتاحة. اختر أقرب مدينة خليجية إليك.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SnackBarAction, 'اختيار المدينة'),
      findsOneWidget,
    );
    expect(prefs.getString(SettingsRepository.cityIdKey), 'riyadh');
  });
}
