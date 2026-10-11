// الاستخدام (من library/tools): dart run bin/validate.dart ../
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('الاستخدام: dart run bin/validate.dart <library-dir>');
    exit(64);
  }
  final r = validateLibrary(Directory(args[0]));
  for (final i in r.issues) {
    stderr.writeln(i);
  }
  if (r.ok) {
    stdout.writeln('OK: ${r.books} كتاب، ${r.paragraphs} فقرة، بلا أخطاء.');
  } else {
    stderr.writeln('فشل: ${r.issues.length} خطأ.');
    exit(1);
  }
}
