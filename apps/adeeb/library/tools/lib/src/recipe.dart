/// «وصفة» الكتاب: كل ما يلزم لتحويل كتاب من ويكي مصدر تحويلاً حتمياً.
/// المراجعات (revid) مثبّتة فيها، فالمصدر نفسه يُجلب دائماً.
library;

import 'dart:convert';
import 'dart:io';

class RecipePage {
  RecipePage({
    required this.title,
    this.revid,
    this.chapterTitle,
    this.skip = false,
  });

  /// عنوان الصفحة في ويكي مصدر (مثل «كتاب/باب»).
  final String title;

  /// رقم المراجعة المثبّت؛ null في المسودة قبل أول جلب.
  int? revid;

  /// عنوان الباب في الكتاب؛ إن غاب يُؤخذ آخر جزء من عنوان الصفحة.
  final String? chapterTitle;

  /// صفحة تُتجاهل كلها (مثل مقدمة محقق معاصر).
  final bool skip;

  String get effectiveChapterTitle {
    if (chapterTitle != null && chapterTitle!.trim().isNotEmpty) {
      return chapterTitle!.trim();
    }
    final parts = title.split('/');
    return parts.last.replaceAll('_', ' ').trim();
  }

  Map<String, Object?> toJson() => {
        'title': title,
        'revid': revid,
        if (chapterTitle != null) 'chapter_title': chapterTitle,
        if (skip) 'skip': true,
      };

  static RecipePage fromJson(Map<String, Object?> j) => RecipePage(
        title: j['title']! as String,
        revid: j['revid'] as int?,
        chapterTitle: j['chapter_title'] as String?,
        skip: (j['skip'] as bool?) ?? false,
      );
}

class TemplateRules {
  TemplateRules({
    this.drop = const [],
    this.unwrap = const {},
    this.verse = const [],
  });

  /// قوالب تُحذف بمحتواها (ترويسات، تنقّل، تنسيق بلا نص).
  final List<String> drop;

  /// قوالب يُبقى منها وسيط موضعي واحد (الرقم يبدأ من 1).
  final Map<String, int> unwrap;

  /// قوالب بيت شعر: الوسيطان الموضعيان الأول والثاني = الصدر والعجز.
  final List<String> verse;

  Map<String, Object?> toJson() => {
        'drop': drop,
        'unwrap': unwrap,
        'verse': verse,
      };

  static TemplateRules fromJson(Map<String, Object?>? j) {
    if (j == null) return TemplateRules();
    return TemplateRules(
      drop: [...((j['drop'] as List?) ?? const []).cast<String>()],
      unwrap: {
        ...((j['unwrap'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, v as int),
        ),
      },
      verse: [...((j['verse'] as List?) ?? const []).cast<String>()],
    );
  }
}

class Recipe {
  Recipe({
    required this.id,
    required this.version,
    required this.titleAr,
    required this.titleEn,
    required this.authorAr,
    required this.authorEn,
    required this.authorDeathHijri,
    required this.wiki,
    required this.rootPage,
    required this.pages,
    required this.license,
    required this.removed,
    this.sourceName = 'ويكي مصدر',
    this.edition,
    this.retrieved,
    this.skipHeadings = const [],
    this.redirects = const {},
    this.validationExceptions = const {},
    TemplateRules? templates,
  }) : templates = templates ?? TemplateRules();

  final String id;
  final int version;
  final String titleAr;
  final String titleEn;
  final String authorAr;
  final String authorEn;
  final int authorDeathHijri;

  /// مضيف الويكي، مثل ar.wikisource.org.
  final String wiki;
  final String rootPage;
  final List<RecipePage> pages;
  final String license;

  /// وصف ما حُذف (يُنسخ إلى ملف الكتاب كما هو).
  final String removed;
  final String sourceName;
  final String? edition;

  /// تاريخ الجلب YYYY-MM-DD، يكتبه أمر الجلب عند تثبيت المراجعات.
  String? retrieved;

  /// عناوين أقسام داخل الصفحات تُحذف مع ما تحتها (مقدمات وحواشي معاصرة).
  final List<String> skipHeadings;
  final TemplateRules templates;

  /// معرّف قديم ← معرّف جديد، يُنسخ كما هو إلى `redirects` في ملف الكتاب.
  final Map<String, String> redirects;

  /// استثناءات مراجَعة يدوياً: معرّف ← رموز تحقق مسموح بها (مثل footnote_attached_number).
  final Map<String, List<String>> validationExceptions;

  String get sourceUrl =>
      'https://$wiki/wiki/${Uri.encodeComponent(rootPage.replaceAll(' ', '_'))}';

  bool get isPinned =>
      retrieved != null && pages.isNotEmpty && pages.every((p) => p.revid != null);

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version,
        'title': {'ar': titleAr, 'en': titleEn},
        'author': {'ar': authorAr, 'en': authorEn},
        'author_death_hijri': authorDeathHijri,
        'source_name': sourceName,
        'wiki': wiki,
        'root_page': rootPage,
        if (edition != null) 'edition': edition,
        'retrieved': retrieved,
        'license': license,
        'removed': removed,
        'skip_headings': skipHeadings,
        'templates': templates.toJson(),
        if (redirects.isNotEmpty) 'redirects': redirects,
        if (validationExceptions.isNotEmpty) 'validation_exceptions': validationExceptions,
        'pages': [for (final p in pages) p.toJson()],
      };

  static Recipe fromJson(Map<String, Object?> j) {
    final title = j['title']! as Map<String, Object?>;
    final author = j['author']! as Map<String, Object?>;
    return Recipe(
      id: j['id']! as String,
      version: j['version']! as int,
      titleAr: title['ar']! as String,
      titleEn: title['en']! as String,
      authorAr: author['ar']! as String,
      authorEn: author['en']! as String,
      authorDeathHijri: j['author_death_hijri']! as int,
      sourceName: (j['source_name'] as String?) ?? 'ويكي مصدر',
      wiki: j['wiki']! as String,
      rootPage: j['root_page']! as String,
      edition: j['edition'] as String?,
      retrieved: j['retrieved'] as String?,
      license: j['license']! as String,
      removed: j['removed']! as String,
      skipHeadings: [...((j['skip_headings'] as List?) ?? const []).cast<String>()],
      templates: TemplateRules.fromJson(j['templates'] as Map<String, Object?>?),
      redirects: {
        ...((j['redirects'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
      },
      validationExceptions: {
        ...((j['validation_exceptions'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, [...(v as List).cast<String>()])),
      },
      pages: [
        for (final p in (j['pages']! as List).cast<Map<String, Object?>>())
          RecipePage.fromJson(p),
      ],
    );
  }

  static Recipe load(File f) =>
      fromJson(jsonDecode(f.readAsStringSync()) as Map<String, Object?>);

  void save(File f) => f.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(toJson())}\n',
      );
}
