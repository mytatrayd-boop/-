// الاستخدام (من library/tools):
// dart run bin/sample.dart ../books/<id>/<id>.v<N>.json.gz --count 10 --seed 1 > ../SAMPLE_REVIEW.md
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  int opt(String name, int def) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? int.parse(args[i + 1]) : def;
  }

  final pos = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      i++;
    } else {
      pos.add(args[i]);
    }
  }
  if (pos.length != 1) {
    stderr.writeln('الاستخدام: dart run bin/sample.dart <book.json.gz> [--count 10] [--seed 1]');
    exit(64);
  }
  final book = decodeGzJson(File(pos[0]).readAsBytesSync());
  stdout.write(buildSampleMarkdown(book, count: opt('--count', 10), seed: opt('--seed', 1)));
}
