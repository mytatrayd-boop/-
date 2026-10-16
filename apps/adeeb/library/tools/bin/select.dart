// الاستخدام (من library/tools):
//   dart run bin/select.dart <metadata.tsv> [--scope scope.yaml] [--registry ../registry.tsv]
//       [--out selection.tsv] [--sample 50 --seed 2028]
// يصنّف كل نسخة في TSV إصدار OpenITI حسب scope.yaml (D30، ARCHITECTURE §18.2) ويكتب القائمة
// مع القرار والسبب لكل نسخة. حتمي. يرفض ملف TSV لا يطابق sha256 المثبّت في scope.yaml.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final pos = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (const ['--any-metadata'].contains(args[i])) continue;
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    pos.add(args[i]);
  }
  if (pos.length != 1) {
    stderr.writeln('الاستخدام: dart run bin/select.dart <metadata.tsv> [--scope scope.yaml] '
        '[--registry ../registry.tsv] [--out selection.tsv] [--sample N --seed S]');
    exit(64);
  }
  final scope = Scope.load(File(opt('--scope') ?? 'scope.yaml'));
  final bytes = File(pos[0]).readAsBytesSync();
  final digest = sha256.convert(bytes).toString();
  if (digest != scope.metadataSha256 && !args.contains('--any-metadata')) {
    stderr.writeln('sha256 لملف TSV ($digest) لا يطابق scope.yaml (${scope.metadataSha256}).');
    exit(1);
  }
  final registry = Registry.load(File(opt('--registry') ?? '../registry.tsv'));
  final sel = selectBooks(scope, parseMetadataTsv(utf8.decode(bytes)), registry);
  final out = opt('--out');
  if (out != null) File(out).writeAsStringSync(selectionToTsv(sel));

  final included = sel.where((s) => s.decision == Decision.include).toList();
  final existing = sel.where((s) => s.decision == Decision.existing).toList();
  final reasons = <String, int>{};
  for (final s in sel.where((s) => s.decision == Decision.exclude)) {
    final k = s.reason.split(':').first;
    reasons[k] = (reasons[k] ?? 0) + 1;
  }
  final words = included.fold<int>(0, (n, s) => n + s.row.tokLength);
  stdout.writeln('النسخ: ${sel.length}');
  stdout.writeln('مدرجة: ${included.length} (${(words / 1e6).toStringAsFixed(1)} مليون كلمة)');
  stdout.writeln('موجودة في السجل: ${existing.length} (${existing.map((s) => s.existingId).join('، ')})');
  for (final k in reasons.keys.toList()..sort()) {
    stdout.writeln('مستبعدة [$k]: ${reasons[k]}');
  }
  final n = int.tryParse(opt('--sample') ?? '');
  if (n != null) {
    final rnd = Random(int.parse(opt('--seed') ?? '2028'));
    final pool = [...included]..shuffle(rnd);
    stdout.writeln('\nعيّنة $n عنواناً للمراجعة:');
    for (final s in pool.take(n)) {
      stdout.writeln('- ${s.row.titleAr} — ${s.row.authorAr} (ت ${s.row.deathHijri}هـ) [${s.reason}]');
    }
  }
}
