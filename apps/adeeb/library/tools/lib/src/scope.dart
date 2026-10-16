/// نطاق المكتبة الكبيرة والاختيار الآلي من بيانات OpenITI الوصفية (D30، ARCHITECTURE §18.2).
///
/// دالة صافية حتمية: `scope.yaml` + ملف TSV للإصدار + السجل ← قرار وسبب لكل نسخة.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'registry.dart';

/// حدود بوابات الجودة (ARCHITECTURE §18.3)، تُقرأ من `gates` في `scope.yaml`.
class GateLimits {
  GateLimits(Map<String, Object?> j)
      : unknownReject = _num(j, 'unknown_per_10k_reject'),
        unknownReview = _num(j, 'unknown_per_10k_review'),
        footnoteReject = _num(j, 'footnote_per_10k_reject'),
        footnoteReview = _num(j, 'footnote_per_10k_review'),
        removedReject = _num(j, 'removed_ratio_reject'),
        removedReview = _num(j, 'removed_ratio_review'),
        latinReject = _num(j, 'latin_ratio_reject'),
        latinReview = _num(j, 'latin_ratio_review'),
        duplicateReject = _num(j, 'duplicate_ratio_reject'),
        duplicateReview = _num(j, 'duplicate_ratio_review'),
        duplicateMinChars = _num(j, 'duplicate_min_chars').toInt(),
        maxParagraphChars = _num(j, 'max_paragraph_chars').toInt(),
        minWords = _num(j, 'min_words').toInt(),
        editorHeadRatio = _num(j, 'editor_head_ratio'),
        editorWords = RegExp((j['editor_words'] as String?) ?? (throw const FormatException('gates.editor_words مطلوب'))),
        headingsPer100kWords = _num(j, 'min_headings_per_100k_words'),
        generatedSectionParagraphs = _num(j, 'generated_section_paragraphs').toInt();

  final double unknownReject, unknownReview;
  final double footnoteReject, footnoteReview;
  final double removedReject, removedReview;
  final double latinReject, latinReview;
  final double duplicateReject, duplicateReview;
  final int duplicateMinChars;
  final int maxParagraphChars;
  final int minWords;
  final double editorHeadRatio;
  final RegExp editorWords;

  /// كشف البنية: أقل من هذا العدد من العناوين لكل 100 ألف كلمة ← أبواب مولّدة.
  final double headingsPer100kWords;

  /// عدد الفقرات التقريبي لكل «قسم» مولّد.
  final int generatedSectionParagraphs;

  static double _num(Map<String, Object?> j, String k) {
    final v = j[k];
    if (v is! num) throw FormatException('gates.$k رقم مطلوب في scope.yaml');
    return v.toDouble();
  }
}

class Scope {
  Scope({
    required this.releaseRepo,
    required this.releaseTag,
    required this.releaseCommit,
    required this.metadataPath,
    required this.metadataSha256,
    required this.status,
    required this.language,
    required this.allowUncorrectedOcr,
    required this.maxDeathHijri,
    required this.includeTags,
    required this.excludeTags,
    required this.includeBooks,
    required this.excludeBooks,
    this.excludeTitles = const {},
    required this.versionOverrides,
    required this.gates,
  });

  final String releaseRepo;
  final String releaseTag;
  final String releaseCommit;
  final String metadataPath;
  final String metadataSha256;
  final String status;
  final String language;
  final bool allowUncorrectedOcr;
  final int maxDeathHijri;
  final List<RegExp> includeTags;
  final List<RegExp> excludeTags;

  /// كتب مختلطة (إدراج + استبعاد) حُسمت بالاسم: URI الكتاب ← سبب.
  final Map<String, String> includeBooks;
  final Map<String, String> excludeBooks;

  /// أنماط عناوين خارج النطاق (حديث، رجال، أذكار/مناقب، فقه، تفسير) لا تكشفها الوسوم:
  /// اسم الفئة ← نمط على `title_ar`. `include_books` يتقدّم عليها.
  final Map<String, RegExp> excludeTitles;

  /// URI الكتاب ← URI النسخة المختارة بدل `pri` (استثناء يدوي).
  final Map<String, String> versionOverrides;
  final GateLimits gates;

  static Scope load(File f) => parse(f.readAsStringSync());

  static Scope parse(String yamlText) {
    final y = _plain(loadYaml(yamlText)) as Map<String, Object?>;
    final rel = y['release']! as Map<String, Object?>;
    final flt = y['filters']! as Map<String, Object?>;
    List<RegExp> res(String k) => [for (final p in (y[k]! as List).cast<String>()) RegExp(p)];
    Map<String, String> books(String k) => {
          for (final e in ((y[k] as Map?) ?? const {}).entries) e.key as String: e.value as String,
        };
    final commit = rel['commit']! as String;
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) throw FormatException('release.commit غير صالح: $commit');
    final s = Scope(
      releaseRepo: rel['repo']! as String,
      releaseTag: rel['tag']! as String,
      releaseCommit: commit,
      metadataPath: rel['metadata']! as String,
      metadataSha256: rel['metadata_sha256']! as String,
      status: flt['status']! as String,
      language: flt['language']! as String,
      allowUncorrectedOcr: flt['uncorrected_ocr']! as bool,
      maxDeathHijri: flt['max_death_hijri']! as int,
      includeTags: res('include_tags'),
      excludeTags: res('exclude_tags'),
      includeBooks: books('include_books'),
      excludeBooks: books('exclude_books'),
      excludeTitles: {for (final e in books('exclude_titles').entries) e.key: RegExp(e.value)},
      versionOverrides: books('version_overrides'),
      gates: GateLimits(y['gates']! as Map<String, Object?>),
    );
    final both = s.includeBooks.keys.toSet().intersection(s.excludeBooks.keys.toSet());
    if (both.isNotEmpty) throw FormatException('كتب في include_books وexclude_books معاً: ${both.join(', ')}');
    return s;
  }

  String rawUrl(String localPath) =>
      'https://raw.githubusercontent.com/$releaseRepo/$releaseCommit/${localPath.split('/').map(Uri.encodeComponent).join('/')}';
}

Object? _plain(Object? v) => switch (v) {
      YamlMap m => <String, Object?>{for (final e in m.entries) e.key.toString(): _plain(e.value)},
      YamlList l => [for (final x in l) _plain(x)],
      _ => v,
    };

/// صف من ملف البيانات الوصفية (الأعمدة المستعملة فقط، ARCHITECTURE §18.2).
class MetadataRow {
  MetadataRow(this.f);
  final Map<String, String> f;

  String get versionUri => f['version_uri']!;
  String get bookUri => f['book']!.isNotEmpty ? f['book']! : bookUriOf(versionUri);
  String get status => f['status']!;
  String get language => f['language']!;
  bool get uncorrectedOcr => f['uncorrected_OCR']!.toLowerCase() == 'true';
  int? get deathHijri => int.tryParse(f['date']!.trim());
  String get titleAr => _first(f['title_ar']!);
  String get titleLat => _first(f['title_lat']!);
  String get authorAr => _first(f['author_ar']!);
  String get authorLat => _first(f['author_lat']!);
  int get tokLength => int.tryParse(f['tok_length']!) ?? 0;
  String get localPath => f['local_path']!;
  List<String> get tags => [
        for (final t in f['tags']!.split('::'))
          if (t.trim().isNotEmpty) t.trim(),
      ];

  static String _first(String s) => s.split('::').first.trim();
}

/// URI الكتاب من URI النسخة: `0255Jahiz.BayanWaTabyin.Shamela0010614-ara1` ← `0255Jahiz.BayanWaTabyin`.
String bookUriOf(String versionUri) => versionUri.split('.').take(2).join('.');

const _requiredColumns = [
  'version_uri', 'language', 'uncorrected_OCR', 'date', 'author_ar', 'author_lat', 'book', 'title_ar',
  'title_lat', 'status', 'tok_length', 'local_path', 'tags',
];

/// يقرأ TSV البيانات الوصفية (سطر أول = أسماء الأعمدة، بلا اقتباس).
List<MetadataRow> parseMetadataTsv(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final header = lines.first.split('\t');
  final missing = _requiredColumns.where((c) => !header.contains(c)).toList();
  if (missing.isNotEmpty) throw FormatException('أعمدة ناقصة في TSV: ${missing.join(', ')}');
  final rows = <MetadataRow>[];
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].isEmpty) continue;
    final cells = lines[i].split('\t');
    if (cells.length > header.length) throw FormatException('سطر ${i + 1}: أعمدة أكثر من الترويسة');
    rows.add(MetadataRow({for (var k = 0; k < header.length; k++) header[k]: k < cells.length ? cells[k] : ''}));
  }
  return rows;
}

enum Decision { include, existing, exclude }

class Selection {
  Selection(this.row, this.decision, this.reason, {this.existingId});
  final MetadataRow row;
  final Decision decision;
  final String reason;
  final String? existingId;
}

/// يصنّف كل نسخة في [rows]. النتيجة مرتبة بـ URI النسخة (حتمية).
List<Selection> selectBooks(Scope scope, List<MetadataRow> rows, Registry registry) {
  final out = <Selection>[];
  final sorted = [...rows]..sort((a, b) => a.versionUri.compareTo(b.versionUri));
  for (final r in sorted) {
    out.add(_classify(scope, r, registry));
  }
  return out;
}

Selection _classify(Scope scope, MetadataRow r, Registry registry) {
  Selection no(String why) => Selection(r, Decision.exclude, why);
  final book = r.bookUri;
  final override = scope.versionOverrides[book];
  if (override != null) {
    if (override != r.versionUri) return no('version: نسخة أخرى مختارة بالاسم ($override)');
  } else if (r.status != scope.status) {
    return no('status: ${r.status}');
  }
  if (r.language != scope.language) return no('language: ${r.language}');
  if (r.uncorrectedOcr && !scope.allowUncorrectedOcr) return no('ocr: OCR غير مصحح');
  final d = r.deathHijri;
  if (d == null) return no('date: سنة الوفاة غير معروفة (${r.f['date']})');
  if (d > scope.maxDeathHijri) return no('date: $d > ${scope.maxDeathHijri}');

  final existing = registry.idOf(book);
  // «موجودة» للكتب ذات الوصفات اليدوية فقط (D33)؛ الكتاب الآلي المسجّل يبقى مدرجاً فيُعاد تحويله
  // بمعرّفه نفسه في الدفعات اللاحقة.
  if (existing != null && !RegExp(r'^o\d{5}$').hasMatch(existing)) return Selection(r, Decision.existing, 'existing: في registry.tsv بالمعرّف $existing', existingId: existing);

  if (scope.excludeBooks.containsKey(book)) return no('name: ${scope.excludeBooks[book]}');
  if (scope.includeBooks.containsKey(book)) {
    return Selection(r, Decision.include, 'name: ${scope.includeBooks[book]}');
  }
  final inc = <String>[];
  final exc = <String>[];
  for (final t in r.tags) {
    // الوسم الواحد يُحسم بالإدراج أولاً («الغريب والمعاجم ولغة الفقه» وسم لغة لا فقه).
    if (scope.includeTags.any((p) => p.hasMatch(t))) {
      inc.add(t);
    } else if (scope.excludeTags.any((p) => p.hasMatch(t))) {
      exc.add(t);
    }
  }
  if (inc.isEmpty) return no('scope: لا وسم إدراج');
  if (exc.isNotEmpty) return no('mixed: ${inc.first} + ${exc.first}');
  for (final e in scope.excludeTitles.entries) {
    if (e.value.hasMatch(r.titleAr)) return no('title: ${e.key}');
  }
  return Selection(r, Decision.include, 'tags: ${inc.first}');
}

/// ملف الاختيار TSV (مدخل `convert --auto`): الأعمدة بالترتيب أدناه.
const selectionColumns = [
  'decision', 'reason', 'version_uri', 'book_uri', 'existing_id', 'date', 'tok_length', 'title_ar', 'author_ar',
  'title_lat', 'author_lat', 'local_path', 'tags',
];

String _cell(String s) => s.replaceAll(RegExp(r'[\t\n\r]'), ' ');

String selectionToTsv(List<Selection> sel) {
  final b = StringBuffer()..writeln(selectionColumns.join('\t'));
  for (final s in sel) {
    final r = s.row;
    b.writeln([
      s.decision.name, s.reason, r.versionUri, r.bookUri, s.existingId ?? '', '${r.deathHijri ?? ''}',
      '${r.tokLength}', r.titleAr, r.authorAr, r.titleLat, r.authorLat, r.localPath, r.tags.join('::'),
    ].map(_cell).join('\t'));
  }
  return b.toString();
}

/// صف من ملف الاختيار.
class SelectedBook {
  SelectedBook(this.f);
  final Map<String, String> f;
  String get decision => f['decision']!;
  String get versionUri => f['version_uri']!;
  String get bookUri => f['book_uri']!;
  int get deathHijri => int.parse(f['date']!);
  String get titleAr => f['title_ar']!;
  String get authorAr => f['author_ar']!;
  String get titleLat => f['title_lat']!;
  String get authorLat => f['author_lat']!;
  String get localPath => f['local_path']!;

  /// وسوم المصدر (للتصنيف في الفهرس)؛ فارغة في ملف اختيار قديم بلا العمود.
  List<String> get tags => [
        for (final t in (f['tags'] ?? '').split('::'))
          if (t.trim().isNotEmpty) t.trim(),
      ];
}

List<SelectedBook> parseSelectionTsv(String text) {
  final lines = text.split('\n').where((l) => l.isNotEmpty).toList();
  final header = lines.first.split('\t');
  return [
    for (final l in lines.skip(1))
      SelectedBook({for (final (i, c) in l.split('\t').indexed) header[i]: c}),
  ];
}

/// دفعة من الكتب المدرجة (`include`) بترتيب قائمة الاختيار: أول [limit] كتاباً، أو مع [spread]
/// [limit] كتاباً موزّعة بالتساوي على القائمة كلها (عيّنة ممثِّلة للعصور، حتمية).
List<SelectedBook> pickBatch(List<SelectedBook> selection, int? limit, {bool spread = false}) {
  final inc = selection.where((s) => s.decision == Decision.include.name).toList();
  if (limit == null || limit >= inc.length) return inc;
  if (!spread) return inc.take(limit).toList();
  return [for (var i = 0; i < limit; i++) inc[i * inc.length ~/ limit]];
}
