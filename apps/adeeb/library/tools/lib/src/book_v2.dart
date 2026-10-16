/// صيغة ملف الكتاب 2 (ARCHITECTURE §18.4، §19): JSON الكتاب نفسه (schema 1) مضغوطاً أعضاءَ gzip
/// متتالية: عضو للرأس (حتى `"chapters":[`)، وعضو لكل باب، وعضو للذيل (`]` وما بعده). فك الملف
/// كاملاً يعطي JSON نفسه بايتاً ببايت، وفك عضو باب وحده (طلب Range) يعطي كائن الباب (بفاصلة
/// بعده إلا الأخير). الإزاحات في ملف جانبي `<id>.v<N>.idx.json` بجوار الكتاب.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'book_builder.dart';

class BookV2 {
  BookV2(this.gz, this.index, this.uncompressed);

  /// الملف المضغوط (أعضاء متتالية).
  final List<int> gz;

  /// الفهرس الجانبي (يُكتب بـ [indexBytes]).
  final Map<String, Object?> index;

  /// طول JSON بعد فك الضغط.
  final int uncompressed;

  List<int> get indexBytes => utf8.encode('${jsonEncode(index)}\n');
}

/// مسار الفهرس الجانبي لملف كتاب: `….json.gz` ← `….idx.json`.
String indexPathFor(String bookPath) => bookPath.replaceFirst(RegExp(r'\.json\.gz$'), '.idx.json');

/// يرمّز [book] بالصيغة 2. حتمي.
BookV2 encodeBookV2(Map<String, Object?> book) {
  final full = utf8.decode(encodeBookJson(book));
  final chapters = (book['chapters']! as List).cast<Map<String, Object?>>();
  if (chapters.isEmpty) throw StateError('كتاب بلا أبواب');
  final parts = [for (final c in chapters) jsonEncode(c)];
  final key = '"chapters":[${parts.join(',')}]';
  final at = full.indexOf(key);
  if (at < 0 || full.indexOf(key, at + 1) >= 0) throw StateError('تعذّر تحديد موضع الأبواب في JSON');
  final headEnd = at + '"chapters":['.length;
  final pieces = <String>[
    full.substring(0, headEnd),
    for (var i = 0; i < parts.length; i++) i < parts.length - 1 ? '${parts[i]},' : parts[i],
    full.substring(headEnd + key.length - '"chapters":['.length - 1),
  ];
  final out = <int>[];
  final spans = <List<int>>[];
  var raw = 0;
  for (final p in pieces) {
    final bytes = utf8.encode(p);
    raw += bytes.length;
    final m = gzipDeterministic(bytes);
    spans.add([out.length, m.length]);
    out.addAll(m);
  }
  final index = <String, Object?>{
    'format': 2,
    'id': book['id'],
    'version': book['version'],
    'header': spans.first,
    'chapters': [
      for (var i = 0; i < chapters.length; i++)
        {
          'id': chapters[i]['id'],
          'o': spans[i + 1][0],
          'l': spans[i + 1][1],
          'sha': sha256.convert(utf8.encode(parts[i])).toString(),
        },
    ],
    'trailer': spans.last,
  };
  return BookV2(out, index, raw);
}

/// يفك عضو باب واحد (كما يفعل التطبيق بعد طلب Range) ويعيد كائن الباب.
Map<String, Object?> decodeChapterMember(List<int> member) {
  var s = utf8.decode(gzip.decode(member));
  if (s.endsWith(',')) s = s.substring(0, s.length - 1);
  return jsonDecode(s) as Map<String, Object?>;
}

/// يتحقق من الفهرس الجانبي مقابل الملف: الأعضاء متتالية تغطي الملف كله، وكل عضو يُفك وحده،
/// وكل باب يطابق معرّفه وsha256. يعيد أوصاف الأخطاء (فارغة إن صحّ).
List<String> checkBookV2Index(List<int> gz, Map<String, Object?> index, Map<String, Object?> book) {
  final errs = <String>[];
  if (index['format'] != 2) errs.add('format يجب أن يكون 2');
  if (index['id'] != book['id'] || index['version'] != book['version']) errs.add('id/version لا يطابقان الكتاب');
  final chapters = (book['chapters']! as List).cast<Map<String, Object?>>();
  final entries = (index['chapters'] as List?)?.cast<Map<String, Object?>>() ?? const [];
  if (entries.length != chapters.length) {
    errs.add('عدد الأبواب في الفهرس ${entries.length} لا يطابق ${chapters.length}');
    return errs;
  }
  List<int>? spanOf(Object? s) => s is List && s.length == 2 && s.every((x) => x is int) ? s.cast<int>() : null;
  final spans = <List<int>?>[spanOf(index['header']), for (final e in entries) spanOf([e['o'], e['l']]), spanOf(index['trailer'])];
  var expect = 0;
  final rebuilt = <int>[];
  for (var i = 0; i < spans.length; i++) {
    final sp = spans[i];
    if (sp == null || sp[0] != expect || sp[1] <= 0 || sp[0] + sp[1] > gz.length) {
      errs.add('إزاحة غير صحيحة للعضو $i: $sp (المتوقع البدء عند $expect)');
      return errs;
    }
    expect = sp[0] + sp[1];
    final member = gz.sublist(sp[0], expect);
    List<int> raw;
    try {
      raw = gzip.decode(member);
    } on Object catch (e) {
      errs.add('العضو $i لا يُفك وحده: $e');
      return errs;
    }
    rebuilt.addAll(raw);
    if (i == 0 || i == spans.length - 1) continue;
    final e = entries[i - 1];
    var s = utf8.decode(raw);
    if (i < spans.length - 2) {
      if (!s.endsWith(',')) errs.add('عضو الباب ${e['id']} بلا فاصلة بعده');
      s = s.substring(0, s.length - 1);
    }
    if (sha256.convert(utf8.encode(s)).toString() != e['sha']) errs.add('sha لا يطابق للباب ${e['id']}');
    final c = jsonDecode(s) as Map<String, Object?>;
    if (c['id'] != e['id'] || c['id'] != chapters[i - 1]['id']) errs.add('معرّف الباب ${e['id']} لا يطابق');
  }
  if (expect != gz.length) errs.add('الأعضاء لا تغطي الملف كله ($expect من ${gz.length})');
  if (utf8.decode(rebuilt) != utf8.decode(encodeBookJson(book))) errs.add('فك الأعضاء لا يعطي JSON الكتاب نفسه');
  return errs;
}

/// يكتب الكتاب بالصيغة 2 وفهرسه الجانبي في [root] بالمسار [rel].
BookV2 writeBookV2(Directory root, String rel, Map<String, Object?> book) {
  final v2 = encodeBookV2(book);
  final f = File('${root.path}/$rel');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(v2.gz);
  File('${root.path}/${indexPathFor(rel)}').writeAsBytesSync(v2.indexBytes);
  return v2;
}
