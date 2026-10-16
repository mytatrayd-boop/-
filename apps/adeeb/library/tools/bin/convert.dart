// الاستخدام (من library/tools): dart run bin/convert.dart recipes/<id>.json ../ [--overwrite]
// يحوّل المصدر المخزّن (بلا شبكة) إلى books/<id>/<id>.v<N>.json.gz ويطبع ما حُذف.
// الوصفة بصيغة ويكي مصدر (D17) أو OpenITI ("format": "openiti"، D21).
//
// الوضع الآلي (D31، ARCHITECTURE §18.3):
//   dart run bin/convert.dart --auto <selection.tsv> <sources-dir> <out-dir> --date YYYY-MM-DD
//       [--scope scope.yaml] [--registry ../registry.tsv] [--limit 100 [--spread]]
// يحوّل الكتب المدرجة بالوصفة الافتراضية ويحكم عليها بالبوابات، ويكتب في <out-dir> الكتب
// المقبولة والمحالة للمراجعة و report.json وreport.md. لا ينشر شيئاً.
import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  if (args.contains('--auto')) {
    _auto(args);
    return;
  }
  final pos = args.where((a) => !a.startsWith('--')).toList();
  if (pos.length != 2) {
    stderr.writeln('الاستخدام: dart run bin/convert.dart recipes/<id>.json <library-dir> [--overwrite]');
    exit(64);
  }
  final recipeFile = File(pos[0]);
  final overwrite = args.contains('--overwrite');
  final json = jsonDecode(recipeFile.readAsStringSync()) as Map<String, Object?>;
  final cacheRoot = '${recipeFile.absolute.parent.parent.path}/.cache';
  try {
    late final ConvertOutput out;
    late final String id;
    late final int version;
    late final Map<String, List<String>> exceptions;
    if (OpenitiRecipe.isOpenitiJson(json)) {
      final recipe = OpenitiRecipe.fromJson(json);
      final src = openitiCacheFile(Directory('$cacheRoot/${recipe.id}'));
      if (!src.existsSync()) {
        throw StateError('المصدر غير مخزّن: ${src.path}. شغّل bin/fetch_openiti.dart أولاً.');
      }
      out = writeBookToLibrary(buildOpenitiBook(recipe, src.readAsBytesSync()), recipe.id, recipe.version,
          Directory(pos[1]),
          overwrite: overwrite);
      (id, version, exceptions) = (recipe.id, recipe.version, recipe.validationExceptions);
    } else {
      final recipe = Recipe.fromJson(json);
      out = convertToLibrary(recipe, loadCache(recipe, Directory('$cacheRoot/${recipe.id}')), Directory(pos[1]),
          overwrite: overwrite);
      (id, version, exceptions) = (recipe.id, recipe.version, recipe.validationExceptions);
    }
    final all = validateBookBytes(out.json, out.file.path,
        expectedId: id,
        expectedVersion: version,
        exceptions: {for (final e in exceptions.entries) e.key: e.value.toSet()});
    final issues = all.where((i) => !i.warning).toList();
    final warnings = all.where((i) => i.warning).toList();
    stdout.writeln('كُتب ${out.file.path}');
    stdout.writeln('الأبواب: ${out.result.chapters.length}، الفقرات: ${out.result.paragraphCount}، '
        'الحجم: ${out.gz.length} بايت مضغوط / ${out.json.length} غير مضغوط');
    stdout.writeln('المحذوف والمعالَج:');
    for (final l in out.result.stats.lines()) {
      stdout.writeln('  $l');
    }
    if (warnings.isNotEmpty) {
      stdout.writeln('تحذيرات للمراجعة (${warnings.length}، تظهر في العيّنة):');
      for (final w in warnings.take(50)) {
        stdout.writeln('  $w');
      }
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

void _auto(List<String> args) {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final pos = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (const ['--auto', '--spread'].contains(args[i])) continue;
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    pos.add(args[i]);
  }
  final date = opt('--date');
  if (pos.length != 3 || date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    stderr.writeln('الاستخدام: dart run bin/convert.dart --auto <selection.tsv> <sources-dir> <out-dir> '
        '--date YYYY-MM-DD [--scope scope.yaml] [--registry ../registry.tsv] [--limit N]');
    exit(64);
  }
  final out = Directory(pos[2])..createSync(recursive: true);
  final report = runAutoBatch(
    selection: parseSelectionTsv(File(pos[0]).readAsStringSync()),
    sourcesDir: Directory(pos[1]),
    outDir: out,
    scope: Scope.load(File(opt('--scope') ?? 'scope.yaml')),
    registry: Registry.load(File(opt('--registry') ?? '../registry.tsv')),
    date: date,
    limit: int.tryParse(opt('--limit') ?? ''),
    spread: args.contains('--spread'),
  );
  File('${out.path}/report.json').writeAsStringSync(report.toJson());
  File('${out.path}/report.md').writeAsStringSync(report.toMarkdown());
  stdout.writeln('accept: ${report.count(GateDecision.accept)}، review: ${report.count(GateDecision.review)}، '
      'reject: ${report.count(GateDecision.reject)}');
  for (final d in [GateDecision.reject, GateDecision.review]) {
    report.reasonCounts(d).forEach((k, v) => stdout.writeln('  ${d.name} [$k]: $v'));
  }
}
