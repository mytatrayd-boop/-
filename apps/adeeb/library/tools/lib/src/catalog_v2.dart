/// فهرس schema 2 للمكتبة الكبيرة (ARCHITECTURE §18.5): `catalog/v2/catalog.json.gz`
/// بحقول مختصرة لكل كتاب، والتصنيف من وسوم المصدر والعصر من سنة الوفاة.
/// حتمي: إن لم تتغير الكتب يبقى الملف كما هو؛ وإن تغيّرت يزيد catalog_version.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'book_builder.dart';
import 'catalog.dart';

const catalogV2Path = 'catalog/v2/catalog.json.gz';

/// التصنيفات التسعة بترتيب الأولوية (§18.5)، وأنماط الوسوم لكل منها.
/// الأسماء المعروضة في ملفات ترجمة التطبيق (6.5)؛ الفهرس يحمل المعرّف فقط.
const categoryRules = <(String, List<String>)>[
  ('ayyam', [r'@.*(الأنساب|أيام العرب)']),
  ('poetry', [r'@.*(الشعر|دواوين|الدواوين)', r'^GAL@poetry$', r'^_SHICR']),
  ('lexicon', [r'@.*(المعاجم|الغريب|كتب اللغة|اللغوي|علوم اللغة|مكتبة المعاجم)', r'^GAL@(lexicography|philology)$', r'^KITAB@lexicographical']),
  ('grammar', [r'@.*(النحو|الصرف|نحوية|العروض|الإعراب)', r'^GAL@grammar$']),
  ('rhetoric', [r'@(.*[ ])?(البلاغة والفصاحة|النقد)', r'@نهج البلاغة']),
  ('adab', [r'@.*(الأدب|الطرائف|القصص|الأمثال|النوادر|صناعة الكتابة)', r'^GAL@(prose|adab|literature-popular)$']),
  ('history', [r'@.*(التاريخ|التواريخ|تواريخ|السيرة|سيرة|السير)', r'^GAL@(history|historiography|history-local|history-universal)$']),
  ('biography', [r'@.*(التراجم|الطبقات|الوفيات|تراجم)', r'^GAL@(biography|biography-collective|genealogy)$']),
  ('travel', [r'@.*(البلدان|الجغرافيا|الرحلات|رحلة)']),
];

final _compiled = [for (final (id, ps) in categoryRules) (id, [for (final p in ps) RegExp(p)])];

/// التصنيف بالأولوية: وسوم المكتبات العربية (`Shamela@…`، `JK@…`) أولاً، ثم GAL/KITAB إن لم يطابق
/// شيء، وإلا «الأدب» (كل كتاب مدرج دخل بوسم أدب أو لغة أو تاريخ).
String categorize(List<String> tags) {
  final arabic = tags.where((t) => RegExp('[؀-ۿ]').hasMatch(t)).toList();
  final other = tags.where((t) => !arabic.contains(t)).toList();
  for (final group in [arabic, other]) {
    for (final (id, res) in _compiled) {
      if (group.any((t) => res.any((r) => r.hasMatch(t)))) return id;
    }
  }
  return 'adab';
}

const eraIds = ['jahili', 'umayyad', 'abbasid', 'late'];

/// العصر من سنة الوفاة الهجرية (§18.5).
String eraOf(int deathHijri) => deathHijri <= 40
    ? 'jahili'
    : deathHijri <= 132
        ? 'umayyad'
        : deathHijri <= 656
            ? 'abbasid'
            : 'late';

/// أحدث إصدار لكل كتاب في المسار المقسّم `books/<xx>/<id>/<id>.v<N>.json.gz`: المعرّف ← المسار النسبي.
Map<String, String> latestShardedBooks(Directory root) {
  final dir = Directory('${root.path}/books');
  final best = <String, (int, String)>{};
  if (!dir.existsSync()) return {};
  final re = RegExp(r'^books/([a-z0-9]{2})/([a-z][a-z0-9]{1,11})/\2\.v(\d+)\.json\.gz$');
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    final rel = f.path.substring(root.path.length).replaceFirst(RegExp(r'^/+'), '');
    final m = re.firstMatch(rel);
    if (m == null) continue;
    final v = int.parse(m[3]!);
    if ((best[m[2]!]?.$1 ?? 0) < v) best[m[2]!] = (v, rel);
  }
  final ids = best.keys.toList()..sort();
  return {for (final id in ids) id: best[id]!.$2};
}

Map<String, Object?> catalogV2Entry(Map<String, Object?> book, List<int> gz, int uncompressed, String category) {
  final paras = paragraphsOf(book).toList();
  final source = book['source']! as Map<String, Object?>;
  final openiti = source['openiti'] as Map<String, Object?>?;
  final id = book['id']! as String;
  final v = book['version']! as int;
  final d = book['author_death_hijri']! as int;
  return {
    'id': id,
    't': (book['title']! as Map)['ar'],
    'a': (book['author']! as Map)['ar'],
    'd': d,
    'c': category,
    'e': eraOf(d),
    'v': v,
    'f': 'books/${id.substring(id.length - 2)}/$id/$id.v$v.json.gz',
    'sha': sha256.convert(gz).toString(),
    'sz': gz.length,
    'u': uncompressed,
    'n': paras.length,
    'dia': classifyDiacritics(paras.map((p) => p['text']! as String)),
    'src': openiti?['uri'] ?? source['url'],
  };
}

/// يبني الفهرس من الكتب الموجودة في [root] ويكتبه؛ [tagsById] وسوم المصدر لكل كتاب.
/// يعيد JSON الفهرس (قبل الضغط).
String buildCatalogV2(Directory root, {required String date, required Map<String, List<String>> tagsById}) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) throw ArgumentError('التاريخ YYYY-MM-DD: $date');
  final entries = <Map<String, Object?>>[];
  latestShardedBooks(root).forEach((id, rel) {
    final gz = File('${root.path}/$rel').readAsBytesSync();
    final raw = gzip.decode(gz);
    final book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
    final tags = tagsById[id];
    if (tags == null) throw StateError('لا وسوم للكتاب $id (ليس في قائمة الاختيار)');
    entries.add(catalogV2Entry(book, gz, raw.length, categorize(tags)));
  });
  final file = File('${root.path}/$catalogV2Path');
  var version = 1;
  if (file.existsSync()) {
    final oldText = utf8.decode(gzip.decode(file.readAsBytesSync()));
    final old = jsonDecode(oldText) as Map<String, Object?>;
    if (jsonEncode(old['books']) == jsonEncode(entries)) return oldText;
    version = (old['catalog_version']! as int) + 1;
  }
  final text = '${jsonEncode({
        'schema': 2,
        'catalog_version': version,
        'updated': date,
        'license': 'CC BY-NC-SA 4.0',
        'categories': [for (final (id, _) in categoryRules) id],
        'eras': eraIds,
        'books': entries,
      })}\n';
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(gzipDeterministic(utf8.encode(text)));
  return text;
}
