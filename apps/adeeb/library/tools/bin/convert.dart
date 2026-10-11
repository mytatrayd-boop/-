// الاستخدام (من library/tools): dart run bin/convert.dart recipes/<id>.json ../ [--overwrite]
// يحوّل النص المخزّن (بلا شبكة) إلى books/<id>/<id>.v<N>.json.gz ويطبع ما حُذف.
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  final pos = args.where((a) => !a.startsWith('--')).toList();
  if (pos.length != 2) {
    stderr.writeln('الاستخدام: dart run bin/convert.dart recipes/<id>.json <library-dir> [--overwrite]');
    exit(64);
  }
  final recipeFile = File(pos[0]);
  final recipe = Recipe.load(recipeFile);
  final cache = Directory('${recipeFile.absolute.parent.parent.path}/.cache/${recipe.id}');
  try {
    final out = convertToLibrary(
      recipe,
      loadCache(recipe, cache),
      Directory(pos[1]),
      overwrite: args.contains('--overwrite'),
    );
    final issues = validateBookBytes(out.json, out.file.path, expectedId: recipe.id, expectedVersion: recipe.version);
    stdout.writeln('كُتب ${out.file.path}');
    stdout.writeln('الأبواب: ${out.result.chapters.length}، الفقرات: ${out.result.paragraphCount}، '
        'الحجم: ${out.gz.length} بايت مضغوط / ${out.json.length} غير مضغوط');
    stdout.writeln('المحذوف:');
    for (final l in out.result.stats.lines()) {
      stdout.writeln('  $l');
    }
    if (issues.isNotEmpty) {
      stderr.writeln('أخطاء التحقق (${issues.length}):');
      for (final i in issues.take(50)) {
        stderr.writeln('  $i');
      }
      exit(1);
    }
  } on WikitextException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
}
