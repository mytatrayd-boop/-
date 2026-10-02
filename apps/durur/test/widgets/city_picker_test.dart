import 'package:durur/src/domain/city.dart';
import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:durur/src/features/home/city_chip.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

class _FailingSettingsRepository extends SettingsRepository {
  _FailingSettingsRepository(super.prefs);

  @override
  Future<void> saveCityId(String cityId) async =>
      throw const SettingsSaveException(SettingsRepository.cityIdKey);
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  Finder tile(String id) => find.byKey(CityPickerScreen.cityTileKey(id));
  Finder chip(Country? c) => find.byKey(CityPickerScreen.countryChipKey(c));
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(CityPickerScreen.searchFieldKey), text);
    await tester.pumpAndSettle();
  }

  String chipText(WidgetTester tester) {
    final label = find.descendant(
      of: find.byType(CityChip),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(label).data!;
  }

  group('شاشة اختيار المدينة', () {
    testWidgets('العنوان والبحث والشرائح والقائمة المجمّعة، من اليمين لليسار',
        (tester) async {
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: await fakePrefs(), tables: tables);

      expect(find.text('اختر مدينتك'), findsOneWidget);
      expect(find.text('ابحث باسم المدينة'), findsOneWidget);
      for (final label in [
        'الكل', 'السعودية', 'الكويت', 'الإمارات', 'عُمان', 'قطر', 'البحرين',
      ]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget,
            reason: label);
      }
      // أول مجموعة: السعودية، وأول مدينة: الرياض مع «جدول: نجد».
      expect(find.text('الرياض'), findsOneWidget);
      expect(
        find.descendant(of: tile('riyadh'), matching: find.text('جدول: نجد')),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(tile('riyadh'))),
        TextDirection.rtl,
      );
      // اتجاه RTL: عنوان الصف على يمين الشاشة.
      final row = tester.getRect(tile('riyadh'));
      final title = tester.getRect(
        find.descendant(of: tile('riyadh'), matching: find.text('الرياض')),
      );
      expect(title.right, greaterThan(row.center.dx));
    });

    testWidgets('معيار 1: البحث بالاسم العربي مع تجاهل الهمزات والتاء المربوطة',
        (tester) async {
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: await fakePrefs(), tables: tables);

      await search(tester, 'الاحساء');
      expect(tile('al_ahsa'), findsOneWidget);
      expect(tile('riyadh'), findsNothing);

      await search(tester, 'الدوحه');
      expect(tile('doha'), findsOneWidget);
      expect(find.text('قطر'), findsWidgets); // عنوان المجموعة + الشريحة

      await search(tester, 'مسقط');
      expect(tile('muscat'), findsOneWidget);
      expect(
        find.descendant(
            of: tile('muscat'), matching: find.text('جدول: الإمارات وعُمان')),
        findsOneWidget,
      );
    });

    testWidgets('حالة الفراغ: لا نتائج، وزر «مسح البحث» يعيد القائمة',
        (tester) async {
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: await fakePrefs(), tables: tables);

      await search(tester, 'لندن');
      expect(find.text('لا توجد مدينة بهذا الاسم.'), findsOneWidget);
      expect(find.text('جرّب اسماً آخر أو اختر أقرب مدينة لك.'),
          findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      await tester.tap(find.text('مسح البحث'));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد مدينة بهذا الاسم.'), findsNothing);
      expect(tile('riyadh'), findsOneWidget);
      final field = tester.widget<TextField>(
          find.byKey(CityPickerScreen.searchFieldKey));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('التصفية بالدولة', (tester) async {
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: await fakePrefs(), tables: tables);

      await tester.tap(chip(Country.qa));
      await tester.pumpAndSettle();
      expect(tile('doha'), findsOneWidget);
      expect(tile('riyadh'), findsNothing);
      expect(
        tester.widget<ChoiceChip>(chip(Country.qa)).selected,
        isTrue,
      );

      // بحث عن مدينة في دولة أخرى مع التصفية ← فراغ.
      await search(tester, 'الرياض');
      expect(find.text('لا توجد مدينة بهذا الاسم.'), findsOneWidget);

      await tester.tap(chip(null));
      await tester.pumpAndSettle();
      expect(tile('riyadh'), findsOneWidget);
    });

    testWidgets('معيار 4: الضغط يحفظ معرّف المدينة فقط ويعرض رسالة، والمختارة معلّمة',
        (tester) async {
      final prefs = await fakePrefs();
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: prefs, tables: tables);

      await tester.tap(chip(Country.kw));
      await tester.pumpAndSettle();
      await tester.tap(tile('kuwait_city'));
      await tester.pumpAndSettle();

      expect(prefs.getKeys(), {SettingsRepository.cityIdKey});
      expect(prefs.getString(SettingsRepository.cityIdKey), 'kuwait_city');
      expect(find.text('تم اختيار مدينة الكويت — جدول الكويت'), findsOneWidget);
      final selected = tester.widget<ListTile>(tile('kuwait_city'));
      expect(selected.selected, isTrue);
      expect(
        find.descendant(of: tile('kuwait_city'), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(tile('hawalli')).selected, isFalse);
    });

    testWidgets('فشل الحفظ: رسالة خطأ مع «إعادة المحاولة»، والاختيار لا يتغير',
        (tester) async {
      final prefs = await fakePrefs();
      await pumpScreen(
        tester,
        const CityPickerScreen(),
        prefs: prefs,
        tables: tables,
        extra: [
          settingsRepositoryProvider
              .overrideWithValue(_FailingSettingsRepository(prefs)),
        ],
      );

      await tester.tap(tile('riyadh'));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر حفظ اختيارك. حاول مرة أخرى.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'إعادة المحاولة'),
          findsOneWidget);
      expect(prefs.getString(SettingsRepository.cityIdKey), isNull);
      expect(tester.widget<ListTile>(tile('riyadh')).selected, isFalse);
    });

    testWidgets('أهداف اللمس 48dp على الأقل', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: await fakePrefs(), tables: tables);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester.getSize(tile('riyadh')).height, greaterThanOrEqualTo(64));
      for (final c in [null, ...Country.values]) {
        expect(tester.getSize(chip(c)).height, greaterThanOrEqualTo(48));
      }
      await search(tester, 'لندن');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('خط الجهاز 200% بلا فيضان (القائمة والفراغ)', (tester) async {
      await pumpScreen(tester, const CityPickerScreen(),
          prefs: await fakePrefs(), tables: tables, textScale: 2);
      expect(tester.takeException(), isNull);
      await search(tester, 'لندن');
      expect(tester.takeException(), isNull);
      expect(find.text('مسح البحث'), findsOneWidget);
    });

    testWidgets('تعذّر قراءة البيانات: رسالة وزر إعادة المحاولة', (tester) async {
      await pumpScreen(
        tester,
        const CityPickerScreen(),
        prefs: await fakePrefs(),
        tables: null,
        extra: [
          tablesProvider.overrideWith((ref) => throw const FormatException()),
        ],
      );
      expect(find.text('تعذّر فتح بيانات الدرور'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  });

  group('التدفق في التطبيق', () {
    testWidgets(
        'معيار 3 و4: الرئيسية ← اختيار الرياض ← رجوع والعرض «الرياض · نجد»، '
        'ويبقى بعد إعادة الفتح', (tester) async {
      // بلا مدينة محفوظة تظهر شاشات البداية (الميزة 4، test/widgets/onboarding_test.dart).
      final prefs =
          await fakePrefs(savedCity('kuwait_city'));
      await pumpDururApp(tester, prefs: prefs, tables: tables);
      expect(chipText(tester), 'مدينة الكويت · الكويت');

      await tester.tap(find.byType(CityChip));
      await tester.pumpAndSettle();
      expect(find.byType(CityPickerScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(tile('riyadh'));
      await tester.pumpAndSettle();
      expect(find.byType(CityPickerScreen), findsNothing);
      expect(chipText(tester), 'الرياض · نجد');
      expect(find.text('تم اختيار الرياض — جدول نجد'), findsOneWidget);

      // إعادة فتح التطبيق بنفس التخزين.
      await tester.pumpWidget(const SizedBox());
      final reopened = await SharedPreferences.getInstance();
      await pumpDururApp(tester, prefs: reopened, tables: tables);
      expect(chipText(tester), 'الرياض · نجد');
    });

    testWidgets('معيار 5: التغيير من الإعدادات يحدّث العرض فوراً',
        (tester) async {
      final prefs = await fakePrefs(savedCity('riyadh'));
      late ProviderContainer container;
      await pumpDururApp(tester, prefs: prefs, tables: tables);
      container = ProviderScope.containerOf(
          tester.element(find.byType(CityChip)));
      expect(container.read(engineProvider)?.region.id, 'najd');

      await tester.tap(find.byTooltip('الإعدادات'));
      await tester.pumpAndSettle();
      expect(find.text('المنطقة'), findsOneWidget);
      expect(find.text('الرياض — جدول نجد'), findsOneWidget);

      await tester.tap(find.byKey(SettingsScreen.cityRowKey));
      await tester.pumpAndSettle();
      await search(tester, 'مسقط');
      await tester.tap(tile('muscat'));
      await tester.pumpAndSettle();

      // رجعنا إلى الإعدادات والقيمة محدّثة.
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('مسقط — جدول الإمارات وعُمان'), findsOneWidget);
      expect(container.read(engineProvider)?.region.id, 'uae_oman');
      expect(prefs.getString(SettingsRepository.cityIdKey), 'muscat');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(chipText(tester), 'مسقط · الإمارات وعُمان');
    });
  });
}
