// الاستخدام (من library/tools):
//   dart run bin/publish.dart <batch-out> <selection.tsv> <target> --date YYYY-MM-DD [--library ../]
// يجهّز المستودع العام (D31) في <target>: الكتب «المقبولة» فقط من تقرير الدفعة (<batch-out>/report.json)
// بملفاتها وفهارسها الجانبية، والكتب الخمسة من <library>/books بأحدث إصدار معاد ترميزه بالصيغة 2
// (JSON نفسه بعد فك الضغط، D33)، و registry.tsv، وفهرس schema 2. لا يدفع شيئاً (git يدوي).
import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

void main(List<String> args) {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final pos = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    pos.add(args[i]);
  }
  final date = opt('--date');
  if (pos.length != 3 || date == null) {
    stderr.writeln('الاستخدام: dart run bin/publish.dart <batch-out> <selection.tsv> <target> --date YYYY-MM-DD [--library ../]');
    exit(64);
  }
  final batch = Directory(pos[0]);
  final target = Directory(pos[2])..createSync(recursive: true);
  final library = Directory(opt('--library') ?? '../');
  final registry = Registry.load(File('${library.path}/registry.tsv'));
  final selection = parseSelectionTsv(File(pos[1]).readAsStringSync());
  final tagsById = <String, List<String>>{};
  for (final s in selection) {
    final id = registry.idOf(s.bookUri);
    if (id != null) tagsById[id] = s.tags;
  }

  final report = jsonDecode(File('${batch.path}/report.json').readAsStringSync()) as Map<String, Object?>;
  var copied = 0;
  for (final b in (report['books']! as List).cast<Map<String, Object?>>()) {
    if (b['decision'] != 'accept') continue;
    final rel = b['file']! as String;
    for (final r in [rel, indexPathFor(rel)]) {
      final dst = File('${target.path}/$r')..parent.createSync(recursive: true);
      File('${batch.path}/$r').copySync(dst.path);
    }
    copied++;
  }

  // الكتب الخمسة (D33): المعرّف نفسه والإصدار نفسه، JSON نفسه بايتاً ببايت.
  var five = 0;
  for (final f in latestBookFiles(library)) {
    final raw = gzip.decode(f.readAsBytesSync());
    final book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
    final id = book['id']! as String;
    final v2 = writeBookV2(target, autoBookRelativePath(id, book['version']! as int), book);
    final back = gzip.decode(v2.gz);
    if (back.length != raw.length || utf8.decode(back) != utf8.decode(raw)) {
      stderr.writeln('$id: فك الصيغة 2 لا يعطي JSON الأصل');
      exit(1);
    }
    five++;
  }

  File('${library.path}/registry.tsv').copySync('${target.path}/registry.tsv');
  final cat = jsonDecode(buildCatalogV2(target, date: date, tagsById: tagsById)) as Map<String, Object?>;
  stdout.writeln('مقبولة: $copied، الخمسة: $five، في الفهرس: ${(cat['books']! as List).length} '
      '(catalog_version ${cat['catalog_version']})');
}
