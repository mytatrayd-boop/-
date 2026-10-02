import 'dart:convert';
import 'dart:io';

import 'package:durur/src/hijri/hijri_date.dart';
import 'package:durur/src/hijri/hijri_table_validator.dart';
import 'package:durur/src/hijri/umm_al_qura_calendar.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../tool/gen_hijri_table.dart' as gen;
import '../helpers/hijri_asset.dart';

/// الميزة 2ب (D22، ARCHITECTURE §16.6): أم القرى كجدول بيانات.
void main() {
  final calendar = loadAssetHijriCalendar();
  final rawJson = jsonDecode(File(TablesLoader.hijriPath).readAsStringSync())
      as Map<String, dynamic>;

  group('الجدول المضمّن', () {
    test('المدى 1446/1 حتى 1466/12 بسنوات كاملة وحارس', () {
      expect(calendar.calendar, UmmAlQuraCalendar.ummAlQura);
      expect(calendar.firstYear, 1446);
      expect(calendar.firstMonth, 1);
      expect(calendar.monthCount, 21 * 12);
      expect(calendar.monthStarts, hasLength(21 * 12 + 1));
      expect(calendar.monthAt(calendar.monthCount - 1), (1466, 12));
      expect(calendar.firstDay, DateTime.utc(2024, 7, 7));
      expect(calendar.tryConvert(calendar.lastDay)!.year, 1466);
    });

    test('يجتاز مدقق الهجري', () {
      expect(const HijriTableValidator().validate(calendar), isEmpty);
    });

    test('verifiedThrough = 2029-08-10، والسجل مسودة بمصدر', () {
      expect(calendar.verifiedThrough, DateTime.utc(2029, 8, 10));
      expect(calendar.approval.isApproved, isFalse);
      expect(calendar.source.title.trim(), isNotEmpty);
    });

    test('بدايات الأشهر في الملف = ناتج أداة التوليد', () {
      final generated = gen.generateHijriTableJson();
      expect(rawJson['monthStarts'], generated['monthStarts']);
      expect(rawJson['firstYear'], generated['firstYear']);
      expect(rawJson['firstMonth'], generated['firstMonth']);
      expect(rawJson['calendar'], generated['calendar']);
    });
  });

  group('التطابق مع مكتبة hijri', () {
    test('كل بداية شهر (والحارس) = hijriToGregorian في المكتبة', () {
      final lib = HijriCalendar();
      for (var i = 0; i <= calendar.monthCount; i++) {
        final (y, m) = calendar.monthAt(i);
        final expected = lib.hijriToGregorian(y, m, 1);
        expect(
          formatIsoDate(calendar.monthStarts[i]),
          formatIsoDate(expected),
          reason: 'بداية $m/$y',
        );
      }
    });

    test('يوماً بيوم في المدى كله (2024-07-07 حتى آخر 1466)', () {
      var days = 0;
      for (var d = calendar.firstDay;
          !d.isAfter(calendar.lastDay);
          d = d.add(const Duration(days: 1))) {
        final h = HijriCalendar.fromDate(DateTime(d.year, d.month, d.day));
        expect(
          HijriDate.fromGregorian(d, calendar),
          HijriDate(h.hYear, h.hMonth, h.hDay),
          reason: formatIsoDate(d),
        );
        days++;
      }
      // 21 سنة هجرية ≈ 7442 يوماً.
      expect(days, inInclusiveRange(21 * 354, 21 * 355));
    });

    test('لا يستورد كود التطبيق (lib/) مكتبة hijri، وهي في dev_dependencies',
        () {
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('package:hijri/'))
            f.path,
      ];
      expect(offenders, isEmpty);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final devStart = pubspec.indexOf('\ndev_dependencies:');
      expect(devStart, greaterThan(0));
      expect(pubspec.indexOf(RegExp(r'\n  hijri:')), greaterThan(devStart));
    });
  });

  group('التحويل', () {
    test('حدود الجدول: أول يوم وآخر يوم، وخارجهما null أو RangeError', () {
      expect(calendar.tryConvert(DateTime(2024, 7, 7)),
          const HijriDate(1446, 1, 1));
      final last = calendar.tryConvert(calendar.lastDay)!;
      expect((last.year, last.month), (1466, 12));
      expect(last.day, anyOf(29, 30));

      final before = DateTime(2024, 7, 6);
      final after = calendar.monthStarts.last;
      expect(calendar.tryConvert(before), isNull);
      expect(calendar.tryConvert(after), isNull);
      expect(() => calendar.convert(before), throwsRangeError);
      expect(() => HijriDate.fromGregorian(after, calendar), throwsRangeError);
    });

    test('يتجاهل الوقت والمنطقة الزمنية', () {
      expect(calendar.tryConvert(DateTime(2026, 2, 18, 23, 59, 59)),
          const HijriDate(1447, 9, 1));
      expect(calendar.tryConvert(DateTime.utc(2026, 2, 17, 23, 59)),
          const HijriDate(1447, 8, 29));
    });

    test('monthStart و indexOf', () {
      expect(calendar.monthStart(1448, 1), DateTime.utc(2026, 6, 16));
      expect(calendar.monthStart(1445, 12), isNull);
      expect(calendar.monthStart(1467, 1), isNull);
      expect(calendar.indexOf(1446, 1), 0);
      expect(calendar.indexOf(1466, 12), 251);
    });

    test('جدول يبدأ من منتصف سنة يحسب السنة والشهر صحيحاً', () {
      final t = UmmAlQuraCalendar.fromJson({
        ...rawJson,
        'firstYear': 1446,
        'firstMonth': 11,
        'monthStarts': ['2025-04-29', '2025-05-28', '2025-06-26'],
      });
      expect(t.tryConvert(DateTime(2025, 4, 29)), const HijriDate(1446, 11, 1));
      expect(t.tryConvert(DateTime(2025, 6, 25)), const HijriDate(1446, 12, 29));
      expect(t.tryConvert(DateTime(2025, 6, 26)), isNull);
    });
  });

  group('قراءة JSON', () {
    Map<String, dynamic> withField(String key, Object? value) =>
        {...rawJson, key: value};

    test('يرفض تاريخاً غير موجود أو بصيغة أخرى', () {
      for (final bad in ['2025-02-30', '2025-2-1', '2025/02/01', 20250201]) {
        final starts = [...rawJson['monthStarts'] as List]..[3] = bad;
        expect(
          () => UmmAlQuraCalendar.fromJson(withField('monthStarts', starts)),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('يرفض حقولاً مفقودة أو غير صالحة', () {
      expect(() => UmmAlQuraCalendar.fromJson(withField('firstYear', null)),
          throwsFormatException);
      expect(() => UmmAlQuraCalendar.fromJson(withField('firstMonth', 13)),
          throwsFormatException);
      expect(() => UmmAlQuraCalendar.fromJson(withField('monthStarts', null)),
          throwsFormatException);
      expect(
          () => UmmAlQuraCalendar.fromJson(
              withField('monthStarts', ['2024-07-07'])),
          throwsFormatException);
      expect(() => UmmAlQuraCalendar.fromJson(withField('approval', null)),
          throwsFormatException);
      expect(
          () => UmmAlQuraCalendar.fromJson(
              withField('verifiedThrough', '2029-13-01')),
          throwsFormatException);
      expect(() => UmmAlQuraCalendar.fromJson([]), throwsFormatException);
    });

    test('verifiedThrough اختياري', () {
      expect(
        UmmAlQuraCalendar.fromJson(withField('verifiedThrough', null))
            .verifiedThrough,
        isNull,
      );
    });
  });
}
