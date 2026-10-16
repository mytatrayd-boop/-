// الاستخدام (من library/tools):
//   dart run bin/validate.dart ../                          مكتبة التطبيق الحالية (schema 1)
//   dart run bin/validate.dart --v2 <dir> [--recipes recipes]  المكتبة الكبيرة (schema 2، الصيغة 2)
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  final v2 = args.contains('--v2');
  final ri = args.indexOf('--recipes');
  final pos = [
    for (var i = 0; i < args.length; i++)
      if (args[i] != '--v2' && args[i] != '--recipes' && (ri < 0 || i != ri + 1)) args[i],
  ];
  if (pos.length != 1) {
    stderr.writeln('الاستخدام: dart run bin/validate.dart [--v2 [--recipes recipes]] <library-dir>');
    exit(64);
  }
  final r = v2
      ? validateLibraryV2(Directory(pos[0]),
          exceptions: loadRecipeExceptions(Directory(ri >= 0 ? args[ri + 1] : 'recipes')))
      : validateLibrary(Directory(pos[0]));
  for (final i in r.issues) {
    stderr.writeln(i);
  }
  if (r.ok) {
    stdout.writeln('OK: ${r.books} كتاب، ${r.paragraphs} فقرة، بلا أخطاء'
        '${r.warnings.isEmpty ? '' : '، ${r.warnings.length} تحذير للمراجعة في العيّنة'}.');
  } else {
    stderr.writeln('فشل: ${r.errors.length} خطأ، ${r.warnings.length} تحذير.');
    exit(1);
  }
}
