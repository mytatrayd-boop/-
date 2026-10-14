// الاستخدام (من library/tools):
// dart run bin/sample.dart ../books/<id>/<id>.v<N>.json.gz [كتب أخرى...] [--count 20] [--seed 1] > ../SAMPLE_REVIEW.md
// العدد الافتراضي 20 (SPEC). استثناءات التحقق تُقرأ من recipes/<id>.json إن وُجدت.
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
  if (pos.isEmpty) {
    stderr.writeln('الاستخدام: dart run bin/sample.dart <book.json.gz>... [--count 20] [--seed 1]');
    exit(64);
  }
  final recipesDir = Directory('${File(Platform.script.toFilePath()).parent.parent.path}/recipes');
  final allEx = loadRecipeExceptions(recipesDir);
  // عدة كتب: قسم لكل كتاب بالترتيب المعطى، والبذرة نفسها لكل كتاب.
  for (var k = 0; k < pos.length; k++) {
    final book = decodeGzJson(File(pos[k]).readAsBytesSync());
    if (k > 0) stdout.writeln();
    stdout.write(buildSampleMarkdown(book,
        count: opt('--count', defaultSampleCount), seed: opt('--seed', 1), exceptions: allEx[book['id']] ?? const {}));
  }
}
