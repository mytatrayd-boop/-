// يتحقق من جداول assets/tables. الاستخدام (من داخل apps/durur):
//   dart run tool/validate_tables.dart            # تطوير: المسودات تحذير
//   dart run tool/validate_tables.dart --release  # إطلاق: أي سجل غير معتمد فشل
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:durur/src/engine/table_validator.dart';
import 'package:durur/src/repository/tables_loader.dart';

Future<void> main(List<String> args) async {
  final release = args.contains('--release');
  try {
    final tables =
        await TablesLoader((path) => File(path).readAsString()).load();
    final report = const TableValidator().validate(tables, release: release);
    for (final w in report.warnings) {
      print('تحذير: $w');
    }
    for (final e in report.errors) {
      stderr.writeln('خطأ: $e');
    }
    if (!report.isValid) {
      stderr.writeln('فشل التحقق (${report.errors.length} خطأ).');
      exit(1);
    }
    print('الجداول سليمة${release ? ' ومعتمدة للإطلاق' : ''}. '
        '(نسخة البيانات ${tables.meta.dataVersion})');
  } on Object catch (e) {
    stderr.writeln('خطأ في قراءة الجداول: $e');
    exit(1);
  }
}
