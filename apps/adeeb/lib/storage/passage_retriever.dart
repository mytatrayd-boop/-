/// استرجاع فقرات «اسأل الأديب» من فهرس FTS5 (ARCHITECTURE §7): OR بين
/// الكلمات وجذوعها، ترتيب bm25 عبر الكتب المحمّلة أو كتاب واحد. القراءة فقط؛
/// في Isolate منفصل. Dart صافٍ.
library;

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../ask/ask_passages.dart';
import '../ask/ask_query.dart';
import '../ask/ask_service.dart';
import 'app_database.dart';

class SqlitePassageRetriever implements PassageRetriever {
  SqlitePassageRetriever(this.dbPath, {this.useIsolate = true});

  final String dbPath;
  final bool useIsolate;

  @override
  Future<List<LocalParagraph>> retrieve(
    AskQuery query, {
    String? bookId,
    int limit = maxPassages,
  }) async {
    if (query.isEmpty) return const [];
    await ensureDatabaseReady(dbPath, useIsolate: useIsolate);
    final path = dbPath;
    List<LocalParagraph> task() {
      final db = openAppDatabase(path);
      try {
        return retrieveParagraphs(db, query, bookId: bookId, limit: limit);
      } finally {
        db.close();
      }
    }

    return useIsolate ? Isolate.run(task) : Future.sync(task);
  }
}

/// أفضل [limit] فقرة: [candidateCount] مرشحاً بـ bm25 (OR بين الكلمات)، ثم
/// إعادة الترتيب بعدد كلمات السؤال المطابقة (D28). الفقرة التمهيدية تحمل
/// الفقرة التالية في بابها.
List<LocalParagraph> retrieveParagraphs(
  Database db,
  AskQuery query, {
  String? bookId,
  int limit = maxPassages,
}) {
  if (query.isEmpty) return const [];
  final scope = bookId == null ? '' : 'AND p.book_id = ? ';
  final rows = db.select(
    'SELECT p.id, p.book_id, p.chapter_id, p.ord, p.text, '
    'c.title AS chapter_title, b.title_ar, b.author_ar '
    'FROM paragraphs_fts '
    'JOIN paragraphs p ON p.rowid = paragraphs_fts.rowid '
    'JOIN books b ON b.id = p.book_id '
    'JOIN chapters c ON c.id = p.chapter_id '
    'WHERE paragraphs_fts MATCH ? $scope'
    'ORDER BY bm25(paragraphs_fts), b.installed_at, p.ord '
    'LIMIT ?',
    [query.toFtsMatch(), ?bookId, candidateCount],
  );
  final nextStmt = db.prepare(
    'SELECT id, text FROM paragraphs '
    'WHERE book_id = ? AND chapter_id = ? AND ord > ? ORDER BY ord LIMIT 1',
  );
  try {
    final candidates = [
      for (final r in rows)
        () {
          final text = r['text'] as String;
          LocalParagraph? next;
          if (isIntroParagraph(text)) {
            final n = nextStmt.select([
              r['book_id'],
              r['chapter_id'],
              r['ord'],
            ]);
            if (n.isNotEmpty) {
              next = LocalParagraph(
                id: n.first['id'] as String,
                bookId: r['book_id'] as String,
                bookTitle: r['title_ar'] as String,
                chapterTitle: r['chapter_title'] as String,
                text: n.first['text'] as String,
              );
            }
          }
          return LocalParagraph(
            id: r['id'] as String,
            bookId: r['book_id'] as String,
            bookTitle: r['title_ar'] as String,
            chapterTitle: r['chapter_title'] as String,
            text: text,
            bookAuthor: r['author_ar'] as String,
            next: next,
          );
        }(),
    ];
    return rerankCandidates(candidates, query).take(limit).toList();
  } finally {
    nextStmt.close();
  }
}
