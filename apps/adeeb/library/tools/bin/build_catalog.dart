// الاستخدام (من library/tools): dart run bin/build_catalog.dart ../ --date YYYY-MM-DD
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  final i = args.indexOf('--date');
  final pos = args.where((a) => !a.startsWith('--')).toList();
  if (i < 0 || i + 1 >= args.length || pos.length != 2) {
    stderr.writeln('الاستخدام: dart run bin/build_catalog.dart <library-dir> --date YYYY-MM-DD');
    exit(64);
  }
  final text = buildCatalog(Directory(pos[0]), date: args[i + 1]);
  stdout.write(text);
}
