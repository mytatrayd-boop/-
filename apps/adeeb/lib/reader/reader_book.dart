/// نموذج الكتاب في القارئ: الأبواب والفقرات بترتيبها، وقائمة «مدخلات» مسطّحة
/// يعرضها التمرير المتصل (عنوان باب ثم فقراته). Dart صافٍ.
library;

import '../library/catalog.dart';

class ReaderChapter {
  const ReaderChapter({
    required this.id,
    required this.title,
    required this.level,
    required this.entryIndex,
    required this.firstParagraph,
  });

  final String id;
  final String title;
  final int level;

  /// موضع عنوان الباب في [ReaderBook.entryCount].
  final int entryIndex;

  /// فهرس أول فقرة في الباب، أو -1 إن كان الباب بلا فقرات (عنوان قسم فقط).
  final int firstParagraph;
}

class ReaderParagraph {
  const ReaderParagraph({
    required this.id,
    required this.chapterIndex,
    required this.kind,
    required this.text,
    this.tts,
  });

  final String id;
  final int chapterIndex;

  /// `prose` أو `verse` (الأبيات بـ `\n` والشطران بـ `\t`).
  final String kind;
  final String text;

  /// نص النطق المشكول إن وُجد (للصوت فقط).
  final String? tts;

  /// ما يُنطق: [tts] إن وُجد وإلا [text].
  String get speechText => tts ?? text;

  bool get isVerse => kind == 'verse';
}

/// مدخل في التمرير: عنوان باب أو فقرة.
sealed class ReaderEntry {
  const ReaderEntry();
}

class HeadingEntry extends ReaderEntry {
  const HeadingEntry(this.chapterIndex);
  final int chapterIndex;
}

class ParagraphEntry extends ReaderEntry {
  const ParagraphEntry(this.paragraphIndex);
  final int paragraphIndex;
}

class ReaderBook {
  ReaderBook({
    required this.id,
    required this.title,
    required this.author,
    required this.authorDeathHijri,
    required this.chapters,
    required this.paragraphs,
  }) : _paragraphEntry = List<int>.filled(paragraphs.length, 0) {
    var p = 0;
    for (var c = 0; c < chapters.length; c++) {
      while (p < paragraphs.length && paragraphs[p].chapterIndex == c) {
        _paragraphEntry[p] =
            chapters[c].entryIndex + 1 + (p - chapters[c].firstParagraph);
        p++;
      }
    }
    for (var i = 0; i < paragraphs.length; i++) {
      _indexById[paragraphs[i].id] = i;
    }
  }

  /// يبني الأبواب والفقرات من صفوف مرتّبة. [rawChapters]: (id, title, level)،
  /// و[rawParagraphs]: (id, chapterId, kind, text, tts) بترتيب الكتاب.
  factory ReaderBook.fromRows({
    required String id,
    required LocalizedName title,
    required LocalizedName author,
    required int? authorDeathHijri,
    required List<({String id, String title, int level})> rawChapters,
    required List<
      ({String id, String chapterId, String kind, String text, String? tts})
    >
    rawParagraphs,
  }) {
    final chapterIndex = {
      for (var i = 0; i < rawChapters.length; i++) rawChapters[i].id: i,
    };
    final byChapter = List<List<int>>.generate(rawChapters.length, (_) => []);
    for (var i = 0; i < rawParagraphs.length; i++) {
      final c = chapterIndex[rawParagraphs[i].chapterId];
      if (c != null) byChapter[c].add(i);
    }
    final paragraphs = <ReaderParagraph>[];
    final chapters = <ReaderChapter>[];
    var entry = 0;
    for (var c = 0; c < rawChapters.length; c++) {
      final raw = rawChapters[c];
      chapters.add(
        ReaderChapter(
          id: raw.id,
          title: raw.title,
          level: raw.level,
          entryIndex: entry,
          firstParagraph: byChapter[c].isEmpty ? -1 : paragraphs.length,
        ),
      );
      entry += 1 + byChapter[c].length;
      for (final i in byChapter[c]) {
        final p = rawParagraphs[i];
        paragraphs.add(
          ReaderParagraph(
            id: p.id,
            chapterIndex: c,
            kind: p.kind,
            text: p.text,
            tts: p.tts,
          ),
        );
      }
    }
    return ReaderBook(
      id: id,
      title: title,
      author: author,
      authorDeathHijri: authorDeathHijri,
      chapters: chapters,
      paragraphs: paragraphs,
    );
  }

  final String id;
  final LocalizedName title;
  final LocalizedName author;
  final int? authorDeathHijri;
  final List<ReaderChapter> chapters;
  final List<ReaderParagraph> paragraphs;
  final List<int> _paragraphEntry;
  final _indexById = <String, int>{};

  int get entryCount => chapters.length + paragraphs.length;

  /// فهرس الفقرة بمعرّفها، أو null.
  int? paragraphIndexOf(String id) => _indexById[id];

  int entryOfParagraph(int paragraphIndex) => _paragraphEntry[paragraphIndex];

  int? chapterIndexOf(String chapterId) {
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].id == chapterId) return i;
    }
    return null;
  }

  /// المدخل رقم [index] (بحث ثنائي في مواضع العناوين).
  ReaderEntry entryAt(int index) {
    var lo = 0;
    var hi = chapters.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (chapters[mid].entryIndex <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final chapter = chapters[lo];
    if (chapter.entryIndex == index) return HeadingEntry(lo);
    return ParagraphEntry(
      chapter.firstParagraph + index - chapter.entryIndex - 1,
    );
  }

  /// الباب الذي يحوي المدخل [index].
  int chapterOfEntry(int index) => switch (entryAt(index)) {
    HeadingEntry(:final chapterIndex) => chapterIndex,
    ParagraphEntry(:final paragraphIndex) =>
      paragraphs[paragraphIndex].chapterIndex,
  };

  /// أول فقرة عند المدخل [index] أو بعده (عنوان الباب ← أول فقرة فيه)، أو
  /// آخر فقرة قبله إن لم توجد بعده. null إن كان الكتاب بلا فقرات.
  int? paragraphAtOrAfterEntry(int index) {
    if (paragraphs.isEmpty) return null;
    for (var i = index; i < entryCount; i++) {
      if (entryAt(i) case ParagraphEntry(:final paragraphIndex)) {
        return paragraphIndex;
      }
    }
    for (var i = index - 1; i >= 0; i--) {
      if (entryAt(i) case ParagraphEntry(:final paragraphIndex)) {
        return paragraphIndex;
      }
    }
    return null;
  }

  /// مدخل البداية لفتح الباب: عنوانه.
  int entryOfChapter(int chapterIndex) => chapters[chapterIndex].entryIndex;

  /// معرّف الباب من معرّف الفقرة (`<باب>-pNNNNN`)، لفتح الباب حين تختفي الفقرة.
  static String? chapterIdOfParagraphId(String paragraphId) {
    final match = RegExp(r'^(.+)-p\d+$').firstMatch(paragraphId);
    return match?.group(1);
  }

  /// نسبة التقدّم (0–1) عند الفقرة [paragraphIndex].
  double progressAt(int paragraphIndex) =>
      paragraphs.isEmpty ? 0 : (paragraphIndex + 1) / paragraphs.length;
}
