/// البحث المحلي في فهرس FTS5 (ARCHITECTURE §6): كل الكتب المحمّلة أو كتاب
/// واحد، مرتبة حسب الكتاب ثم bm25، مع مقتطف ومواضع التظليل على النص الأصلي.
/// القراءة فقط؛ في Isolate منفصل. Dart صافٍ.
library;

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../text/search_query.dart';
import 'app_database.dart';

class SearchHit {
  const SearchHit({
    required this.paragraphId,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.snippet,
    required this.matchedWords,
  });

  final String paragraphId;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;

  /// مقتطف من النص الأصلي بتشكيله مع مواضع الكلمات المطابقة.
  final Snippet snippet;

  /// الكلمات المطابقة كما هي في النص (لقارئ الشاشة).
  final List<String> matchedWords;
}

/// عدد النتائج في كتاب، بترتيب الكتب في النتائج.
class BookHitCount {
  const BookHitCount(this.bookId, this.bookTitle, this.count);
  final String bookId;
  final String bookTitle;
  final int count;
}

class SearchPage {
  const SearchPage({required this.hits, required this.counts});

  final List<SearchHit> hits;

  /// العدد في كل كتاب (يُحسب مع الصفحة الأولى فقط؛ فارغ في الصفحات التالية).
  final List<BookHitCount> counts;

  int get total => counts.fold(0, (n, c) => n + c.count);
}

abstract interface class SearchRepository {
  /// [bookId] null = كل الكتب المحمّلة. [offset] > 0 للصفحات التالية.
  Future<SearchPage> search(
    SearchQuery query, {
    String? bookId,
    int offset = 0,
    int limit = 50,
  });
}

class SqliteSearchRepository implements SearchRepository {
  SqliteSearchRepository(this.dbPath, {this.useIsolate = true});

  final String dbPath;
  final bool useIsolate;

  @override
  Future<SearchPage> search(
    SearchQuery query, {
    String? bookId,
    int offset = 0,
    int limit = 50,
  }) async {
    await ensureDatabaseReady(dbPath, useIsolate: useIsolate);
    final path = dbPath;
    SearchPage task() {
      final db = openAppDatabase(path);
      try {
        return searchParagraphs(
          db,
          query,
          bookId: bookId,
          offset: offset,
          limit: limit,
        );
      } finally {
        db.close();
      }
    }

    return useIsolate ? Isolate.run(task) : Future.sync(task);
  }
}

SearchPage searchParagraphs(
  Database db,
  SearchQuery query, {
  String? bookId,
  int offset = 0,
  int limit = 50,
}) {
  if (query.isEmpty) return const SearchPage(hits: [], counts: []);
  final match = query.toFtsMatch();
  final scope = bookId == null ? '' : 'AND p.book_id = ? ';
  final params = [match, ?bookId];

  final counts = offset > 0
      ? const <BookHitCount>[]
      : db
            .select(
              'SELECT b.id, b.title_ar, n FROM ('
              'SELECT p.book_id AS book_id, COUNT(*) AS n FROM paragraphs_fts '
              'JOIN paragraphs p ON p.rowid = paragraphs_fts.rowid '
              'WHERE paragraphs_fts MATCH ? $scope'
              'GROUP BY p.book_id) '
              'JOIN books b ON b.id = book_id ORDER BY b.installed_at, b.id',
              params,
            )
            .map(
              (r) => BookHitCount(
                r['id'] as String,
                r['title_ar'] as String,
                r['n'] as int,
              ),
            )
            .toList();

  final rows = db.select(
    'SELECT p.id, p.book_id, p.text, c.title AS chapter_title, b.title_ar '
    'FROM paragraphs_fts '
    'JOIN paragraphs p ON p.rowid = paragraphs_fts.rowid '
    'JOIN books b ON b.id = p.book_id '
    'JOIN chapters c ON c.id = p.chapter_id '
    'WHERE paragraphs_fts MATCH ? $scope'
    'ORDER BY b.installed_at, b.id, bm25(paragraphs_fts), p.ord '
    'LIMIT ? OFFSET ?',
    [...params, limit, offset],
  );
  final hits = [
    for (final r in rows)
      () {
        final text = r['text'] as String;
        final spans = findMatches(text, query);
        final snippet = buildSnippet(text, spans);
        return SearchHit(
          paragraphId: r['id'] as String,
          bookId: r['book_id'] as String,
          bookTitle: r['title_ar'] as String,
          chapterTitle: r['chapter_title'] as String,
          snippet: snippet,
          matchedWords: {for (final s in spans) text.substring(s.start, s.end)}
              .toList(),
        );
      }(),
  ];
  return SearchPage(hits: hits, counts: counts);
}
