/// قارئ صيغة OpenITI mARkdown وتحويلها إلى ملف الكتاب (schema 1) — D21.
///
/// نفس مبادئ D17: دالة صافية حتمية من الوصفة ونص المصدر المثبّت (commit + sha256)؛
/// كل ما يُحذف يُعدّ في الإحصاء؛ أي سطر أو وسم غير معروف يوقف التحويل بخطأ.
///
/// الوسوم المدعومة:
/// - `######OpenITI#` السطر الأول، ثم ترويسة `#META# ...` حتى `#META#Header#End#`.
/// - `### |` عنوان، وعدد `|` = المستوى (يُقصر على 3). `### |PARATEXT|` و`### |EDITOR|`
///   قسم ليس من نص المؤلف يُحذف حتى العنوان التالي.
/// - `# ` بداية فقرة، و`~~` سطر ملحق بالفقرة السابقة.
/// - `PageV01P009` نهاية الصفحة 9 من المجلد 1 (اصطلاح OpenITI: العلامة في آخر الصفحة)،
///   داخل السطر أو وحدها في سطر. تُحفظ للفقرة في `page` = صفحة بدايتها.
/// - `ms12` علامة مَعلَم (كل 300 كلمة تقريباً) تُحذف وتُعدّ.
/// - `%~%` فاصل الشطرين: الفقرة التي فيها بيت؛ الأبيات المتتالية فقرة شعر واحدة.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'book_builder.dart';
import 'presentation_forms.dart';
import 'wikitext.dart' show RemovalStats, WikitextException, cleanText;

/// خطأ في صيغة المصدر أو في الوصفة، برقم السطر في ملف OpenITI إن وُجد.
class OpenitiException extends WikitextException {
  OpenitiException(super.message);
}

/// قاعدة نصية من الوصفة تُطبَّق على كل سطر من متن المصدر (بعد الترويسة) بالترتيب.
/// `with` غائب = حذف المطابقة (ويقبل `$1`…`$9`). كل مطابقة تُعدّ باسم القاعدة.
class OpenitiRule {
  OpenitiRule(this.name, this.pattern, this.replacement, {this.pipes, this.end});
  final String name;
  final RegExp pattern;
  final String replacement;

  /// في drop_headings: يقصر القاعدة على عناوين بهذا العدد من `|`.
  final int? pipes;

  /// في drop_spans: نمط السطر الأخير من المقطع المحذوف (يُحذف معه).
  final RegExp? end;

  static OpenitiRule fromJson(Map<String, Object?> j) => OpenitiRule(
        j['name']! as String,
        RegExp(j['pattern']! as String),
        (j['with'] as String?) ?? '',
        pipes: j['pipes'] as int?,
        end: j['end'] == null ? null : RegExp(j['end']! as String),
      );

  /// مطابقة النص كله (لا جزء منه).
  bool fullMatch(String t) => pattern.matchAsPrefix(t)?.end == t.length;

  /// نص الاستبدال لمطابقة، مع `$1`…`$9` للمجموعات.
  String expand(Match m) => replacement.replaceAllMapped(
        RegExp(r'\$(\d)'),
        (g) => m[int.parse(g[1]!)] ?? '',
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'pattern': pattern.pattern,
        if (replacement.isNotEmpty) 'with': replacement,
        if (pipes != null) 'pipes': pipes,
        if (end != null) 'end': end!.pattern,
      };
}

/// سياسة المعقوفات في وصفة OpenITI.
class OpenitiBrackets {
  OpenitiBrackets({required this.name, this.keep = const [], this.maxChars = 3000});
  final String name;

  /// محتوى معقوف يبقى نصه (بلا المعقوفين) إن طابق أوله أحد هذه الأنماط.
  final List<OpenitiRule> keep;

  /// أطول معقوف يُحذف آلياً؛ الأطول خطأ يحتاج قاعدة صريحة (حماية من معقوف ناقص).
  final int maxChars;

  static OpenitiBrackets fromJson(Map<String, Object?> j) => OpenitiBrackets(
        name: j['name']! as String,
        keep: [
          for (final r in ((j['keep'] as List?) ?? const []).cast<Map<String, Object?>>())
            OpenitiRule.fromJson(r),
        ],
        maxChars: (j['max_chars'] as int?) ?? 3000,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'keep': [for (final r in keep) r.toJson()],
        'max_chars': maxChars,
      };
}

/// يطبّق [OpenitiBrackets] على المتن. [firstLine] فهرس أول سطر (لرسائل الخطأ).
/// المعقوف المحذوف يُستبدل بعلامات الصفحات/المعالم التي فيه، وما بعد «]» في سطره يُلحق
/// بسطر «[»، وتُضاف أسطر فارغة بعدد الأسطر المحذوفة فتبقى أرقام الأسطر التالية كما هي.
String _applyBrackets(String b, OpenitiBrackets policy, int firstLine, RemovalStats stats) {
  int lineOf(int pos) => firstLine + 1 + '\n'.allMatches(b.substring(0, pos)).length;
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final s = b.indexOf('[', i);
    if (s < 0) break;
    final lineStart = b.lastIndexOf('\n', s) + 1;
    final e = b.indexOf(']', s + 1);
    final n = b.indexOf('[', s + 1);
    if (b.startsWith('### ', lineStart)) {
      // معقوف داخل عنوان: تعالجه قواعد العناوين، بشرط أن يُغلق في السطر نفسه.
      final lineEnd = b.indexOf('\n', s) < 0 ? b.length : b.indexOf('\n', s);
      if (e < 0 || e > lineEnd) throw OpenitiException('سطر ${lineOf(s)}: معقوف في عنوان لا يُغلق في سطره.');
      out.write(b.substring(i, e + 1));
      i = e + 1;
      continue;
    }
    if (e < 0 || (n >= 0 && n < e)) {
      throw OpenitiException('سطر ${lineOf(s)}: معقوف غير متوازن أو متداخل؛ أصلحه بقاعدة صريحة في rules.');
    }
    final content = b.substring(s + 1, e);
    if (content.contains('\n### ')) throw OpenitiException('سطر ${lineOf(s)}: معقوف يمتد عبر عنوان.');
    final keep = policy.keep.where((r) => r.pattern.matchAsPrefix(content) != null).firstOrNull;
    if (keep != null) {
      stats.add('معقوف أُبقي نصه بلا المعقوفين: ${keep.name}');
      out
        ..write(b.substring(i, s))
        ..write(content);
      i = e + 1;
      continue;
    }
    if (content.length > policy.maxChars) {
      throw OpenitiException('سطر ${lineOf(s)}: معقوف أطول من ${policy.maxChars} حرفاً؛ راجعه وأضف قاعدة صريحة.');
    }
    stats.add('معقوف محذوف بمحتواه: ${policy.name}');
    final k = '\n'.allMatches(content).length;
    if (k > 0) stats.add('معقوف محذوف ممتد على أكثر من سطر');
    final markers = _markerRe.allMatches(content).map((m) => m[0]).join(' ');
    out
      ..write(b.substring(i, s))
      ..write(markers.isEmpty ? '' : ' $markers ');
    final lineEnd = b.indexOf('\n', e + 1) < 0 ? b.length : b.indexOf('\n', e + 1);
    out
      ..write(b.substring(e + 1, lineEnd))
      ..write('\n' * k);
    i = lineEnd;
  }
  out.write(b.substring(i));
  final result = out.toString();
  final stray = RegExp(r'^(?!### ).*\]', multiLine: true).firstMatch(result);
  if (stray != null) {
    final line = firstLine + 1 + '\n'.allMatches(result.substring(0, stray.start)).length;
    throw OpenitiException('سطر $line: «]» بلا «[»؛ أصلحه بقاعدة صريحة في rules.');
  }
  return result;
}

/// تعديل عنوان بعينه (بنصه بعد التنظيف): عنوان بديل و/أو مستوى، أو حذف العنوان وحده.
class OpenitiHeading {
  OpenitiHeading({this.title, this.level, this.drop = false});
  final String? title;
  final int? level;
  final bool drop;

  static OpenitiHeading fromJson(Map<String, Object?> j) => OpenitiHeading(
        title: j['title'] as String?,
        level: j['level'] as int?,
        drop: (j['drop'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        if (title != null) 'title': title,
        if (level != null) 'level': level,
        if (drop) 'drop': true,
      };
}

class OpenitiRecipe {
  OpenitiRecipe({
    required this.id,
    required this.version,
    required this.titleAr,
    required this.titleEn,
    required this.authorAr,
    required this.authorEn,
    required this.authorDeathHijri,
    required this.repo,
    required this.commit,
    required this.path,
    required this.versionUri,
    required this.license,
    required this.removed,
    this.sha256,
    this.retrieved,
    this.originalSource,
    this.edition,
    this.sourceName = 'OpenITI',
    this.mergePageBreaks = false,
    this.prefaceTitle,
    this.skipHeadings = const [],
    this.dropLines = const [],
    this.dropHeadings = const [],
    this.headingRules = const [],
    this.headingLevels = const [],
    this.dropSpans = const [],
    this.paragraphRules = const [],
    this.dropParagraphs = const [],
    this.noMergeBefore = const [],
    this.bareHeading,
    this.bareHeadingFormat,
    this.brackets,
    this.rules = const [],
    this.headings = const {},
    this.redirects = const {},
    this.validationExceptions = const {},
  });

  final String id;
  final int version;
  final String titleAr;
  final String titleEn;
  final String authorAr;
  final String authorEn;
  final int authorDeathHijri;

  /// مستودع GitHub مثل `OpenITI/0150AH`.
  final String repo;

  /// commit مثبّت (40 حرفاً ست عشرياً).
  final String commit;

  /// مسار الملف داخل المستودع.
  final String path;

  /// معرّف النسخة في OpenITI (URI) مثل `0139IbnMuqaffac.KalilaWaDimna.Shamela0026537-ara1`.
  final String versionUri;

  /// sha256 لبايتات ملف المصدر؛ يكتبه أمر الجلب في المسودة ويُتحقق منه دائماً بعدها.
  String? sha256;
  String? retrieved;

  /// المصدر الأصلي الذي نقل عنه OpenITI (مثل «المكتبة الشاملة، الكتاب 26537»).
  final String? originalSource;
  final String? edition;
  final String sourceName;
  final String license;
  final String removed;

  /// وصل فقرة شقّها حدّ الصفحة: إن بدأ سطر `# ` بعد علامة صفحة مباشرة والفقرة السابقة
  /// نثر لا تنتهي بعلامة وقف، فهو تتمة لها (أثر نقل الشاملة صفحةً صفحة).
  final bool mergePageBreaks;

  /// عنوان باب لما يسبق أول عنوان في المصدر (إن وُجد نص قبله)؛ غيابه مع وجود النص خطأ.
  final String? prefaceTitle;

  /// عناوين تُحذف مع ما تحتها (ومع أبوابها الفرعية الأعمق).
  final List<String> skipHeadings;

  /// أسطر كاملة تُحذف (مثل فاصل `# ***`)؛ تطابق السطر الخام كله.
  final List<OpenitiRule> dropLines;

  /// عناوين تُحذف وحدها (يبقى نصها في الباب السابق)، مثل عناوين أضافها المحقق
  /// بين معقوفين؛ تطابق نص العنوان بعد التنظيف كله.
  final List<OpenitiRule> dropHeadings;

  /// حذف/استبدال داخل نص العنوان (مثل معقوفين حول عنوان من تقسيم المؤلف).
  final List<OpenitiRule> headingRules;

  /// مستوى العنوان المطابق كله لنمط (`with` = المستوى)؛ يغلب عدد `|`.
  final List<OpenitiRule> headingLevels;

  /// مقاطع أسطر تُحذف كلها: من سطر يطابق `pattern` إلى سطر يطابق `end` (كلاهما مطابقة كاملة).
  /// لتعليقات محقق تمتد على عدة فقرات.
  final List<OpenitiRule> dropSpans;

  /// حذف/استبدال داخل نص الفقرة بعد ضم أسطرها (لما يمتد على أكثر من سطر).
  final List<OpenitiRule> paragraphRules;

  /// فقرات تُحذف كلها إن طابق نصها (بعد paragraph_rules) النمط كله.
  final List<OpenitiRule> dropParagraphs;

  /// أنماط إضافية لبداية سطر لا يُوصل بما قبله عبر حدّ الصفحة (فوق القائمة الافتراضية).
  final List<OpenitiRule> noMergeBefore;

  /// عنوان بلا اسم (مثل «باب») يُرقَّم بترتيبه بين أبواب المستوى 1: [bareHeadingFormat]
  /// مع `{n}` بأرقام عربية مشرقية (مثل «باب ١٢»)، حتى لا يُضاف كلام ليس في المصدر.
  final String? bareHeading;
  final String? bareHeadingFormat;

  /// سياسة المعقوفات [..] في المتن (D17: نص المؤلف فقط): ما طابق `keep` يبقى نصه بلا
  /// المعقوفين، وكل ما سواه يُحذف بمحتواه ولو امتد على عدة أسطر (تبقى علامات الصفحات فيه).
  final OpenitiBrackets? brackets;

  /// قواعد حذف/استبدال داخل الأسطر (مثل أرقام حواشٍ «١» بقيت بعد حذف الحواشي).
  final List<OpenitiRule> rules;

  /// تعديلات عناوين بعينها؛ المفتاح غير المستخدم خطأ (وصفة قديمة).
  final Map<String, OpenitiHeading> headings;
  final Map<String, String> redirects;
  final Map<String, List<String>> validationExceptions;

  String get sourceUrl => 'https://github.com/$repo/blob/$commit/${_encodePath(path)}';
  String get rawUrl => 'https://raw.githubusercontent.com/$repo/$commit/${_encodePath(path)}';

  bool get isPinned => sha256 != null && retrieved != null;

  static bool isOpenitiJson(Map<String, Object?> j) => j['format'] == 'openiti';

  Map<String, Object?> toJson() => {
        'format': 'openiti',
        'id': id,
        'version': version,
        'title': {'ar': titleAr, 'en': titleEn},
        'author': {'ar': authorAr, 'en': authorEn},
        'author_death_hijri': authorDeathHijri,
        'source_name': sourceName,
        'openiti': {
          'repo': repo,
          'commit': commit,
          'path': path,
          'uri': versionUri,
          'sha256': sha256,
        },
        if (originalSource != null) 'original_source': originalSource,
        if (edition != null) 'edition': edition,
        'retrieved': retrieved,
        'license': license,
        'removed': removed,
        'merge_page_breaks': mergePageBreaks,
        if (prefaceTitle != null) 'preface_title': prefaceTitle,
        'skip_headings': skipHeadings,
        'drop_lines': [for (final r in dropLines) r.toJson()],
        'drop_headings': [for (final r in dropHeadings) r.toJson()],
        'heading_rules': [for (final r in headingRules) r.toJson()],
        'heading_levels': [for (final r in headingLevels) r.toJson()],
        'drop_spans': [for (final r in dropSpans) r.toJson()],
        'paragraph_rules': [for (final r in paragraphRules) r.toJson()],
        'drop_paragraphs': [for (final r in dropParagraphs) r.toJson()],
        'no_merge_before': [for (final r in noMergeBefore) r.toJson()],
        if (bareHeading != null) 'bare_heading': {'text': bareHeading, 'format': bareHeadingFormat},
        if (brackets != null) 'brackets': brackets!.toJson(),
        'rules': [for (final r in rules) r.toJson()],
        'headings': {for (final e in headings.entries) e.key: e.value.toJson()},
        if (redirects.isNotEmpty) 'redirects': redirects,
        if (validationExceptions.isNotEmpty) 'validation_exceptions': validationExceptions,
      };

  static OpenitiRecipe fromJson(Map<String, Object?> j) {
    if (!isOpenitiJson(j)) throw OpenitiException('الوصفة ليست بصيغة openiti (format).');
    final title = (j['title']! as Map).cast<String, Object?>();
    final author = (j['author']! as Map).cast<String, Object?>();
    final o = (j['openiti']! as Map).cast<String, Object?>();
    final commit = o['commit']! as String;
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      throw OpenitiException('commit يجب أن يكون 40 حرفاً ست عشرياً: $commit');
    }
    List<OpenitiRule> rules(String k) => [
          for (final r in ((j[k] as List?) ?? const []).cast<Map<String, Object?>>()) OpenitiRule.fromJson(r),
        ];
    return OpenitiRecipe(
      id: j['id']! as String,
      version: j['version']! as int,
      titleAr: title['ar']! as String,
      titleEn: title['en']! as String,
      authorAr: author['ar']! as String,
      authorEn: author['en']! as String,
      authorDeathHijri: j['author_death_hijri']! as int,
      sourceName: (j['source_name'] as String?) ?? 'OpenITI',
      repo: o['repo']! as String,
      commit: commit,
      path: o['path']! as String,
      versionUri: o['uri']! as String,
      sha256: o['sha256'] as String?,
      originalSource: j['original_source'] as String?,
      edition: j['edition'] as String?,
      retrieved: j['retrieved'] as String?,
      license: j['license']! as String,
      removed: j['removed']! as String,
      mergePageBreaks: (j['merge_page_breaks'] as bool?) ?? false,
      prefaceTitle: j['preface_title'] as String?,
      skipHeadings: [...((j['skip_headings'] as List?) ?? const []).cast<String>()],
      dropLines: rules('drop_lines'),
      dropHeadings: rules('drop_headings'),
      headingRules: rules('heading_rules'),
      headingLevels: rules('heading_levels'),
      dropSpans: rules('drop_spans'),
      paragraphRules: rules('paragraph_rules'),
      dropParagraphs: rules('drop_paragraphs'),
      noMergeBefore: rules('no_merge_before'),
      bareHeading: (j['bare_heading'] as Map?)?['text'] as String?,
      bareHeadingFormat: (j['bare_heading'] as Map?)?['format'] as String?,
      brackets: j['brackets'] == null ? null : OpenitiBrackets.fromJson((j['brackets']! as Map).cast<String, Object?>()),
      rules: rules('rules'),
      headings: {
        for (final e in ((j['headings'] as Map?) ?? const {}).entries)
          e.key as String: OpenitiHeading.fromJson((e.value as Map).cast<String, Object?>()),
      },
      redirects: {
        ...((j['redirects'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
      },
      validationExceptions: {
        ...((j['validation_exceptions'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, [...(v as List).cast<String>()])),
      },
    );
  }

  static OpenitiRecipe load(File f) =>
      fromJson(jsonDecode(f.readAsStringSync()) as Map<String, Object?>);

  void save(File f) => f.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(toJson())}\n',
      );
}

String _encodePath(String p) => p.split('/').map(Uri.encodeComponent).join('/');

// ---------------------------------------------------------------------------
// القراءة

/// عنصر من المتن بعد القراءة: عنوان أو فقرة.
sealed class OpenitiItem {}

class OpenitiHeadingItem extends OpenitiItem {
  OpenitiHeadingItem(this.text, this.pipes, this.line);
  final String text;
  final int pipes;
  final int line;
}

class OpenitiParagraph extends OpenitiItem {
  OpenitiParagraph(this.line);

  /// رقم السطر في ملف المصدر (من 1) لرسائل الخطأ.
  final int line;
  final List<String> pieces = [];
  final List<int> lines = [];

  /// علامة الصفحة التي تنتهي بها صفحة بداية الفقرة، مثل V01P009.
  String? page;

  /// نص آخر سطر من المصدر في الفقرة (بلا علامات)، لقرار الوصل عبر حدّ الصفحة.
  String lastLine = '';

  /// الفقرة السابقة لها (بلا عنوان بينهما) بيت أو تنتهي بـ«:»، فهذه قد تكون شطراً منظوماً.
  bool afterVerseOrColon = false;
  String get raw => pieces.join(' ');
}

final _pageRe = RegExp(r'PageV(\d+)P(\d+)');
final _milestoneRe = RegExp(r'(?<![A-Za-z])ms\d+(?![A-Za-z0-9])');
final _markerRe = RegExp(r'PageV\d+P\d+|(?<![A-Za-z])ms\d+(?![A-Za-z0-9])');
final _headingRe = RegExp(r'^### (\|+)(.*)$');
final _taggedHeadingRe = RegExp(r'^([A-Z_]+)\|\s*(.*)$');

/// محارف لا تظهر في نص عربي نظيف: بقايا وسم OpenITI أو HTML أو ترميز مجهول.
final _unknownMarkup = RegExp(r'[A-Za-z#|~%@$<>*`_{}\\^=+]');

/// علامات وقف تنهي الفقرة؛ ما بعدها في صفحة جديدة لا يُوصل بها.
final _terminal = RegExp(r'[.!?؟:»"…]$');

/// فواتح خبر جديد: سطر يبدأ بها بعد حدّ الصفحة لا يُوصل بما قبله.
const defaultNoMergeOpeners = [
  'قال', 'وقال', 'فقال', 'قالت', 'وقالت', 'وقالوا', 'أنشد', 'وأنشد', 'أنشدني', 'وأنشدني', 'أنشدنا', 'وأنشدنا',
  'حدثني', 'وحدثني', 'حدثنا', 'وحدثنا', 'أخبرنا', 'وأخبرنا', 'أخبرني', 'وأخبرني', 'يريد', 'يقول', 'ويقول',
  'يروى', 'ويروى', 'وكان',
];
final _openerRe = RegExp('^\\s*(${defaultNoMergeOpeners.join('|')})(?![ء-ي])');

/// آخر سطر في الفقرة السابقة بيت: فيه فاصل الشطرين «...»، أو الفقرة سطر واحد قصير بلا ترقيم
/// (شطر منظوم). لا يُوصل ما بعده به.
bool _looksLikeVerse(OpenitiParagraph prev) {
  final last = prev.lastLine;
  if (last.contains(' ... ') || last.contains('...')) return true;
  if (prev.afterVerseOrColon &&
      prev.lines.length == 1 &&
      !RegExp(r'[.،,؛;:؟?!«»"()]').hasMatch(last) &&
      last.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 8) {
    return true;
  }
  return false;
}

bool _isVerseOrColon(OpenitiParagraph? p) {
  if (p == null) return false;
  final t = p.raw.replaceAll(_markerRe, ' ').trim();
  return t.contains('%~%') || p.lastLine.contains('...') || t.endsWith(':');
}

/// كلمات لا تنتهي بها جملة: إن ختمت الفقرة السابقة بإحداها (أو بفاصلة) فما بعد الحدّ تتمة لها
/// ولو بدأ بفاتحة خبر («مثل التاجر الذي | قال: ...»).
const _openEndings = {
  'الذي', 'التي', 'الذين', 'اللذين', 'اللتين', 'اللاتي', 'أن', 'إن', 'من', 'في', 'على', 'إلى', 'عن', 'ما',
  'لا', 'لم', 'لن', 'قد', 'ثم', 'أو', 'أم', 'بل', 'حتى', 'إذا', 'إذ', 'كي', 'لأن', 'لكن', 'مع', 'بين', 'عند',
  'و', 'ف', 'ب', 'ل', 'يا', 'هذا', 'هذه', 'ذلك', 'كان', 'فقال', 'وقال', 'قال', 'منه', 'به', 'له',
};

bool _prevContinues(OpenitiParagraph prev) {
  final t = cleanText(prev.raw.replaceAll(_markerRe, ' '));
  if (t.endsWith('،') || t.endsWith('؛') || t.endsWith(',')) return true;
  final words = t.split(' ');
  return _openEndings.contains(words.last);
}

bool _startsNewReport(String content, OpenitiRecipe recipe, OpenitiParagraph prev) {
  if (_prevContinues(prev)) return false;
  final t = content.replaceAll(_markerRe, ' ').trimLeft();
  if (_openerRe.hasMatch(t)) return true;
  return recipe.noMergeBefore.any((r) => r.pattern.matchAsPrefix(t) != null);
}

/// أقسام ليست من نص المؤلف بوسم OpenITI صريح.
const skippedSectionTags = {'PARATEXT', 'EDITOR'};

class OpenitiDocument {
  OpenitiDocument(this.meta, this.items);
  final Map<String, String> meta;
  final List<OpenitiItem> items;
}

/// يقرأ ملف OpenITI mARkdown إلى عناوين وفقرات خام (قبل تجميع الأبواب).
OpenitiDocument parseOpeniti(String source, OpenitiRecipe recipe, RemovalStats stats) {
  var s = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (s.startsWith('﻿')) s = s.substring(1);
  s = foldPresentationForms(s, stats);
  final lines = s.split('\n');
  if (lines.isEmpty || lines.first.trim() != '######OpenITI#') {
    throw OpenitiException('السطر الأول ليس ######OpenITI#: ليس ملف OpenITI mARkdown.');
  }
  final meta = <String, String>{};
  var i = 1;
  var headerEnded = false;
  for (; i < lines.length; i++) {
    final l = lines[i].trim();
    if (l.isEmpty) continue;
    if (l == '#META#Header#End#') {
      headerEnded = true;
      i++;
      break;
    }
    final m = RegExp(r'^#META#\s*(\S+)\s*::\s*(.*)$').firstMatch(l);
    if (m == null) throw OpenitiException('سطر ${i + 1}: سطر ترويسة غير معروف: «$l»');
    meta[m[1]!] = m[2]!.trim();
  }
  if (!headerEnded) throw OpenitiException('لا يوجد #META#Header#End#.');

  final items = <OpenitiItem>[];
  final pending = <OpenitiParagraph>[];
  OpenitiParagraph? current;
  var pageSinceText = false;
  var sectionSkip = false;
  final usedHeadings = <String>{};
  OpenitiRule? openSpan;

  // يضيف قطعة نص للفقرة الحالية ويعالج العلامات داخلها بترتيب ظهورها.
  void addContent(OpenitiParagraph p, String content, int lineNo) {
    var last = 0;
    var hasText = false;
    for (final m in _markerRe.allMatches(content)) {
      final before = content.substring(last, m.start);
      if (before.trim().isNotEmpty) {
        p.pieces.add(before);
        pageSinceText = false;
        hasText = true;
      }
      _marker(m[0]!, pending, stats, () => pageSinceText = true);
      last = m.end;
    }
    final rest = content.substring(last);
    if (rest.trim().isNotEmpty) {
      p.pieces.add(rest);
      pageSinceText = false;
      hasText = true;
    }
    if (hasText) {
      p.lines.add(lineNo);
      p.lastLine = content.replaceAll(_markerRe, ' ').trim();
    }
  }

  // تمريرة 1: drop_lines ثم rules لكل سطر (السطر المحذوف يصير فارغاً فتبقى أرقام الأسطر).
  for (var k = i; k < lines.length; k++) {
    var line = lines[k];
    if (line.trim().isEmpty) continue;
    final dl = recipe.dropLines.where((r) => r.fullMatch(line)).firstOrNull;
    if (dl != null) {
      stats.add('سطر محذوف: ${dl.name}');
      lines[k] = '';
      continue;
    }
    for (final r in recipe.rules) {
      final n = r.pattern.allMatches(line).length;
      if (n > 0) {
        stats.add('قاعدة: ${r.name}', n);
        line = line.replaceAllMapped(r.pattern, r.expand);
      }
    }
    lines[k] = line;
  }
  // تمريرة 2: المعقوفات (إن طلبتها الوصفة) ولو امتدت على عدة أسطر.
  if (recipe.brackets != null) {
    final body = _applyBrackets(lines.sublist(i).join('\n'), recipe.brackets!, i, stats);
    lines.replaceRange(i, lines.length, body.split('\n'));
  }

  for (; i < lines.length; i++) {
    final lineNo = i + 1;
    var line = lines[i];
    if (line.trim().isEmpty) continue;

    if (openSpan != null) {
      stats.add('سطر محذوف ضمن مقطع: ${openSpan.name}');
      for (final m in _markerRe.allMatches(line)) {
        _marker(m[0]!, pending, stats, () => pageSinceText = true);
      }
      if (openSpan.end!.matchAsPrefix(line)?.end == line.length) openSpan = null;
      continue;
    }
    final span = recipe.dropSpans.where((r) => r.fullMatch(line)).firstOrNull;
    if (span != null) {
      if (span.end == null) throw OpenitiException('drop_spans «${span.name}» بلا end.');
      stats.add('مقطع محذوف: ${span.name}');
      stats.add('سطر محذوف ضمن مقطع: ${span.name}');
      for (final m in _markerRe.allMatches(line)) {
        _marker(m[0]!, pending, stats, () => pageSinceText = true);
      }
      if (span.end!.matchAsPrefix(line)?.end != line.length) openSpan = span;
      continue;
    }

    line = line.trimRight();
    if (line.trim().isEmpty || RegExp(r'^(~~|#)\s*$').hasMatch(line)) {
      stats.add('سطر فرغ بعد القواعد');
      continue;
    }

    if (line.startsWith('### ')) {
      final h = _headingRe.firstMatch(line);
      if (h == null) throw OpenitiException('سطر $lineNo: عنوان بوسم غير مدعوم: «$line»');
      final pipes = h[1]!.length;
      var rest = h[2]!;
      final tagged = _taggedHeadingRe.firstMatch(rest);
      if (tagged != null && rest.startsWith(tagged[1]!)) {
        final tag = tagged[1]!;
        if (!skippedSectionTags.contains(tag)) {
          throw OpenitiException('سطر $lineNo: وسم قسم مجهول |$tag|');
        }
        stats.add('قسم محذوف بوسم OpenITI |$tag|');
        current = null;
        sectionSkip = true;
        continue;
      }
      sectionSkip = false;
      // علامات الصفحة والمعالم داخل سطر العنوان.
      final probe = OpenitiParagraph(lineNo);
      addContent(probe, rest, lineNo);
      rest = cleanText(probe.raw);
      _checkUnknown(rest, lineNo);
      current = null;
      if (rest.isEmpty) {
        stats.add('عنوان فارغ');
        continue;
      }
      items.add(OpenitiHeadingItem(rest, pipes, lineNo));
      usedHeadings.add(rest);
      continue;
    }

    String content;
    bool continuation;
    if (line.startsWith('~~')) {
      content = line.substring(2);
      continuation = true;
    } else if (line == '#' || line.startsWith('# ')) {
      content = line.length > 2 ? line.substring(2) : '';
      continuation = false;
    } else if (RegExp(r'^\s*(PageV\d+P\d+|ms\d+)(\s+(PageV\d+P\d+|ms\d+))*\s*$').hasMatch(line)) {
      // علامات وحدها في سطر بلا «# » (تظهر في بعض الملفات): لا تغيّر الفقرة.
      final p = current ?? OpenitiParagraph(lineNo);
      addContent(p, line, lineNo);
      continue;
    } else {
      throw OpenitiException('سطر $lineNo: بداية سطر غير معروفة في mARkdown: «${_short(line)}»');
    }

    if (sectionSkip) {
      stats.add('سطر ضمن قسم PARATEXT/EDITOR');
      // علامات الصفحات فيه تبقى محسوبة لترقيم ما قبله.
      for (final m in _markerRe.allMatches(content)) {
        _marker(m[0]!, pending, stats, () => pageSinceText = true);
      }
      continue;
    }

    final isMarkerOnly = content.replaceAll(_markerRe, '').trim().isEmpty;
    if (continuation) {
      if (current == null) {
        if (isMarkerOnly) {
          addContent(OpenitiParagraph(lineNo), content, lineNo);
          continue;
        }
        throw OpenitiException('سطر $lineNo: سطر ملحق ~~ بلا فقرة قبله.');
      }
      if (!isMarkerOnly && current.raw.contains('%~%') && !content.contains('%~%')) {
        // البيت سطر واحد في mARkdown؛ نثر ملحق به أثرُ حدّ صفحة أسقط «# »، فهو فقرة جديدة.
        stats.add('سطر نثر ملحق ~~ بعد بيت (عومل فقرة جديدة)');
        final p = OpenitiParagraph(lineNo);
        items.add(p);
        pending.add(p);
        current = p;
        addContent(p, content, lineNo);
        continue;
      }
      addContent(current, content, lineNo);
      continue;
    }

    if (isMarkerOnly) {
      // «# PageV01P010»: علامة صفحة على سطر مستقل؛ لا تبدأ فقرة.
      addContent(current ?? OpenitiParagraph(lineNo), content, lineNo);
      continue;
    }

    final prev = current;
    if (recipe.mergePageBreaks &&
        prev != null &&
        pageSinceText &&
        !prev.raw.contains('%~%') &&
        !content.contains('%~%') &&
        !_terminal.hasMatch(cleanText(prev.raw.replaceAll(_markerRe, '')))) {
      if (_looksLikeVerse(prev)) {
        stats.add('لم يُوصل عبر حدّ الصفحة: الفقرة السابقة تنتهي ببيت');
      } else if (_startsNewReport(content, recipe, prev)) {
        stats.add('لم يُوصل عبر حدّ الصفحة: السطر يبدأ بفاتحة خبر');
      } else {
        stats.add('فقرة موصولة عبر حدّ الصفحة');
        addContent(prev, content, lineNo);
        continue;
      }
    }
    final p = OpenitiParagraph(lineNo)..afterVerseOrColon = _isVerseOrColon(prev);
    items.add(p);
    pending.add(p);
    current = p;
    addContent(p, content, lineNo);
  }
  if (openSpan != null) throw OpenitiException('مقطع drop_spans «${openSpan.name}» لم يُغلق حتى آخر الملف.');
  if (pending.isNotEmpty) stats.add('فقرة بلا علامة صفحة بعدها (بلا page)', pending.length);

  final unused = recipe.headings.keys.where((k) => !usedHeadings.contains(k)).toList()..sort();
  if (unused.isNotEmpty) {
    throw OpenitiException('عناوين في الوصفة (headings) غير موجودة في المصدر: ${unused.join('، ')}');
  }
  return OpenitiDocument(meta, items);
}

void _marker(String m, List<OpenitiParagraph> pending, RemovalStats stats, void Function() onPage) {
  final pm = _pageRe.matchAsPrefix(m);
  if (pm != null) {
    // اصطلاح OpenITI: العلامة في نهاية الصفحة، فكل فقرة بدأت منذ العلامة السابقة تبدأ في هذه الصفحة.
    final page = 'V${pm[1]}P${pm[2]}';
    for (final p in pending) {
      p.page = page;
    }
    pending.clear();
    stats.add('علامة صفحة (حُفظت في page)');
    onPage();
    return;
  }
  if (_milestoneRe.hasMatch(m)) {
    stats.add('علامة مَعلَم ms (حُذفت)');
    return;
  }
  throw OpenitiException('علامة غير معروفة: $m');
}

void _checkUnknown(String t, int lineNo) {
  final m = _unknownMarkup.firstMatch(t);
  if (m != null) {
    final start = (m.start - 30).clamp(0, t.length);
    final end = (m.end + 30).clamp(0, t.length);
    throw OpenitiException(
      'سطر $lineNo: وسم أو محرف مجهول «${m[0]}» في: «${t.substring(start, end)}». '
      'أضف قاعدة صريحة في الوصفة (rules/drop_lines) بعد مراجعته، ولا يُحذف بصمت.',
    );
  }
}

String _short(String s) => s.length > 80 ? '${s.substring(0, 80)}…' : s;

// ---------------------------------------------------------------------------
// البناء

/// أرقام عربية مشرقية (١٢) لترقيم العناوين.
String toArabicIndicDigits(int n) =>
    n.toString().split('').map((d) => String.fromCharCode(0x0660 + int.parse(d))).join();

/// يحوّل نص المصدر إلى ملف الكتاب. [sourceBytes] بايتات الملف كما جُلبت (يُتحقق من sha256).
BuildResult buildOpenitiBook(OpenitiRecipe recipe, List<int> sourceBytes) {
  if (!recipe.isPinned) {
    throw StateError('الوصفة غير مثبّتة (sha256/retrieved ناقص): شغّل fetch_openiti أولاً.');
  }
  final digest = sha256.convert(sourceBytes).toString();
  if (digest != recipe.sha256) {
    throw StateError('sha256 للمصدر ($digest) لا يطابق الوصفة (${recipe.sha256}).');
  }
  final String source;
  try {
    source = const Utf8Decoder(allowMalformed: false).convert(sourceBytes);
  } on FormatException catch (e) {
    throw OpenitiException('المصدر ليس UTF-8 صالحاً: ${e.message}');
  }
  final stats = RemovalStats();
  final doc = parseOpeniti(source, recipe, stats);

  final skip = recipe.skipHeadings.map(cleanText).toSet();
  final chapters = <DraftChapter>[];
  DraftChapter? current;
  int? skippingLevel;
  Map<String, Object?>? openVerse; // آخر فقرة شعر، لتجميع الأبيات المتتالية.

  for (final item in doc.items) {
    switch (item) {
      case OpenitiHeadingItem(:final text, :final pipes):
        openVerse = null;
        final override = recipe.headings[text];
        final levelRule = recipe.headingLevels
            .where((r) => r.pattern.matchAsPrefix(text)?.end == text.length)
            .firstOrNull;
        final ruleLevel = levelRule == null ? null : int.parse(levelRule.replacement);
        if (levelRule != null) stats.add('مستوى عنوان بالوصفة: ${levelRule.name}');
        var lvl = override?.level ?? ruleLevel ?? (pipes > 3 ? 3 : pipes);
        if (skippingLevel != null && lvl > skippingLevel) {
          stats.add('قسم محذوف (فرعي): $text');
          continue;
        }
        skippingLevel = null;
        if (skip.contains(text)) {
          skippingLevel = lvl;
          stats.add('قسم محذوف: $text');
          continue;
        }
        if (override?.drop ?? false) {
          stats.add('عنوان محذوف بالوصفة (النص بعده يبقى في الباب السابق): $text');
          continue;
        }
        final dropRule =
            recipe.dropHeadings.where((r) => (r.pipes == null || r.pipes == pipes) && r.fullMatch(text)).firstOrNull;
        if (dropRule != null) {
          stats.add('عنوان محذوف (نصه يبقى في الباب السابق): ${dropRule.name}');
          continue;
        }
        if (pipes > 3 && override?.level == null && ruleLevel == null) stats.add('عنوان أعمق من 3 مستويات (عومل كمستوى 3)');
        final parent = chapters.isEmpty ? 0 : chapters.last.level;
        if (lvl > parent + 1) lvl = parent + 1;
        var title = override?.title ?? text;
        if (override?.title == null) {
          for (final r in recipe.headingRules) {
            final n = r.pattern.allMatches(title).length;
            if (n > 0) {
              stats.add('قاعدة عنوان: ${r.name}', n);
              title = title.replaceAllMapped(r.pattern, r.expand);
            }
          }
          title = cleanText(title);
          if (title.isEmpty) throw OpenitiException('عنوان «$text» صار فارغاً بعد heading_rules.');
        }
        if (recipe.bareHeading != null && lvl == 1 && title == recipe.bareHeading) {
          final n = chapters.where((c) => c.level == 1).length + 1;
          title = recipe.bareHeadingFormat!.replaceAll('{n}', toArabicIndicDigits(n));
          stats.add('عنوان «${recipe.bareHeading}» بلا اسم رُقّم بترتيبه');
        }
        current = DraftChapter(title, lvl);
        chapters.add(current);
      case OpenitiParagraph():
        if (skippingLevel != null) {
          stats.add('فقرة ضمن قسم محذوف');
          continue;
        }
        var raw = item.raw;
        for (final r in recipe.paragraphRules) {
          final n = r.pattern.allMatches(raw).length;
          if (n > 0) {
            stats.add('قاعدة فقرة: ${r.name}', n);
            raw = raw.replaceAllMapped(r.pattern, r.expand);
          }
        }
        final text = cleanText(raw);
        if (text.isEmpty) {
          stats.add('فقرة فارغة بعد التنظيف');
          continue;
        }
        if (!RegExp('[ء-ي]').hasMatch(text)) {
          stats.add('فقرة بلا حروف بعد التنظيف (علامة ترقيم وحدها)');
          continue;
        }
        final dropPara = recipe.dropParagraphs.where((r) => r.fullMatch(text)).firstOrNull;
        if (dropPara != null) {
          stats.add('فقرة محذوفة: ${dropPara.name}');
          continue;
        }
        if (current == null) {
          if (recipe.prefaceTitle == null) {
            throw OpenitiException('سطر ${item.line}: نص قبل أول عنوان؛ حدّد preface_title في الوصفة.');
          }
          current = DraftChapter(recipe.prefaceTitle!, 1);
          chapters.add(current);
        }
        if (text.contains('%~%')) {
          if (item.lines.length > 1) {
            throw OpenitiException('سطر ${item.line}: بيت (%~%) ممتد على أكثر من سطر؛ أصلحه بقاعدة في الوصفة.');
          }
          final parts = text.split('%~%').map((p) => p.trim()).toList();
          final empty = parts.where((p) => p.isEmpty).length;
          if (empty > 0) stats.add('شطر فارغ حول %~% (بيت بشطر واحد)', empty);
          final halves = parts.where((p) => p.isNotEmpty).toList();
          if (halves.isEmpty) {
            stats.add('فقرة فارغة بعد التنظيف');
            continue;
          }
          if (halves.length > 2) {
            throw OpenitiException('سطر ${item.line}: أكثر من شطرين في سطر واحد.');
          }
          for (final h in halves) {
            _checkUnknown(h, item.line);
          }
          final verseLine = halves.join('\t');
          if (openVerse != null && identical(current.paragraphs.last, openVerse)) {
            openVerse['text'] = '${openVerse['text']}\n$verseLine';
          } else {
            openVerse = {'kind': 'verse', 'text': verseLine, if (item.page != null) 'page': item.page};
            current.paragraphs.add(openVerse);
          }
          continue;
        }
        _checkUnknown(text, item.line);
        openVerse = null;
        current.paragraphs.add({'text': text, if (item.page != null) 'page': item.page});
    }
  }

  final outChapters = finalizeChapters(recipe.id, chapters, stats);
  final book = <String, Object?>{
    'schema': 1,
    'id': recipe.id,
    'version': recipe.version,
    'title': {'ar': recipe.titleAr, 'en': recipe.titleEn},
    'author': {'ar': recipe.authorAr, 'en': recipe.authorEn},
    'author_death_hijri': recipe.authorDeathHijri,
    'source': {
      'name': recipe.sourceName,
      'url': recipe.sourceUrl,
      'retrieved': recipe.retrieved,
      if (recipe.edition != null) 'edition': recipe.edition,
      if (recipe.originalSource != null) 'original': recipe.originalSource,
      'openiti': {
        'uri': recipe.versionUri,
        'repo': recipe.repo,
        'commit': recipe.commit,
        'path': recipe.path,
        'sha256': recipe.sha256,
      },
    },
    'license': recipe.license,
    'removed': recipe.removed,
    'chapters': outChapters,
    'redirects': {
      for (final k in (recipe.redirects.keys.toList()..sort())) k: recipe.redirects[k],
    },
  };
  return BuildResult(book, stats);
}

// ---------------------------------------------------------------------------
// الجلب

class OpenitiFetchException implements Exception {
  OpenitiFetchException(this.message, {this.network = false});
  final String message;
  final bool network;
  @override
  String toString() => message;
}

File openitiCacheFile(Directory cacheDir) => File('${cacheDir.path}/openiti.txt');

/// يجلب ملف المصدر من raw.githubusercontent.com بالـ commit المثبّت (أو ينسخه من
/// مستنسخ محلي [localRepo] على الـ commit نفسه)، ويتحقق من sha256. في المسودة
/// (بلا sha256) يثبّت sha256 و[today] في الوصفة ويحفظها.
Future<List<int>> fetchOpeniti({
  required OpenitiRecipe recipe,
  required File recipeFile,
  required Directory cacheDir,
  required String today,
  http.Client? client,
  Directory? localRepo,
}) async {
  List<int> bytes;
  if (localRepo != null) {
    final head = await Process.run('git', ['-C', localRepo.path, 'rev-parse', 'HEAD']);
    final sha = (head.stdout as String).trim();
    if (head.exitCode != 0 || sha != recipe.commit) {
      throw OpenitiFetchException('المستنسخ المحلي ${localRepo.path} ليس على commit الوصفة '
          '(${recipe.commit})، بل على «$sha».');
    }
    final f = File('${localRepo.path}/${recipe.path}');
    if (!f.existsSync()) throw OpenitiFetchException('الملف غير موجود في المستنسخ: ${f.path}');
    bytes = f.readAsBytesSync();
  } else {
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse(recipe.rawUrl));
      if (res.statusCode != 200) {
        throw OpenitiFetchException('ردّ GitHub بالرمز HTTP ${res.statusCode} لـ ${recipe.rawUrl}');
      }
      bytes = res.bodyBytes;
    } on http.ClientException catch (e) {
      throw OpenitiFetchException('تعذّر الاتصال بـ raw.githubusercontent.com: ${e.message}', network: true);
    } on SocketException catch (e) {
      throw OpenitiFetchException('تعذّر الاتصال (انقطاع الشبكة): ${e.message}', network: true);
    } finally {
      if (client == null) c.close();
    }
  }
  final digest = sha256.convert(bytes).toString();
  if (recipe.sha256 == null) {
    recipe
      ..sha256 = digest
      ..retrieved = today;
    recipe.save(recipeFile);
  } else if (digest != recipe.sha256) {
    throw OpenitiFetchException('sha256 للملف المجلوب ($digest) لا يطابق الوصفة (${recipe.sha256}).');
  }
  cacheDir.createSync(recursive: true);
  openitiCacheFile(cacheDir).writeAsBytesSync(bytes);
  return bytes;
}
