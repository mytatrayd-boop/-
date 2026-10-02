// يولّد assets/tables/hijri_umm_al_qura.json (بدايات أشهر أم القرى 1446–1466)
// من مكتبة hijri (أداة تطوير فقط، D22). الاستخدام (من داخل apps/durur):
//   dart run tool/gen_hijri_table.dart           # يرفض الكتابة فوق ملف موجود
//   dart run tool/gen_hijri_table.dart --force   # يعيد التوليد ويكتب فوقه
//   dart run tool/gen_hijri_table.dart --stdout  # يطبع الناتج فقط
// بعد التوليد الأول الحقيقة هي الملف لا المكتبة (ARCHITECTURE §16.6)؛
// إعادة التوليد تمحو أي تصحيح أو اعتماد في الملف، فلا تُستخدم إلا عمداً.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:durur/src/hijri/hijri_table_validator.dart';
import 'package:durur/src/hijri/umm_al_qura_calendar.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:hijri/hijri_calendar.dart';

const firstYear = 1446;
const lastYear = 1466;

/// آخر يوم اتفقت عليه كل المصادر المقارنة (STATUS.md، D22).
const verifiedThrough = '2029-08-10';

/// نسخة المكتبة المثبّتة في pubspec.lock وقت التوليد.
const hijriPackageVersion = '3.0.1';

/// محتوى الملف (JSON محلَّل) من المكتبة.
Map<String, Object?> generateHijriTableJson() {
  final calendar = HijriCalendar();
  final starts = <String>[
    for (var y = firstYear; y <= lastYear; y++)
      for (var m = 1; m <= 12; m++)
        formatIsoDate(calendar.hijriToGregorian(y, m, 1)),
    // الحارس: بداية الشهر التالي لآخر شهر.
    formatIsoDate(calendar.hijriToGregorian(lastYear + 1, 1, 1)),
  ];
  return {
    'calendar': UmmAlQuraCalendar.ummAlQura,
    'firstYear': firstYear,
    'firstMonth': 1,
    'monthStarts': starts,
    'source': {
      'title': 'تقويم أم القرى: بدايات الأشهر من جدول R. H. van Gent '
          'كما في مكتبة hijri $hijriPackageVersion (مولّد آلياً بـ '
          'tool/gen_hijri_table.dart)',
      'author': 'R. H. van Gent',
      'year': null,
      'page': null,
      'url': 'https://pub.dev/packages/hijri/versions/$hijriPackageVersion',
    },
    'approval': {'status': 'draft', 'reviewer': null, 'date': null},
    'verifiedThrough': verifiedThrough,
  };
}

/// JSON منسّق: كل تاريخ في سطر ليسهل على المراجع قراءة الفروق.
String encodeHijriTable(Map<String, Object?> json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';

Future<void> main(List<String> args) async {
  final json = generateHijriTableJson();
  final errors =
      const HijriTableValidator().validate(UmmAlQuraCalendar.fromJson(json));
  if (errors.isNotEmpty) {
    for (final e in errors) {
      stderr.writeln('خطأ: $e');
    }
    exit(1);
  }
  final text = encodeHijriTable(json);
  if (args.contains('--stdout')) {
    stdout.write(text);
    return;
  }
  final file = File(TablesLoader.hijriPath);
  if (file.existsSync() && !args.contains('--force')) {
    stderr.writeln('${file.path} موجود. استخدم --force لإعادة التوليد '
        '(يمحو أي تصحيح أو اعتماد فيه).');
    exit(1);
  }
  await file.writeAsString(text);
  print('كُتب ${file.path}: ${(json['monthStarts']! as List).length - 1} '
      'شهراً ($firstYear–$lastYear) + حارس.');
}
