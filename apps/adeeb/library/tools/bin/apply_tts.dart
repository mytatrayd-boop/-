// الاستخدام (من library/tools):
//   dart run bin/apply_tts.dart <library-dir> <part.json>...
// يكتب `tts` (من أجزاء tool/diacritize_tts.py) في إصدار جديد لكل كتاب تغيّر،
// ثم شغّل build_catalog.dart وvalidate.dart.
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('الاستخدام: dart run bin/apply_tts.dart <library-dir> <part.json>...');
    exit(64);
  }
  final root = Directory(args[0]);
  final tts = loadTtsParts(args.skip(1).map(File.new));
  final ids = latestBookFiles(root).map((f) => f.uri.pathSegments.last.split('.').first);
  for (final id in ids) {
    final r = applyTts(root, id, tts);
    stdout.writeln(r.file == null
        ? '$id: v${r.fromVersion} بلا تغيير (${r.withTts} فقرة بـ tts)'
        : '$id: v${r.fromVersion} → v${r.toVersion}، ${r.withTts} فقرة بـ tts');
  }
}
