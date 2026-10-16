/// التحويل الآلي (`convert --auto`، D31، ARCHITECTURE §18.3): الوصفة الافتراضية، وكشف البنية،
/// وبوابات الجودة (قبول/مراجعة/رفض)، و`redirects` الآلية بين الإصدارات.
///
/// حتمي: لا ساعة ولا عشوائية؛ التاريخ ومعرّف الكتاب مدخلان.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'arabic_normalizer.dart';
import 'book_builder.dart';
import 'openiti.dart';
import 'presentation_forms.dart';
import 'scope.dart';
import 'validator.dart';
import 'wikitext.dart' show RemovalStats, WikitextException;

/// الوصفة الافتراضية: القواعد التي تكررت في وصفات الكتب الخمسة (ARCHITECTURE §18.3).
/// الوصفات اليدوية في `recipes/` تبقى وتتقدّم عليها.
const Map<String, Object?> defaultAutoRules = {
  'merge_page_breaks': true,
  'preface_title': 'صدر الكتاب',
  'drop_lines': [
    {'name': 'فاصل *** بين الأخبار (زخرفة طباعية)', 'pattern': r'#\s*\*+\s*'},
    {'name': 'سطر «...» وحده (علامة بلا نص)', 'pattern': r'#\s*\.\.\.\s*'},
  ],
  'drop_headings': [
    {'name': 'عنوان كله بين معقوفين [..] (أضافه المحقق، D25)', 'pattern': r'\[[^\[\]]*\]\s*\.?'},
  ],
  'heading_rules': [
    {'name': 'معقوفا تكميل المحقق داخل عنوان (يبقى النص)', 'pattern': r'[\[\]]'},
    {'name': 'رمز «(ر)» للترضية في العنوان (من الناشر)', 'pattern': r'\s*\(ر\)'},
  ],
  'brackets': {
    'name': 'معقوف المحقق',
    'default': 'keep',
    'keep': <Object?>[],
    'drop': [
      {'name': 'تعليق «ش» (المحقق)', 'pattern': r'\s*ش\s*:|[\s\S]*(قاله ش|(?<![ء-ي])ش)\s*$'},
      {'name': 'إحالة آية', 'pattern': r'[^\[\]:0-9]+: ?[0-9٠-٩]+$'},
    ],
    'max_chars': 3000,
  },
  'rules': [
    {'name': 'وسم HTML (بقايا تحويل الشاملة)', 'pattern': r'</?[a-zA-Z][^>]*>'},
    {
      'name': 'إحالة المحقق إلى السورة والآية «[المائدة: 24]»',
      'pattern': r' ?\[[^\[\]:0-9]+: ?(ms[0-9]+ )?[0-9٠-٩]+( ?[-،,] ?[0-9٠-٩]+)*\]',
      'with': r' $1',
    },
    {
      'name': 'إحالة آية مقسومة على سطرين: «[الشعراء: من» آخر السطر',
      'pattern': r'^((?:# |~~).*?) ?\[[^\[\]0-9:]{1,20}:[^\[\]0-9]{0,8}$',
      'with': r'$1',
    },
    {
      'name': 'إحالة آية مقسومة على سطرين: «الآية227]» أول السطر الملحق',
      'pattern': r'^~~([^\[\]\s0-9]*:? ?)?[0-9٠-٩]+\] ?',
      'with': '~~',
    },
    {'name': 'قوس بداية الآية «{» (اصطلاح الشاملة) ← «(»', 'pattern': r'\{', 'with': '('},
    {'name': 'قوس نهاية الآية «}» (اصطلاح الشاملة) ← «)»', 'pattern': r'\}', 'with': ')'},
    {'name': 'رقم حاشية «N» (الحواشي نفسها حذفها OpenITI)', 'pattern': r' ?«[0-9٠-٩]+»'},
    {'name': 'رقم حاشية (N) برقم واحد (الحواشي نفسها حذفها OpenITI)', 'pattern': r' ?\([0-9٠-٩]\)'},
    {
      'name': 'اسم البحر [طويل] (أضافه المحقق)',
      'pattern': r'\[(من )?(مجزوء |مشطور |منهوك |مخلع )?(ال)?(طويل|بسيط|وافر|وفر|كامل|لكامل|متقارب|رجز|منسرح|منسرج|سريع|خفيف|رمل|هزج|مديد|مضارع|مقتضب|مجتث|متدارك|خبب)[^\[\]]*\] ?',
    },
    {'name': 'فاصل الشطرين * ← «...»', 'pattern': r'\s*\*\s*', 'with': ' ... '},
    {
      'name': 'رقم حاشية ملتصق بآخر الكلمة',
      'pattern': r'([ء-يً-ْ])[0-9٠-٩]{1,2}(?=[\s.,،؛:!؟]|$)',
      'with': r'$1',
    },
  ],
};

class AutoMeta {
  AutoMeta({
    required this.bookUri,
    required this.versionUri,
    required this.titleAr,
    required this.titleEn,
    required this.authorAr,
    required this.authorEn,
    required this.deathHijri,
    required this.localPath,
  });
  final String bookUri;
  final String versionUri;
  final String titleAr;
  final String titleEn;
  final String authorAr;
  final String authorEn;
  final int deathHijri;
  final String localPath;

  static AutoMeta fromSelected(SelectedBook b) => AutoMeta(
        bookUri: b.bookUri,
        versionUri: b.versionUri,
        titleAr: b.titleAr,
        titleEn: b.titleLat.isEmpty ? b.bookUri : b.titleLat,
        authorAr: b.authorAr,
        authorEn: b.authorLat.isEmpty ? b.bookUri.split('.').first : b.authorLat,
        deathHijri: b.deathHijri,
        localPath: b.localPath,
      );
}

/// وصفة آلية (وضع متسامح) لنسخة من إصدار OpenITI.
OpenitiRecipe autoRecipe(AutoMeta m, Scope scope, String id, int version, String sha, String retrieved) =>
    OpenitiRecipe.fromJson({
      'format': 'openiti',
      'id': id,
      'version': version,
      'title': {'ar': m.titleAr, 'en': m.titleEn},
      'author': {'ar': m.authorAr, 'en': m.authorEn},
      'author_death_hijri': m.deathHijri,
      'source_name': 'OpenITI',
      'openiti': {
        'repo': scope.releaseRepo,
        'commit': scope.releaseCommit,
        'path': m.localPath,
        'uri': m.versionUri,
        'sha256': sha,
      },
      'retrieved': retrieved,
      'license': 'CC BY-NC-SA 4.0',
      'removed': '-',
      ...defaultAutoRules,
    }, lenient: true);

// ---------------------------------------------------------------------------
// كشف البنية

final _markerRe = RegExp(r'PageV\d+P\d+|(?<![A-Za-z])ms\d+(?![A-Za-z0-9])');
final _vol = RegExp(r'^V(\d+)P');

int _wordsOf(String s) => s.replaceAll(_markerRe, ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// يعيد دالة إعادة ترتيب لـ [buildOpenitiBook]: إن قلّت العناوين عن
/// [GateLimits.headingsPer100kWords] لكل 100 ألف كلمة تُحذف وتُولَّد أبواب بحدود المجلدات
/// («الجزء ٢») ثم كل نحو [GateLimits.generatedSectionParagraphs] فقرة («القسم ٣»).
/// [generated] يُضبط على true إن وُلّدت البنية.
List<OpenitiItem> Function(List<OpenitiItem>, RemovalStats) structureDetector(
  GateLimits g,
  void Function() onGenerated,
) =>
    (items, stats) {
      final paras = items.whereType<OpenitiParagraph>().toList();
      final headings = items.whereType<OpenitiHeadingItem>().length;
      final words = paras.fold<int>(0, (n, p) => n + _wordsOf(p.raw));
      if (headings > 0 && words > 0 && headings * 100000 / words >= g.headingsPer100kWords) return items;
      onGenerated();
      stats.add('بنية مولّدة: عنوان المصدر أُسقط (عناوين أقل من الحد)', headings);
      // المجلد لكل فقرة؛ ما بلا علامة صفحة يتبع ما قبله.
      final vols = <int>[];
      var last = 1;
      for (final p in paras) {
        final m = p.page == null ? null : _vol.firstMatch(p.page!);
        if (m != null) last = int.parse(m[1]!);
        vols.add(last);
      }
      final multi = vols.toSet().length > 1;
      final perVol = <int, int>{};
      for (final v in vols) {
        perVol[v] = (perVol[v] ?? 0) + 1;
      }
      final n = g.generatedSectionParagraphs;
      final out = <OpenitiItem>[];
      int? curVol;
      var inSeg = 0, section = 0;
      for (var i = 0; i < paras.length; i++) {
        final p = paras[i];
        if (multi && vols[i] != curVol) {
          curVol = vols[i];
          inSeg = 0;
          section = 0;
          out.add(OpenitiHeadingItem('الجزء ${toArabicIndicDigits(curVol)}', 1, p.line));
          stats.add('بنية مولّدة: باب «الجزء»');
        }
        final segSize = multi ? perVol[vols[i]]! : paras.length;
        // الكتاب ذو المجلد الواحد يبدأ دائماً بـ«القسم ١»؛ وفي المجلدات أقسام إن طال المجلد.
        if (inSeg % n == 0 && (!multi || segSize > n)) {
          section++;
          out.add(OpenitiHeadingItem('القسم ${toArabicIndicDigits(section)}', multi ? 2 : 1, p.line));
          stats.add('بنية مولّدة: باب «القسم»');
        }
        out.add(p);
        inSeg++;
      }
      return out;
    };

// ---------------------------------------------------------------------------
// البوابات

enum GateDecision { accept, review, reject }

class AutoOutcome {
  AutoOutcome(this.decision, this.reasons, this.metrics, {this.result, this.json, this.generated = false, this.error});
  final GateDecision decision;
  final List<String> reasons;
  final Map<String, num> metrics;
  final BuildResult? result;

  /// JSON الكتاب (schema 1) إن لم يُرفض لخطأ تحويل.
  final List<int>? json;
  final bool generated;
  final String? error;
}

final _arabicLetter = RegExp('[ء-ي]');
final _latin = RegExp('[A-Za-z]');
final _footnoteMarks = [
  RegExp(r'\(\s*[0-9٠-٩۰-۹]+\s*\)'),
  RegExp(r'[ء-يً-ْ][0-9٠-٩۰-۹]+(?=[\s.,،؛:!؟]|$)'),
  RegExp(r'\)\s*[0-9٠-٩۰-۹]+(?=\s|$)'),
  RegExp(r'«\s*[0-9٠-٩۰-۹]+\s*»'),
  RegExp(r'\[\s*[0-9٠-٩۰-۹]+\s*\]'),
];

double _r(double x) => (x * 10000).round() / 10000;

/// يقيس الكتاب المبني ويحكم عليه بحدود [g]. [sourceBody] متن المصدر (لنسبة المحذوف).
(GateDecision, List<String>, Map<String, num>) evaluateGates(
  BuildResult r,
  List<int> json,
  String sourceText,
  GateLimits g, {
  required bool generated,
  required String id,
  required int version,
}) {
  final paras = [for (final c in r.chapters) ...(c['paragraphs']! as List).cast<Map<String, Object?>>()];
  final texts = [for (final p in paras) p['text']! as String];
  final words = texts.fold<int>(0, (n, t) => n + t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
  final per10k = words == 0 ? 0.0 : 10000 / words;

  final unknown = r.stats.counts.entries
      .where((e) => e.key.startsWith(autoUnknownPrefix))
      .fold<int>(0, (n, e) => n + e.value);
  var footnotes = 0;
  for (final t in texts) {
    for (final re in _footnoteMarks) {
      footnotes += re.allMatches(t).length;
    }
  }
  final headerEnd = sourceText.indexOf('#META#Header#End#');
  final body = foldPresentationForms(headerEnd < 0 ? sourceText : sourceText.substring(headerEnd), RemovalStats());
  final srcLetters = _arabicLetter.allMatches(body).length;
  var outLetters = texts.fold<int>(0, (n, t) => n + _arabicLetter.allMatches(t).length);
  if (!generated) {
    for (final c in r.chapters) {
      outLetters += _arabicLetter.allMatches(c['title']! as String).length;
    }
  }
  final removed = srcLetters == 0 ? 1.0 : (1 - outLetters / srcLetters).clamp(0.0, 1.0);
  final allChars = texts.fold<int>(0, (n, t) => n + t.replaceAll(RegExp(r'\s'), '').length);
  final latin = allChars == 0 ? 0.0 : texts.fold<int>(0, (n, t) => n + _latin.allMatches(t).length) / allChars;
  final seen = <String>{};
  var dupes = 0, counted = 0;
  for (final t in texts) {
    if (t.length < g.duplicateMinChars) continue;
    counted++;
    if (!seen.add(t)) dupes++;
  }
  final dupRatio = counted == 0 ? 0.0 : dupes / counted;
  final maxPara = texts.fold<int>(0, (m, t) => t.length > m ? t.length : m);
  final joined = texts.join('\n');
  final head = joined.substring(0, (joined.length * g.editorHeadRatio).ceil().clamp(0, joined.length));
  final editor = g.editorWords.firstMatch(head);
  final issues = validateBookBytes(json, id, expectedId: id, expectedVersion: version, autoIds: true)
      .where((i) => !i.warning)
      .toList();

  final metrics = <String, num>{
    'words': words,
    'paragraphs': texts.length,
    'chapters': r.chapters.length,
    'unknown_per_10k': _r(unknown * per10k),
    'footnote_per_10k': _r(footnotes * per10k),
    'removed_ratio': _r(removed),
    'latin_ratio': _r(latin),
    'duplicate_ratio': _r(dupRatio),
    'max_paragraph_chars': maxPara,
    'validator_errors': issues.length,
  };
  final reject = <String>[], review = <String>[];
  void check(String name, num v, double rej, double rev) {
    if (v > rej) {
      reject.add('$name ${v.toStringAsFixed(4)} > $rej');
    } else if (v > rev) {
      review.add('$name ${v.toStringAsFixed(4)} > $rev');
    }
  }

  check('unknown_per_10k', metrics['unknown_per_10k']!, g.unknownReject, g.unknownReview);
  check('footnote_per_10k', metrics['footnote_per_10k']!, g.footnoteReject, g.footnoteReview);
  check('removed_ratio', metrics['removed_ratio']!, g.removedReject, g.removedReview);
  check('latin_ratio', metrics['latin_ratio']!, g.latinReject, g.latinReview);
  check('duplicate_ratio', metrics['duplicate_ratio']!, g.duplicateReject, g.duplicateReview);
  if (maxPara > g.maxParagraphChars) reject.add('max_paragraph_chars $maxPara > ${g.maxParagraphChars}');
  if (words < g.minWords) reject.add('words $words < ${g.minWords}');
  if (issues.isNotEmpty) {
    final codes = (issues.map((i) => i.code).toSet().toList()..sort()).join(',');
    reject.add('validator ${issues.length} ($codes)');
  }
  if (editor != null) review.add('editor_intro «${editor[0]}» في أول ${(g.editorHeadRatio * 100).round()}%');
  final d = reject.isNotEmpty
      ? GateDecision.reject
      : review.isNotEmpty
          ? GateDecision.review
          : GateDecision.accept;
  return (d, [...reject, ...review], metrics);
}

// ---------------------------------------------------------------------------
// التحويل

/// يحوّل نسخة واحدة آلياً ويحكم عليها. [previous] الإصدار المنشور السابق (إن وُجد) لتوليد
/// `redirects`. خطأ التحويل (ليس mARkdown، ليس UTF-8، …) رفضٌ بسببه لا استثناء.
AutoOutcome autoConvert({
  required AutoMeta meta,
  required List<int> sourceBytes,
  required Scope scope,
  required String id,
  required String retrieved,
  int version = 1,
  Map<String, Object?>? previous,
}) {
  final sha = sha256.convert(sourceBytes).toString();
  final recipe = autoRecipe(meta, scope, id, version, sha, retrieved);
  var generated = false;
  BuildResult r;
  try {
    r = buildOpenitiBook(
      recipe,
      sourceBytes,
      restructure: structureDetector(scope.gates, () => generated = true),
      wideChapterIds: previous == null || _chapterWidth(previous) == 4,
    );
  } on WikitextException catch (e) {
    return AutoOutcome(GateDecision.reject, ['convert: ${e.message}'], const {}, error: e.message);
  } on StateError catch (e) {
    return AutoOutcome(GateDecision.reject, ['convert: ${e.message}'], const {}, error: e.message);
  }
  final book = r.book;
  book['removed'] = 'تحويل آلي بالوصفة الافتراضية (ARCHITECTURE §18.3، D31) بلا مراجعة يدوية للنص. '
      'ما حُذف وعولج: ${r.stats.lines().join('؛ ')}.';
  if (generated) book['structure'] = 'generated';
  if (previous != null) {
    final red = autoRedirects(previous, book);
    book['redirects'] = {for (final k in red.keys.toList()..sort()) k: red[k]};
  }
  final json = encodeBookJson(book);
  final (d, reasons, metrics) = evaluateGates(
    r,
    json,
    utf8.decode(sourceBytes, allowMalformed: true),
    scope.gates,
    generated: generated,
    id: id,
    version: version,
  );
  return AutoOutcome(d, reasons, metrics, result: r, json: json, generated: generated);
}

int _chapterWidth(Map<String, Object?> book) {
  final first = ((book['chapters']! as List).first as Map)['id']! as String;
  return first.length - first.lastIndexOf('-b') - 2;
}

// ---------------------------------------------------------------------------
// redirects الآلية

String _paraKey(String text) => sha256.convert(utf8.encode(normalizeArabic(text))).toString();

List<(String, String, List<String>)> _chapters(Map<String, Object?> book) => [
      for (final c in (book['chapters']! as List).cast<Map<String, Object?>>())
        (
          c['id']! as String,
          c['title']! as String,
          [for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) p['id']! as String],
        ),
    ];

/// يولّد `redirects` من إصدار [old] إلى [neu] (ARCHITECTURE §18.3): كل معرّف فقرة في [old]
/// (أو مفتاح تحويل فيه) غير موجود في [neu] يُربط بفقرة نصها المطبَّع مطابق، وإلا بأقرب
/// فقرة في الباب نفسه (بالمعرّف)، وإلا بأول فقرة في أقرب باب قبله. المعرّفات الموجودة لا تُحوَّل.
Map<String, String> autoRedirects(Map<String, Object?> old, Map<String, Object?> neu) {
  final newIds = <String>{};
  final byKey = <String, String>{};
  final newChapters = _chapters(neu);
  final newText = <String, String>{};
  for (final c in (neu['chapters']! as List).cast<Map<String, Object?>>()) {
    for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) {
      newIds.add(p['id']! as String);
      newText[p['id']! as String] = p['text']! as String;
    }
  }
  for (final id in newIds) {
    byKey.putIfAbsent(_paraKey(newText[id]!), () => id);
  }
  final chapterById = {for (final c in newChapters) c.$1: c.$3};
  final chapterIds = [for (final c in newChapters) c.$1];

  String nearest(String pid) {
    final cut = pid.lastIndexOf('-p');
    final cid = pid.substring(0, cut);
    final n = int.parse(pid.substring(cut + 2));
    final ps = chapterById[cid];
    if (ps != null && ps.isNotEmpty) return ps[(n - 1).clamp(0, ps.length - 1)];
    // أقرب باب قبله في الترتيب، أو أول باب.
    String? best;
    for (final c in chapterIds) {
      if (c.compareTo(cid) <= 0 && chapterById[c]!.isNotEmpty) best = c;
    }
    best ??= chapterIds.firstWhere((c) => chapterById[c]!.isNotEmpty);
    return chapterById[best]!.first;
  }

  final out = <String, String>{};
  for (final c in (old['chapters']! as List).cast<Map<String, Object?>>()) {
    for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) {
      final id = p['id']! as String;
      if (newIds.contains(id)) continue;
      out[id] = byKey[_paraKey(p['text']! as String)] ?? nearest(id);
    }
  }
  // تحويلات الإصدار السابق تبقى، وتُوجَّه إلى وجهتها في الإصدار الجديد.
  final oldRed = ((old['redirects'] as Map?) ?? const {}).cast<String, String>();
  for (final e in oldRed.entries) {
    if (newIds.contains(e.key)) continue;
    final t = e.value;
    out[e.key] = newIds.contains(t) ? t : (out[t] ?? nearest(t));
  }
  return out;
}

/// مسار الكتاب الآلي المقسّم (ARCHITECTURE §18.4): `books/<آخر رقمين>/<id>/<id>.v<N>.json.gz`.
String autoBookRelativePath(String id, int version) =>
    'books/${id.substring(id.length - 2)}/$id/$id.v$version.json.gz';
