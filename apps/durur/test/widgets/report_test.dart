import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/features/home/home_screen.dart';
import 'package:durur/src/features/item_detail/detail_data.dart';
import 'package:durur/src/features/item_detail/item_detail_sheet.dart';
import 'package:durur/src/features/item_detail/item_detail_view.dart';
import 'package:durur/src/features/report/report_sheet.dart';
import 'package:durur/src/features/settings/settings_screen.dart';
import 'package:durur/src/formatting/date_labels.dart';
import 'package:durur/src/formatting/digits.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/report/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// الميزة 9: زر «أبلغ عن خطأ» وورقة البلاغ (DESIGN 8.8).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final now = DateTime(2026, 10, 2, 9, 30);
  final today = DateTime(2026, 10, 2);
  const form = 'https://docs.example.com/forms/d/e/ABC/viewform';
  const version = '1.0.0+1';

  void phone(WidgetTester tester, {double width = 411, double height = 900}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// فاتح روابط وناسخ وهميان يسجّلان ما طُلب منهما.
  final opened = <Uri>[];
  final copied = <String>[];
  var opens = true;
  setUp(() {
    opened.clear();
    copied.clear();
    opens = true;
  });

  List<Override> reportOverrides({
    String formUrl = '',
    String formFields = '',
  }) => [
    fixedClock(now),
    reportConfigProvider.overrideWithValue(
      ReportConfig(formUrl: formUrl, formFields: formFields),
    ),
    appVersionProvider.overrideWith((ref) async => version),
    urlOpenerProvider.overrideWithValue((uri) async {
      opened.add(uri);
      return opens;
    }),
    clipboardWriterProvider.overrideWithValue((text) async => copied.add(text)),
  ];

  const openKey = Key('openSheet');

  /// يفتح صفحة عنصر (ورقة الدائرة) ثم يضغط «أبلغ عن خطأ» أسفلها.
  Future<void> openReportFromDetail(
    WidgetTester tester,
    DetailRequest request, {
    String city = 'riyadh',
    String formUrl = '',
    String formFields = '',
    double textScale = 1,
  }) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: openKey,
            onPressed: () => showItemDetailSheet(context, request),
            child: const Text('open'),
          ),
        ),
      ),
      prefs: await fakePrefs(savedCity(city)),
      tables: tables,
      textScale: textScale,
      extra: reportOverrides(formUrl: formUrl, formFields: formFields),
    );
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    // الورقة تُسحب لأعلى لتصبح كاملة، ثم يُمرَّر إلى الزر.
    await tester.drag(
      find.byKey(ItemDetailSheet.sheetKey),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ItemDetailView.reportKey),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(ItemDetailView.viewKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.detailReport), findsOneWidget);
    await tester.tap(find.byKey(ItemDetailView.reportKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ReportSheet.sheetKey), findsOneWidget);
  }

  Finder inReport(Finder f) =>
      find.descendant(of: find.byKey(ReportSheet.sheetKey), matching: f);

  Finder inSummary(Finder f) =>
      find.descendant(of: find.byKey(ReportSheet.summaryKey), matching: f);

  String item(String id) => tables.items[id]!.name.ar;
  final meta = tables.meta;

  group('محتوى البلاغ', () {
    test('العنصر والمنطقة والتاريخ ونسخة التطبيق ونسخة البيانات فقط', () {
      final m = buildReportMessage(
        l10n,
        itemName: 'الوسم',
        regionName: 'نجد',
        date: DateTime(2026, 10, 2, 13, 45),
        appVersion: version,
        meta: const TablesMeta(
          schemaVersion: 1,
          dataVersion: '2027-03-a',
          dataSeq: 7,
        ),
      );
      expect(m.lines, [
        'العنصر: الوسم',
        'المنطقة: نجد',
        'التاريخ المعروض: ${gregorianDateLabel(l10n, today)}',
        'نسخة التطبيق: ١.٠.٠+١',
        'نسخة البيانات: 2027-03-a (٧)',
      ]);
      expect(m.text, m.lines.join('\n'));
      expect(m.values, {
        ReportField.item: 'الوسم',
        ReportField.region: 'نجد',
        ReportField.date: '2026-10-02',
        ReportField.appVersion: version,
        ReportField.dataVersion: '2027-03-a (7)',
      });
      expect(m.valueOf(ReportField.details), m.text);
    });

    test('بلاغ عام بلا عنصر، والأرقام اللاتينية حسب الإعداد', () {
      final m = buildReportMessage(
        l10n,
        regionName: 'الكويت',
        date: today,
        appVersion: version,
        meta: meta,
        digits: DigitStyle.latin,
      );
      expect(m.lines.first, startsWith('المنطقة: '));
      expect(m.lines.any((l) => l.startsWith('العنصر')), isFalse);
      expect(m.values.containsKey(ReportField.item), isFalse);
      expect(m.lines, contains('نسخة التطبيق: 1.0.0+1'));
      expect(
        m.lines,
        contains('نسخة البيانات: ${meta.dataVersion} (${meta.dataSeq})'),
      );
    });
  });

  group('الزر في صفحة النجم/الموسم/الدَّرّ (SPEC 7 معيار 4)', () {
    testWidgets('القيم فارغة: الملخص كاملاً و«نسخ» فقط، والنسخ يعمل '
        'بلا أي بيانات شخصية', (tester) async {
      phone(tester);
      await openReportFromDetail(tester, (
        target: const ItemTarget('suhail'),
        from: today,
      ));
      expect(inReport(find.text(l10n.reportTitle)), findsOneWidget);
      expect(find.text(l10n.reportIntroCopy), findsOneWidget);
      final lines = [
        l10n.reportItem(item('suhail')),
        l10n.reportRegion('نجد'),
        l10n.reportDate(gregorianDateLabel(l10n, today)),
        l10n.reportVersion('١.٠.٠+١'),
        l10n.reportDataVersion(meta.dataVersion, formatInteger(meta.dataSeq)),
      ];
      for (final line in lines) {
        expect(inSummary(find.text(line)), findsOneWidget, reason: line);
      }
      expect(find.byKey(ReportSheet.openFormKey), findsNothing);
      expect(find.text(l10n.reportOpenForm), findsNothing);
      expect(find.text(l10n.reportNothingSent), findsOneWidget);

      await tester.tap(find.byKey(ReportSheet.copyKey));
      await tester.pumpAndSettle();
      expect(copied, [lines.join('\n')]);
      expect(opened, isEmpty);
      expect(find.byKey(ReportSheet.copiedKey), findsOneWidget);
      expect(find.text(l10n.reportDetailsCopied), findsOneWidget);

      // لا مدينة ولا إحداثيات ولا معرّفات في البلاغ.
      final text = copied.single;
      final city = tables.city('riyadh')!;
      for (final banned in [
        city.name.ar,
        city.id,
        '${city.lat}',
        '${city.lon}',
        city.lat.toStringAsFixed(2),
        'suhail',
      ]) {
        expect(text, isNot(contains(banned)), reason: banned);
      }
    });

    testWidgets('نموذج بلا حقول: يُنسخ النص ويُفتح النموذج وتبقى الورقة '
        'برسالة «الصقها»', (tester) async {
      phone(tester);
      await openReportFromDetail(
        tester,
        (target: const ItemTarget('suhail'), from: today),
        formUrl: form,
      );
      expect(find.text(l10n.reportIntroFormPaste), findsOneWidget);
      expect(find.byKey(ReportSheet.copyKey), findsNothing);
      await tester.tap(find.byKey(ReportSheet.openFormKey));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(form)]);
      expect(copied, hasLength(1));
      expect(copied.single, contains(l10n.reportItem(item('suhail'))));
      expect(find.byKey(ReportSheet.sheetKey), findsOneWidget);
      expect(find.text(l10n.reportPasteHint), findsOneWidget);
    });

    testWidgets('نموذج بحقول: يُفتح معبأً مسبقاً وتُغلق الورقة', (tester) async {
      phone(tester);
      await openReportFromDetail(
        tester,
        (target: const ItemTarget('suhail'), from: today),
        formUrl: form,
        formFields: 'item=entry.1,region=entry.2,date=entry.3,'
            'appVersion=entry.4,dataVersion=entry.5',
      );
      expect(find.text(l10n.reportIntroForm), findsOneWidget);
      await tester.tap(find.byKey(ReportSheet.openFormKey));
      await tester.pumpAndSettle();
      expect(copied, isEmpty);
      expect(opened.single.queryParameters, {
        'entry.1': item('suhail'),
        'entry.2': 'نجد',
        'entry.3': '2026-10-02',
        'entry.4': version,
        'entry.5': '${meta.dataVersion} (${meta.dataSeq})',
      });
      expect(find.byKey(ReportSheet.sheetKey), findsNothing);
      // صفحة العنصر باقية خلفها.
      expect(find.byKey(ItemDetailSheet.sheetKey), findsOneWidget);
    });

    testWidgets('تعذّر فتح النموذج: رسالة ونافذة النسخ', (tester) async {
      phone(tester);
      opens = false;
      await openReportFromDetail(
        tester,
        (target: const ItemTarget('suhail'), from: today),
        formUrl: form,
        formFields: 'item=entry.1',
      );
      await tester.tap(find.byKey(ReportSheet.openFormKey));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(find.text(l10n.reportFormOpenError), findsOneWidget);
      expect(find.byKey(ReportSheet.openFormKey), findsNothing);
      await tester.tap(find.byKey(ReportSheet.copyKey));
      await tester.pumpAndSettle();
      expect(copied.single, contains(l10n.reportItem(item('suhail'))));
      expect(find.text(l10n.reportDetailsCopied), findsOneWidget);
    });

    testWidgets('رابط نموذج ليس https: يُعامل كغير مضبوط («نسخ» فقط)', (
      tester,
    ) async {
      phone(tester);
      await openReportFromDetail(
        tester,
        (target: const ItemTarget('suhail'), from: today),
        formUrl: 'http://docs.example.com/form',
      );
      expect(find.byKey(ReportSheet.openFormKey), findsNothing);
      expect(find.byKey(ReportSheet.copyKey), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('صفحة الدَّرّ: اسم الدَّرّ ومنطقة جدوله', (tester) async {
      phone(tester);
      final record = tables.regionTables['kuwait']!.durur[3];
      await openReportFromDetail(
        tester,
        (target: DarTarget('kuwait', record.start), from: today),
        city: 'kuwait_city',
      );
      expect(inSummary(find.text(l10n.reportItem(record.name.ar))), findsOneWidget);
      expect(
        inSummary(
          find.text(l10n.reportRegion(tables.region('kuwait')!.name.ar)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('تكبير الخط 200% على شاشة 320: بلا قص، وقارئ الشاشة', (
      tester,
    ) async {
      phone(tester, width: 320, height: 640);
      final handle = tester.ensureSemantics();
      await openReportFromDetail(
        tester,
        (target: const ItemTarget('suhail'), from: today),
        formUrl: form,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byKey(ReportSheet.sheetKey))),
        TextDirection.rtl,
      );
      expect(
        tester.getSemantics(inReport(find.text(l10n.reportTitle))),
        matchesSemantics(label: l10n.reportTitle, isHeader: true),
      );
      expect(find.bySemanticsLabel(l10n.reportOpenForm), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.commonClose), findsWidgets);
      // الزر الأساسي بارتفاع 52 على الأقل.
      expect(
        tester.getSize(find.byKey(ReportSheet.openFormKey)).height,
        greaterThanOrEqualTo(52),
      );
      await tester.tap(find.byKey(ReportSheet.closeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ReportSheet.sheetKey), findsNothing);
      handle.dispose();
    });
  });

  group('الإعدادات', () {
    testWidgets('صف «أبلغ عن خطأ» يفتح بلاغاً عاماً بلا عنصر', (tester) async {
      phone(tester);
      await pumpScreen(
        tester,
        const SettingsScreen(),
        prefs: await fakePrefs(savedCity('kuwait_city')),
        tables: tables,
        extra: reportOverrides(),
      );
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.reportRowKey),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsReport), findsOneWidget);
      await tester.tap(find.byKey(SettingsScreen.reportRowKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ReportSheet.sheetKey), findsOneWidget);
      expect(
        inSummary(find.textContaining(l10n.reportItem('').trim())),
        findsNothing,
      );
      expect(
        inSummary(
          find.text(l10n.reportRegion(tables.region('kuwait')!.name.ar)),
        ),
        findsOneWidget,
      );
      expect(
        inSummary(find.text(l10n.reportDate(gregorianDateLabel(l10n, today)))),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ReportSheet.copyKey));
      await tester.pumpAndSettle();
      expect(copied.single, isNot(contains(tables.city('kuwait_city')!.name.ar)));
    });
  });

  group('الرئيسية: خطأ الحساب (DESIGN 8.4)', () {
    testWidgets('«تعذّر حساب هذا اليوم.» + «أبلغ عن خطأ» يفتح بلاغاً عاماً', (
      tester,
    ) async {
      phone(tester);
      // جدول المنطقة غائب ← لا محرك ← لا نتيجة لليوم.
      final broken = Tables(
        meta: tables.meta,
        regions: tables.regions,
        itemList: tables.itemList,
        regionTables: {...tables.regionTables}..remove('najd'),
        cities: tables.cities,
        hijri: tables.hijri,
      );
      await pumpScreen(
        tester,
        const HomeScreen(),
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: broken,
        extra: reportOverrides(),
      );
      expect(find.text(l10n.homeCalcError), findsOneWidget);
      await tester.tap(find.byKey(HomeScreen.calcErrorReportKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ReportSheet.sheetKey), findsOneWidget);
      expect(inSummary(find.text(l10n.reportRegion('نجد'))), findsOneWidget);
      expect(
        inSummary(find.text(l10n.reportDate(gregorianDateLabel(l10n, today)))),
        findsOneWidget,
      );
    });
  });

  group('النسخ الفعلي', () {
    testWidgets('clipboardWriterProvider يكتب في حافظة النظام', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(clipboardWriterProvider)('نص البلاغ');
      final set = calls.where((c) => c.method == 'Clipboard.setData').single;
      expect((set.arguments as Map)['text'], 'نص البلاغ');
    });
  });
}
