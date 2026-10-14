/// بناء ملف الكتاب (schema 1، ARCHITECTURE §4.2) من الوصفة ونصوص الصفحات.
/// حتمي: لا ساعة ولا عشوائية؛ التاريخ من الوصفة والترتيب من ترتيب الصفحات.
library;

import 'dart:convert';
import 'dart:io';

import 'recipe.dart';
import 'wikitext.dart';

class BuildResult {
  BuildResult(this.book, this.stats);
  final Map<String, Object?> book;
  final RemovalStats stats;

  List<Map<String, Object?>> get chapters =>
      (book['chapters']! as List).cast<Map<String, Object?>>();

  int get paragraphCount => chapters.fold(
        0,
        (n, c) => n + (c['paragraphs']! as List).length,
      );
}

/// باب قيد البناء: عنوان ومستوى وفقرات بلا معرّفات بعد.
class DraftChapter {
  DraftChapter(this.title, this.level);
  final String title;
  final int level;

  /// كل فقرة: `text` و`kind` اختياري و`page` اختياري (بلا `id`).
  final List<Map<String, Object?>> paragraphs = [];
}

/// [pageTexts]: نص الويكي لكل صفحة غير متجاهلة، بالمفتاح revid.
BuildResult buildBook(Recipe recipe, Map<int, String> pageTexts) {
  if (!recipe.isPinned) {
    throw StateError('الوصفة غير مثبّتة (revid/retrieved ناقص): شغّل fetch أولاً.');
  }
  final conv = WikitextConverter(recipe.templates);
  final stats = RemovalStats();
  final skip = recipe.skipHeadings.map((h) => cleanText(h)).toSet();
  final chapters = <DraftChapter>[];

  for (final page in recipe.pages) {
    if (page.skip) {
      stats.add('صفحة متجاهلة: ${page.title}');
      continue;
    }
    final text = pageTexts[page.revid];
    if (text == null) {
      throw StateError('نص المراجعة ${page.revid} (${page.title}) غير موجود في الذاكرة المؤقتة.');
    }
    final blocks = conv.convert(text, stats);
    var current = DraftChapter(page.effectiveChapterTitle, 1);
    chapters.add(current);
    int? skippingLevel;
    for (final b in blocks) {
      switch (b) {
        case HeadingBlock(:final level, :final text):
          final lvl = level <= 2 ? 2 : 3;
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
          // لا قفز في المستوى: === مباشرة تحت باب الصفحة تصبح مستوى 2.
          final parent = chapters.last.level;
          current = DraftChapter(text, lvl > parent + 1 ? parent + 1 : lvl);
          chapters.add(current);
        case ProseBlock(:final text):
          if (skippingLevel != null) {
            stats.add('فقرة ضمن قسم محذوف');
            continue;
          }
          current.paragraphs.add({'text': text});
        case VerseBlock():
          if (skippingLevel != null) {
            stats.add('فقرة ضمن قسم محذوف');
            continue;
          }
          current.paragraphs.add({'kind': 'verse', 'text': b.text});
      }
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
      'revisions': [
        for (final p in recipe.pages)
          if (!p.skip) p.revid,
      ],
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

/// يحذف الأبواب الفارغة (بلا فقرات ولا أبواب فرعية بعدها) ويعطي المعرّفات الثابتة.
/// مشترك بين مصدرَي ويكي مصدر وOpenITI حتى تبقى قواعد المعرّفات واحدة.
List<Map<String, Object?>> finalizeChapters(
  String bookId,
  List<DraftChapter> chapters,
  RemovalStats stats,
) {
  // حذف العناوين الفارغة: باب بلا فقرات ولا أبواب فرعية بعده.
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      final next = i + 1 < chapters.length ? chapters[i + 1] : null;
      if (c.paragraphs.isEmpty && (next == null || next.level <= c.level)) {
        stats.add('عنوان بلا نص (حُذف العنوان وحده)');
        chapters.removeAt(i);
        changed = true;
        break;
      }
    }
  }
  if (chapters.isEmpty) throw StateError('لم يُستخرج أي نص من الصفحات.');

  // عرض ثابت لكل الكتب والإصدارات (D17): 3 للباب و5 للفقرة، فلا يتغير معرّف
  // لمجرد أن كتاباً تجاوز 99 باباً أو 9999 فقرة في إصدار لاحق.
  const bWidth = 3, pWidth = 5;
  if (chapters.length > 999) throw StateError('أكثر من 999 باباً: يلزم تقسيم الكتاب.');
  for (final c in chapters) {
    if (c.paragraphs.length > 99999) throw StateError('باب بأكثر من 99999 فقرة: ${c.title}');
  }

  final outChapters = <Map<String, Object?>>[];
  for (var i = 0; i < chapters.length; i++) {
    final c = chapters[i];
    final cid = '$bookId-b${(i + 1).toString().padLeft(bWidth, '0')}';
    outChapters.add({
      'id': cid,
      'title': c.title,
      'level': c.level,
      'paragraphs': [
        for (var j = 0; j < c.paragraphs.length; j++)
          {
            'id': '$cid-p${(j + 1).toString().padLeft(pWidth, '0')}',
            ...c.paragraphs[j],
          },
      ],
    });
  }

  return outChapters;
}

/// JSON مضغوط بلا مسافات، بترتيب المفاتيح كما أُدخلت، وسطر أخير.
List<int> encodeBookJson(Map<String, Object?> book) =>
    utf8.encode('${jsonEncode(book)}\n');

/// gzip حتمي: ترويسة بلا وقت (mtime=0) ونظام تشغيل ثابت (255 = غير معروف).
List<int> gzipDeterministic(List<int> bytes) {
  final gz = GZipCodec(level: 9).encode(bytes);
  // ترويسة gzip: البايتات 4..7 = mtime، والبايت 9 = نظام التشغيل.
  for (var i = 4; i < 8; i++) {
    gz[i] = 0;
  }
  gz[9] = 255;
  return gz;
}

String bookRelativePath(String id, int version) =>
    'books/$id/$id.v$version.json.gz';
