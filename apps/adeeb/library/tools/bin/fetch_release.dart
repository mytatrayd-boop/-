// الاستخدام (من library/tools):
//   dart run bin/fetch_release.dart <selection.tsv> <sources-dir> [--scope scope.yaml] [--limit 100 [--spread]]
// يجلب نصوص الكتب المدرجة (include) من raw.githubusercontent.com بـ commit إصدار OpenITI المثبّت
// في scope.yaml إلى <sources-dir>/<version_uri>، بالترتيب نفسه الذي يستعمله convert --auto.
// الموجود يُتخطّى. sha256 لكل ملف يُكتب في <sources-dir>/SHA256SUMS ويثبّته الكتاب المحوَّل.
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final pos = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (const ['--spread'].contains(args[i])) continue;
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    pos.add(args[i]);
  }
  if (pos.length != 2) {
    stderr.writeln('الاستخدام: dart run bin/fetch_release.dart <selection.tsv> <sources-dir> [--scope scope.yaml] [--limit N]');
    exit(64);
  }
  final scope = Scope.load(File(opt('--scope') ?? 'scope.yaml'));
  final todo = pickBatch(parseSelectionTsv(File(pos[0]).readAsStringSync()), int.tryParse(opt('--limit') ?? ''),
      spread: args.contains('--spread'));
  final dir = Directory(pos[1])..createSync(recursive: true);
  final client = http.Client();
  final failed = <String>[];
  var next = 0;
  Future<void> worker() async {
    while (next < todo.length) {
      final s = todo[next++];
      final f = File('${dir.path}/${s.versionUri}');
      if (f.existsSync()) continue;
      final url = Uri.parse(scope.rawUrl(s.localPath));
      for (var attempt = 1;; attempt++) {
        try {
          final res = await client.get(url);
          if (res.statusCode == 200) {
            f.writeAsBytesSync(res.bodyBytes);
            break;
          }
          if (attempt >= 3 || (res.statusCode != 429 && res.statusCode < 500)) {
            failed.add('${s.versionUri}: HTTP ${res.statusCode}');
            break;
          }
        } on Exception catch (e) {
          if (attempt >= 3) {
            failed.add('${s.versionUri}: $e');
            break;
          }
        }
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  await Future.wait([for (var i = 0; i < 8; i++) worker()]);
  client.close();
  final sums = StringBuffer();
  for (final s in todo) {
    final f = File('${dir.path}/${s.versionUri}');
    if (f.existsSync()) sums.writeln('${sha256.convert(f.readAsBytesSync())}  ${s.versionUri}');
  }
  File('${dir.path}/SHA256SUMS').writeAsStringSync(sums.toString());
  stdout.writeln('جُلب ${todo.length - failed.length} من ${todo.length}');
  for (final x in failed) {
    stderr.writeln('تعذّر: $x');
  }
}
