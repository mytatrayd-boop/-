/// مدقق المكتبة الكبيرة (المستودع العام، ARCHITECTURE §18.4–18.5): فهرس schema 2، وكل ملف كتاب
/// بالصيغة 2 في المسار المقسّم، وإزاحات أعضاء gzip (يُفك كل عضو منفرداً).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'book_v2.dart';
import 'catalog.dart';
import 'catalog_v2.dart';
import 'validator.dart';

LibraryReport validateLibraryV2(Directory root, {Map<String, ValidationExceptions> exceptions = const {}}) {
  final issues = <Issue>[];
  var books = 0, paragraphs = 0;
  void err(String where, String code, String d) => issues.add(Issue(where, code, d));
  final catFile = File('${root.path}/$catalogV2Path');
  final listed = <String>{};
  if (!catFile.existsSync()) {
    err(catalogV2Path, 'missing', 'الفهرس غير موجود');
    return LibraryReport(issues, 0, 0);
  }
  Map<String, Object?> cat;
  try {
    cat = jsonDecode(utf8.decode(gzip.decode(catFile.readAsBytesSync()))) as Map<String, Object?>;
  } on Object catch (e) {
    err(catalogV2Path, 'json', 'غير صالح: $e');
    return LibraryReport(issues, 0, 0);
  }
  if (cat['schema'] != 2) err(catalogV2Path, 'schema', 'schema يجب أن يكون 2');
  if (cat['catalog_version'] is! int) err(catalogV2Path, 'missing_field', 'catalog_version مطلوب');
  final cats = {for (final (id, _) in categoryRules) id};
  for (final e in (cat['books'] as List? ?? const []).cast<Map<String, Object?>>()) {
    final id = e['id'];
    if (id is! String || !autoBookIdPattern.hasMatch(id)) {
      err(catalogV2Path, 'book_id', 'معرّف غير صالح: $id');
      continue;
    }
    final w = '$catalogV2Path[$id]';
    if (!listed.add(id)) err(w, 'duplicate_id', 'كتاب مكرر');
    for (final k in ['t', 'a', 'src', 'sha']) {
      if (e[k] is! String || (e[k]! as String).isEmpty) err(w, 'missing_field', '$k مطلوب');
    }
    for (final k in ['d', 'v', 'sz', 'u', 'n']) {
      if (e[k] is! int) err(w, 'missing_field', '$k عدد صحيح مطلوب');
    }
    if (!cats.contains(e['c'])) err(w, 'category', 'تصنيف غير معروف: ${e['c']}');
    if (e['d'] is int && e['e'] != eraOf(e['d']! as int)) err(w, 'era', 'العصر لا يطابق سنة الوفاة');
    if (!const ['full', 'partial', 'none'].contains(e['dia'])) err(w, 'missing_field', 'dia: full|partial|none');
    final v = e['v'];
    final rel = 'books/${id.substring(id.length - 2)}/$id/$id.v$v.json.gz';
    if (e['f'] != rel) {
      err(w, 'file', 'f يجب أن يكون $rel');
      continue;
    }
    final f = File('${root.path}/$rel');
    final ix = File('${root.path}/${indexPathFor(rel)}');
    if (!f.existsSync() || !ix.existsSync()) {
      err(w, 'file', 'الملف أو فهرسه الجانبي غير موجود: $rel');
      continue;
    }
    final gz = f.readAsBytesSync();
    if (sha256.convert(gz).toString() != e['sha']) err(w, 'sha256', 'sha لا يطابق الملف');
    if (gz.length != e['sz']) err(w, 'size', 'sz لا يطابق');
    List<int> raw;
    try {
      raw = gzip.decode(gz);
    } on Object catch (ex) {
      err(rel, 'gzip', 'تعذّر فك الملف: $ex');
      continue;
    }
    if (raw.length != e['u']) err(w, 'size', 'u لا يطابق');
    final bi = validateBookBytes(raw, rel,
        expectedId: id, expectedVersion: v is int ? v : null, exceptions: exceptions[id] ?? const {}, autoIds: true);
    issues.addAll(bi);
    books++;
    Map<String, Object?> book;
    try {
      book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
    } on Object {
      continue; // سُجّل أعلاه.
    }
    final n = paragraphsOf(book).length;
    paragraphs += n;
    if (n != e['n']) err(w, 'paragraph_count', 'n لا يطابق ($n)');
    try {
      final index = jsonDecode(ix.readAsStringSync()) as Map<String, Object?>;
      for (final x in checkBookV2Index(gz, index, book)) {
        err(indexPathFor(rel), 'offsets', x);
      }
    } on Object catch (ex) {
      err(indexPathFor(rel), 'offsets', 'فهرس جانبي غير صالح: $ex');
    }
  }
  latestShardedBooks(root).forEach((id, rel) {
    if (!listed.contains(id)) err(rel, 'not_listed', 'الكتاب $id غير مدرج في الفهرس');
  });
  // أي ملف في books/ خارج النمط المقسّم.
  final booksDir = Directory('${root.path}/books');
  if (booksDir.existsSync()) {
    final re = RegExp(r'^books/([a-z0-9]{2})/([a-z][a-z0-9]{1,11})/\2\.v\d+\.(json\.gz|idx\.json)$');
    for (final f in booksDir.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(root.path.length).replaceFirst(RegExp(r'^/+'), '');
      final m = re.firstMatch(rel);
      if (m == null || m[1] != m[2]!.substring(m[2]!.length - 2)) {
        err(rel, 'file_name', 'مسار غير متوقع (books/<آخر حرفين>/<id>/<id>.v<N>.json.gz)');
      }
    }
  }
  return LibraryReport(issues, books, paragraphs);
}
