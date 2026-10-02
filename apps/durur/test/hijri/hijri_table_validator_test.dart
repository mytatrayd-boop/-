import 'dart:convert';
import 'dart:io';

import 'package:durur/src/hijri/hijri_table_validator.dart';
import 'package:durur/src/hijri/umm_al_qura_calendar.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// مدقق جدول أم القرى (ARCHITECTURE §16.6، D22)، ومنه قاعدة التحديث:
/// لا تتغير بداية أي شهر بأكثر من يوم عن الجدول المضمّن.
void main() {
  const validator = HijriTableValidator();
  final raw = jsonDecode(File(TablesLoader.hijriPath).readAsStringSync())
      as Map<String, dynamic>;
  final embedded = UmmAlQuraCalendar.fromJson(raw);
  final starts = [...raw['monthStarts'] as List<dynamic>].cast<String>();

  /// جدول من الملف المضمّن بعد تعديل JSON.
  UmmAlQuraCalendar table({
    List<String>? monthStarts,
    Map<String, Object?> fields = const {},
  }) =>
      UmmAlQuraCalendar.fromJson({
        ...raw,
        ...fields,
        'monthStarts': ?monthStarts,
      });

  String shift(String iso, int days) => formatIsoDate(
      parseIsoDate(iso, 'test').add(Duration(days: days)));

  List<String> shiftedAll(int days) => [for (final s in starts) shift(s, days)];

  /// إزاحة بداية شهر واحد (يغيّر طول الشهر قبله وبعده).
  List<String> shiftedOne(int index, int days) =>
      [...starts]..[index] = shift(starts[index], days);

  test('الجدول المضمّن سليم، ومع نفسه كمضمّن', () {
    expect(validator.validate(embedded), isEmpty);
    expect(validator.validate(embedded, embedded: embedded), isEmpty);
  });

  group('أطوال الأشهر والسنوات', () {
    test('شهر 31 يوماً (فجوة) ← خطأ', () {
      // 1446/2 يبدأ متأخراً يوماً: محرم 30→31 أو 29→30 ثم صفر يقصر.
      final i = _firstMonthOfLength(embedded, 30);
      final errors = validator.validate(
          table(monthStarts: shiftedOne(i + 1, 1)));
      expect(errors.any((e) => e.contains('طوله 31')), isTrue,
          reason: '$errors');
    });

    test('شهر 28 يوماً ← خطأ', () {
      final i = _firstMonthOfLength(embedded, 29);
      final errors = validator.validate(
          table(monthStarts: shiftedOne(i + 1, -1)));
      expect(errors.any((e) => e.contains('طوله 28')), isTrue,
          reason: '$errors');
    });

    test('بدايات غير متزايدة (تداخل) ← خطأ', () {
      final s = [...starts]..[5] = starts[4];
      final errors = validator.validate(table(monthStarts: s));
      expect(errors.any((e) => e.contains('طوله 0')), isTrue,
          reason: '$errors');
    });

    test('سنة كل أشهرها 29 يوماً (348) ← خطأ طول السنة', () {
      var d = parseIsoDate(starts.first, 'test');
      final s = <String>[];
      for (var i = 0; i <= 12 * 21; i++) {
        s.add(formatIsoDate(d));
        // السنة الأولى كلها 29، والباقي بالتناوب 30/29.
        d = d.add(Duration(days: i < 12 ? 29 : (i.isEven ? 30 : 29)));
      }
      final errors = validator.validate(table(
        monthStarts: s,
        fields: {'verifiedThrough': null},
      ));
      expect(errors.any((e) => e.contains('السنة 1446 طولها 348')), isTrue,
          reason: '$errors');
    });
  });

  group('المدى', () {
    test('لا يبدأ بمحرم ← خطأ', () {
      final errors = validator.validate(table(
        monthStarts: starts.sublist(1, starts.length),
        fields: {'firstMonth': 2},
      ));
      expect(errors.any((e) => e.contains('سنوات هجرية كاملة')), isTrue);
    });

    test('سنة ناقصة في النهاية ← خطأ', () {
      final errors = validator.validate(
          table(monthStarts: starts.sublist(0, starts.length - 1)));
      expect(errors.any((e) => e.contains('سنوات هجرية كاملة')), isTrue);
    });

    test('لا يغطي حتى 2040-12-31 ← خطأ', () {
      // 1446..1461 (16 سنة) ينتهي قبل 2040.
      final errors = validator.validate(
          table(monthStarts: starts.sublist(0, 16 * 12 + 1)));
      expect(errors.any((e) => e.contains('2040-12-31')), isTrue,
          reason: '$errors');
    });

    test('يبدأ بعد 2025-01-01 ← خطأ', () {
      final errors = validator.validate(table(
        monthStarts: starts.sublist(12),
        fields: {'firstYear': 1447},
      ));
      expect(errors.any((e) => e.contains('2025-01-01')), isTrue,
          reason: '$errors');
    });

    test('نوع تقويم آخر ← خطأ', () {
      final errors =
          validator.validate(table(fields: {'calendar': 'islamic_civil'}));
      expect(errors, hasLength(1));
      expect(errors.single, contains('islamic_civil'));
    });

    test('verifiedThrough خارج المدى ← خطأ', () {
      final errors =
          validator.validate(table(fields: {'verifiedThrough': '2050-01-01'}));
      expect(errors.single, contains('verifiedThrough'));
    });
  });

  group('قاعدة التحديث: فرق يوم واحد كحد أقصى عن المضمّن', () {
    test('إزاحة بداية شهر يوماً واحداً مقبولة', () {
      // بداية 1 محرم 1452 (خلاف معروف بين المصادر، STATUS.md).
      final i = embedded.indexOf(1452, 1)!;
      final len = embedded.monthStarts[i]
          .difference(embedded.monthStarts[i - 1])
          .inDays;
      // تأخير يوم إن كان الشهر السابق 29، وإلا تقديم يوم.
      final candidate =
          table(monthStarts: shiftedOne(i, len == 29 ? 1 : -1));
      expect(validator.validate(candidate, embedded: embedded), isEmpty);
    });

    test('إزاحة كل الجدول يوماً مقبولة، ويومين مرفوضة', () {
      expect(
        validator.validate(table(monthStarts: shiftedAll(1)),
            embedded: embedded),
        isEmpty,
      );
      final errors = validator.validate(
        table(monthStarts: shiftedAll(-2)),
        embedded: embedded,
      );
      // أطوال الأشهر سليمة؛ الرفض بقاعدة الإزاحة وحدها.
      expect(validator.validate(table(monthStarts: shiftedAll(-2))), isEmpty);
      expect(errors, hasLength(starts.length));
      expect(errors.first, contains('بـ 2 أيام'));
    });

    test('بلا جدول مضمّن لا تُطبَّق قاعدة الإزاحة', () {
      expect(validator.validate(table(monthStarts: shiftedAll(-2))), isEmpty);
    });

    test('تُقارن الأشهر المشتركة فقط إن اختلف المدى', () {
      // تحديث يبدأ من 1447 ويمتد سنة بعد المضمّن.
      final ext = [...starts.sublist(12)];
      var d = parseIsoDate(starts.last, 'test');
      for (var k = 0; k < 12; k++) {
        d = d.add(Duration(days: k.isEven ? 29 : 30));
        ext.add(formatIsoDate(d));
      }
      final candidate =
          table(monthStarts: ext, fields: {'firstYear': 1447});
      final errors = validator.validate(candidate, embedded: embedded);
      expect(errors.where((e) => e.contains('المضمّن')), isEmpty);
    });
  });
}

int _firstMonthOfLength(UmmAlQuraCalendar c, int length) {
  for (var i = 0; i < c.monthCount; i++) {
    if (c.monthStarts[i + 1].difference(c.monthStarts[i]).inDays == length) {
      return i;
    }
  }
  throw StateError('لا شهر بطول $length');
}
