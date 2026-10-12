/// القراءة من SQLite: نص الكتاب للقارئ، وآخر موضع، والمفضلة (ARCHITECTURE §5).
/// القراءة الثقيلة (نص الكتاب كاملاً) في Isolate منفصل. Dart صافٍ.
library;

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../library/catalog.dart';
import '../reader/reader_book.dart';
import 'app_database.dart';
import 'book_repository.dart';
import 'write_queue.dart';

/// آخر موضع محفوظ في كتاب محمّل، مع ما يلزم لعرضه («تابع القراءة»، «وصلت إلى»).
class ReadingPosition {
  const ReadingPosition({
    required this.bookId,
    required this.bookTitle,
    required this.paragraphId,
    required this.paragraphText,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.chapterCount,
    required this.paragraphNumber,
    required this.paragraphCount,
  });

  final String bookId;
  final String bookTitle;
  final String paragraphId;
  final String paragraphText;
  final String chapterId;
  final String chapterTitle;

  /// رقم الباب من 1.
  final int chapterNumber;
  final int chapterCount;

  /// رقم الفقرة في الكتاب من 1.
  final int paragraphNumber;
  final int paragraphCount;

  double get fraction =>
      paragraphCount == 0 ? 0 : paragraphNumber / paragraphCount;
}

/// فقرة في المفضلة. [text] و[chapterTitle] و[bookTitle] null إن لم يكن
/// الكتاب محمّلاً (أو لم تعد الفقرة موجودة).
class FavoriteItem {
  const FavoriteItem({
    required this.paragraphId,
    required this.bookId,
    required this.createdAt,
    this.bookTitle,
    this.chapterTitle,
    this.text,
  });

  final String paragraphId;
  final String bookId;
  final int createdAt;
  final String? bookTitle;
  final String? chapterTitle;
  final String? text;

  bool get bookInstalled => bookTitle != null;
}

abstract interface class ReadingRepository {
  /// نص الكتاب للقارئ، أو null إن لم يكن محمّلاً.
  Future<ReaderBook?> loadBook(String bookId);

  /// يتبع `redirects` لمعرّف فقرة قديم.
  Future<String> resolveParagraph(String paragraphId);

  Future<void> savePosition(String bookId, String paragraphId);

  /// آخر موضع في [bookId] إن كان الكتاب محمّلاً والفقرة موجودة.
  Future<ReadingPosition?> position(String bookId);

  /// أحدث موضع في أي كتاب محمّل.
  Future<ReadingPosition?> latestPosition();

  Future<List<FavoriteItem>> favorites();

  /// [createdAt] لإعادة عنصر بعد «تراجع» في مكانه الأصلي.
  Future<void> addFavorite(String bookId, String paragraphId, {int? createdAt});

  Future<void> removeFavorite(String paragraphId);
}

class SqliteReadingRepository implements ReadingRepository {
  SqliteReadingRepository(
    this.dbPath, {
    this.useIsolate = true,
    this.clock = DateTime.now,
  });

  final String dbPath;
  final bool useIsolate;
  final DateTime Function() clock;

  Future<T> _run<T>(
    T Function(Database db) body, {
    bool isolate = false,
  }) async {
    await ensureDatabaseReady(dbPath, useIsolate: useIsolate);
    return _exec(body, isolate: isolate);
  }

  Future<T> _exec<T>(T Function(Database db) body, {bool isolate = false}) {
    final path = dbPath;
    T task() {
      final db = openAppDatabase(path);
      try {
        return body(db);
      } finally {
        db.close();
      }
    }

    return useIsolate && isolate ? Isolate.run(task) : Future.sync(task);
  }

  /// الكتابات عبر طابور الكتابة المشترك مع الاستيراد والحذف.
  Future<T> _write<T>(T Function(Database db) body) async {
    await ensureDatabaseReady(dbPath, useIsolate: useIsolate);
    return enqueueWrite(dbPath, () => _exec(body));
  }

  int get _now => clock().millisecondsSinceEpoch;

  @override
  Future<ReaderBook?> loadBook(String bookId) =>
      _run((db) => readReaderBook(db, bookId), isolate: true);

  @override
  Future<String> resolveParagraph(String paragraphId) =>
      _run((db) => resolveRedirect(db, paragraphId));

  @override
  Future<void> savePosition(String bookId, String paragraphId) {
    final now = _now;
    return _write(
      (db) => db.execute(
        'INSERT INTO positions (book_id, paragraph_id, updated_at) VALUES (?, ?, ?) '
        'ON CONFLICT(book_id) DO UPDATE SET paragraph_id = excluded.paragraph_id, '
        'updated_at = excluded.updated_at',
        [bookId, paragraphId, now],
      ),
    );
  }

  @override
  Future<ReadingPosition?> position(String bookId) =>
      _run((db) => readPosition(db, bookId: bookId));

  @override
  Future<ReadingPosition?> latestPosition() => _run((db) => readPosition(db));

  @override
  Future<List<FavoriteItem>> favorites() => _run(readFavorites);

  @override
  Future<void> addFavorite(
    String bookId,
    String paragraphId, {
    int? createdAt,
  }) {
    final at = createdAt ?? _now;
    return _write(
      (db) => db.execute(
        'INSERT OR REPLACE INTO favorites (paragraph_id, book_id, created_at) VALUES (?, ?, ?)',
        [paragraphId, bookId, at],
      ),
    );
  }

  @override
  Future<void> removeFavorite(String paragraphId) => _write(
    (db) => db.execute('DELETE FROM favorites WHERE paragraph_id = ?', [
      paragraphId,
    ]),
  );
}

ReaderBook? readReaderBook(Database db, String bookId) {
  final books = db.select('SELECT * FROM books WHERE id = ?', [bookId]);
  if (books.isEmpty) return null;
  final b = books.first;
  final chapters = db
      .select(
        'SELECT id, title, level FROM chapters WHERE book_id = ? ORDER BY ord',
        [bookId],
      )
      .map(
        (r) => (
          id: r['id'] as String,
          title: r['title'] as String,
          level: r['level'] as int,
        ),
      )
      .toList();
  final paragraphs = db
      .select(
        'SELECT id, chapter_id, kind, text FROM paragraphs WHERE book_id = ? ORDER BY ord',
        [bookId],
      )
      .map(
        (r) => (
          id: r['id'] as String,
          chapterId: r['chapter_id'] as String,
          kind: r['kind'] as String,
          text: r['text'] as String,
        ),
      )
      .toList();
  return ReaderBook.fromRows(
    id: bookId,
    title: LocalizedName(
      ar: b['title_ar'] as String,
      en: b['title_en'] as String?,
    ),
    author: LocalizedName(
      ar: b['author_ar'] as String,
      en: b['author_en'] as String?,
    ),
    authorDeathHijri: b['author_death_hijri'] as int?,
    rawChapters: chapters,
    rawParagraphs: paragraphs,
  );
}

/// الموضع المحفوظ لكتاب واحد، أو الأحدث بين الكتب المحمّلة إن كان [bookId] null.
ReadingPosition? readPosition(Database db, {String? bookId}) {
  final rows = db.select(
    'SELECT pos.book_id, pos.paragraph_id, p.ord, p.text, p.chapter_id, c.title AS chapter_title, '
    'c.ord AS chapter_ord, b.title_ar, '
    '(SELECT COUNT(*) FROM paragraphs WHERE book_id = pos.book_id) AS paragraph_count, '
    '(SELECT COUNT(*) FROM chapters WHERE book_id = pos.book_id) AS chapter_count '
    'FROM positions pos '
    'JOIN books b ON b.id = pos.book_id '
    'JOIN paragraphs p ON p.id = pos.paragraph_id AND p.book_id = pos.book_id '
    'JOIN chapters c ON c.id = p.chapter_id '
    '${bookId == null ? '' : 'WHERE pos.book_id = ? '}'
    'ORDER BY pos.updated_at DESC LIMIT 1',
    [?bookId],
  );
  if (rows.isEmpty) return null;
  final r = rows.first;
  // `ord` مرتّب لكن قد لا يبدأ من صفر بعد ترحيل مستقبلي؛ الرقم من الترتيب الفعلي.
  final number =
      db.select(
            'SELECT COUNT(*) AS n FROM paragraphs WHERE book_id = ? AND ord <= ?',
            [r['book_id'], r['ord']],
          ).first['n']
          as int;
  final chapterNumber =
      db.select(
            'SELECT COUNT(*) AS n FROM chapters WHERE book_id = ? AND ord <= ?',
            [r['book_id'], r['chapter_ord']],
          ).first['n']
          as int;
  return ReadingPosition(
    bookId: r['book_id'] as String,
    bookTitle: r['title_ar'] as String,
    paragraphId: r['paragraph_id'] as String,
    paragraphText: r['text'] as String,
    chapterId: r['chapter_id'] as String,
    chapterTitle: r['chapter_title'] as String,
    chapterNumber: chapterNumber,
    chapterCount: r['chapter_count'] as int,
    paragraphNumber: number,
    paragraphCount: r['paragraph_count'] as int,
  );
}

List<FavoriteItem> readFavorites(Database db) => db
    .select(
      'SELECT f.paragraph_id, f.book_id, f.created_at, p.text, c.title AS chapter_title, '
      'b.title_ar FROM favorites f '
      'LEFT JOIN books b ON b.id = f.book_id '
      'LEFT JOIN paragraphs p ON p.id = f.paragraph_id AND b.id IS NOT NULL '
      'LEFT JOIN chapters c ON c.id = p.chapter_id '
      'ORDER BY f.created_at DESC, f.rowid DESC',
    )
    .map(
      (r) => FavoriteItem(
        paragraphId: r['paragraph_id'] as String,
        bookId: r['book_id'] as String,
        createdAt: r['created_at'] as int,
        bookTitle: r['title_ar'] as String?,
        chapterTitle: r['chapter_title'] as String?,
        text: r['text'] as String?,
      ),
    )
    .toList();
