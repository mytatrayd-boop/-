/// بناء `catalog.json` (ARCHITECTURE §4.1) من ملفات الكتب الموجودة فعلاً.
/// حتمي: إن لم تتغير قائمة الكتب يبقى الملف كما هو بايتاً ببايت؛ وإن تغيّرت
/// يزيد catalog_version ويُكتب التاريخ المعطى صراحة (لا ساعة النظام).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'book_builder.dart';

final _harakat = RegExp('[\u064B-\u0652]');
final _arabicLetter = RegExp('[ء-غف-يٱ-ۓ]');

/// full: حركة لكل حرفين على الأقل؛ partial: حركة لكل 20 حرفاً؛ وإلا none.
String classifyDiacritics(Iterable<String> texts) {
  var letters = 0, marks = 0;
  for (final t in texts) {
    letters += _arabicLetter.allMatches(t).length;
    marks += _harakat.allMatches(t).length;
  }
  if (letters == 0) return 'none';
  final r = marks / letters;
  if (r >= 0.5) return 'full';
  if (r >= 0.05) return 'partial';
  return 'none';
}

Map<String, Object?> decodeGzJson(List<int> gz) =>
    jsonDecode(utf8.decode(gzip.decode(gz))) as Map<String, Object?>;

Iterable<Map<String, Object?>> paragraphsOf(Map<String, Object?> book) sync* {
  for (final c in (book['chapters']! as List).cast<Map<String, Object?>>()) {
    yield* (c['paragraphs']! as List).cast<Map<String, Object?>>();
  }
}

/// أحدث إصدار لكل كتاب في `books/<id>/`.
List<File> latestBookFiles(Directory libraryRoot) {
  final booksDir = Directory('${libraryRoot.path}/books');
  if (!booksDir.existsSync()) return [];
  final ids = booksDir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .toList()
    ..sort();
  final out = <File>[];
  for (final id in ids) {
    final re = RegExp('^${RegExp.escape(id)}\\.v(\\d+)\\.json\\.gz\$');
    File? best;
    var bestV = -1;
    for (final f in Directory('${booksDir.path}/$id').listSync().whereType<File>()) {
      final m = re.firstMatch(f.uri.pathSegments.last);
      if (m != null && int.parse(m[1]!) > bestV) {
        bestV = int.parse(m[1]!);
        best = f;
      }
    }
    if (best != null) out.add(best);
  }
  return out;
}

Map<String, Object?> catalogEntry(Map<String, Object?> book, List<int> gz, int uncompressed) {
  final id = book['id']! as String;
  final version = book['version']! as int;
  final title = book['title']! as Map<String, Object?>;
  final author = book['author']! as Map<String, Object?>;
  final source = book['source']! as Map<String, Object?>;
  final paras = paragraphsOf(book).toList();
  return {
    'id': id,
    'title': {'ar': title['ar'], 'en': title['en']},
    'author': {'ar': author['ar'], 'en': author['en']},
    'author_death_hijri': book['author_death_hijri'],
    'version': version,
    'file': bookRelativePath(id, version),
    'sha256': sha256.convert(gz).toString(),
    'size_bytes': gz.length,
    'uncompressed_bytes': uncompressed,
    'paragraph_count': paras.length,
    'diacritics': classifyDiacritics(paras.map((p) => p['text']! as String)),
    'source': {'name': source['name'], 'url': source['url']},
    'license': book['license'],
  };
}

const _indent = JsonEncoder.withIndent('  ');

/// يبني الفهرس ويعيد النص المكتوب. [date] بصيغة YYYY-MM-DD.
String buildCatalog(Directory libraryRoot, {required String date}) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    throw ArgumentError('التاريخ يجب أن يكون YYYY-MM-DD: $date');
  }
  final entries = <Map<String, Object?>>[];
  for (final f in latestBookFiles(libraryRoot)) {
    final gz = f.readAsBytesSync();
    final raw = gzip.decode(gz);
    final book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
    entries.add(catalogEntry(book, gz, raw.length));
  }
  final file = File('${libraryRoot.path}/catalog.json');
  var version = 1;
  if (file.existsSync()) {
    final old = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    if (jsonEncode(old['books']) == jsonEncode(entries)) {
      return file.readAsStringSync();
    }
    version = (old['catalog_version']! as int) + 1;
  }
  final text = '${_indent.convert({
        'schema': 1,
        'catalog_version': version,
        'updated': date,
        'books': entries,
      })}\n';
  file.writeAsStringSync(text);
  return text;
}
