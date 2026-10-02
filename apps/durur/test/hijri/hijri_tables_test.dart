import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/features/home/day_text.dart';
import 'package:durur/src/hijri/umm_al_qura_calendar.dart';
import 'package:durur/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import '../helpers/app_harness.dart';
import '../helpers/hijri_asset.dart';

/// ربط جدول أم القرى بالجداول والمدقق والمزوّدات والواجهة (الميزة 2ب).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final assetTables = await loadAssetTables();
  final hijri = loadAssetHijriCalendar();

  Tables withHijri(UmmAlQuraCalendar? calendar) {
    final f = fixtureTables();
    return Tables(
      meta: f.meta,
      regions: f.regions,
      itemList: f.itemList,
      regionTables: f.regionTables,
      cities: f.cities,
      hijri: calendar,
    );
  }

  group('الجداول', () {
    test('TablesLoader يحمّل hijri_umm_al_qura.json مع الجداول', () {
      expect(assetTables.hijri, isNotNull);
      expect(assetTables.hijri!.monthStarts, hijri.monthStarts);
      expect(assetTables.allRecords, contains(assetTables.hijri));
    });

    test('meta.json فيه dataSeq = 0 (لم تُنشر حزمة بعد)', () {
      expect(assetTables.meta.dataSeq, 0);
    });

    test('dataSeq اختياري (0) ولا يقبل سالباً', () {
      expect(
        TablesMeta.fromJson({'schemaVersion': 1, 'dataVersion': 'x'}).dataSeq,
        0,
      );
      expect(
        TablesMeta.fromJson({
          'schemaVersion': 1,
          'dataVersion': 'x',
          'dataSeq': 7,
        }).dataSeq,
        7,
      );
      expect(
        () => TablesMeta.fromJson({
          'schemaVersion': 1,
          'dataVersion': 'x',
          'dataSeq': -1,
        }),
        throwsFormatException,
      );
    });
  });

  group('TableValidator يشمل مدقق الهجري', () {
    test('جدول سليم: لا أخطاء في التطوير، ومسودته تمنع الإطلاق', () {
      final t = withHijri(hijri);
      expect(const TableValidator().validate(t).errors, isEmpty);
      final release = const TableValidator().validate(t, release: true).errors;
      expect(release, hasLength(1));
      expect(release.single, contains(UmmAlQuraCalendar.file));
    });

    test('جدول معيب: خطأ الهجري يظهر في التقرير', () {
      final starts = [...hijri.monthStarts]..removeLast();
      final broken = UmmAlQuraCalendar(
        calendar: hijri.calendar,
        firstYear: hijri.firstYear,
        firstMonth: hijri.firstMonth,
        monthStarts: starts,
        source: hijri.source,
        approval: hijri.approval,
      );
      final errors = const TableValidator().validate(withHijri(broken)).errors;
      expect(errors.any((e) => e.contains(UmmAlQuraCalendar.file)), isTrue);
    });
  });

  group('المزوّد والواجهة', () {
    test('hijriCalendarProvider = جدول الجداول المحمّلة', () async {
      final container = ProviderContainer(
        overrides: appOverrides(await fakePrefs(), assetTables),
      );
      addTearDown(container.dispose);
      expect(container.read(hijriCalendarProvider), isNull); // أثناء التحميل
      await container.read(tablesProvider.future);
      expect(container.read(hijriCalendarProvider), same(assetTables.hijri));
    });

    // الرئيسية صارت تحصر التاريخ في 2025–2040 (الميزة 6)، فحالة «خارج مدى
    // الجدول» تُختبر في دالة سطر التاريخين التي تستخدمها الرئيسية.
    final l10n = lookupAppLocalizations(const Locale('ar'));

    test('تاريخ خارج مدى الجدول: يُحذف الهجري ويبقى الميلادي', () {
      expect(
        datesLine(l10n, DateTime(2050, 1, 1), hijri, isToday: true),
        'السبت ١ يناير ٢٠٥٠م',
      );
    });

    test('آخر يوم في الجدول يُعرض هجرياً', () {
      final line = datesLine(l10n, hijri.lastDay, hijri, isToday: true);
      expect(line, contains('—'));
      expect(line, endsWith('هـ'));
    });
  });
}
