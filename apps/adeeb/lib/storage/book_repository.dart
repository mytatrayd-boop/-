/// الكتب المحمّلة في SQLite: الاستيراد (في معاملة واحدة)، والحذف، والقراءة.
/// الاستيراد والحذف في Isolate منفصل حتى لا تتجمد الواجهة (ARCHITECTURE §5).
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../library/book_file.dart';
import '../library/catalog.dart';
import 'app_database.dart';

class InstalledBook {
  const InstalledBook({
    required this.id,
    required this.version,
    required this.title,
    required this.author,
    required this.authorDeathHijri,
    required this.sourceName,
    required this.license,
    required this.bytes,
  });

  final String id;
  final int version;
  final LocalizedName title;
  final LocalizedName author;
  final int? authorDeathHijri;
  final String sourceName;
  final String license;

  /// حجم نص الكتاب غير المضغوط (تقدير المساحة التي يحررها الحذف).
  final int bytes;
}

class ChapterInfo {
  const ChapterInfo({required this.id, required this.title, required this.level});
  final String id;
  final String title;
  final int level;
}

abstract interface class BookRepository {
  Future<List<InstalledBook>> installed();

  /// يفك الملف ويتحقق من مطابقته لـ [entry] ثم يستورده بدلاً من أي إصدار
  /// سابق. يرمي [LibraryFormatException] إن كان الملف غير سليم.
  Future<void> install(Uint8List gz, CatalogBook entry);

  Future<void> delete(String bookId);

  Future<List<ChapterInfo>> chapters(String bookId);
}

class SqliteBookRepository implements BookRepository {
  /// [useIsolate] = false للاختبارات التي تعمل بزمن وهمي. [vacuum] قابل
  /// للاستبدال في الاختبار (دالة عليا حتى تُرسل إلى الـ Isolate).
  SqliteBookRepository(this.dbPath, {this.useIsolate = true, this.vacuum = vacuumDatabase});

  final String dbPath;
  final bool useIsolate;
  final void Function(Database db) vacuum;

  /// طابور واحد لعمليات الكتابة (الاستيراد والحذف): لا تتزاحم معاملتان.
  Future<void> _writes = Future.value();

  Future<T> _write<T>(T Function(Database db) body) {
    final result = _writes.then((_) => _run(body));
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<T> _run<T>(T Function(Database db) body) {
    final path = dbPath;
    T task() {
      final db = openAppDatabase(path);
      try {
        return body(db);
      } finally {
        db.close();
      }
    }

    return useIsolate ? Isolate.run(task) : Future.sync(task);
  }

  @override
  Future<List<InstalledBook>> installed() => _run(readInstalled);

  @override
  Future<void> install(Uint8List gz, CatalogBook entry) {
    final meta = _EntryMeta.from(entry);
    return _write((db) => importBook(
          db,
          decodeBookGz(gz, maxUncompressedBytes: meta.uncompressedBytes),
          meta.toEntryCheck(),
          meta.diacritics,
        ));
  }

  /// الحذف نفسه في معاملة؛ وVACUUM بعده اختياري: فشله (مثلاً القاعدة مشغولة)
  /// لا يُفشل الحذف، والمساحة تُستعاد في حذف لاحق.
  @override
  Future<void> delete(String bookId) {
    final compact = vacuum;
    return _write((db) {
      deleteBook(db, bookId);
      try {
        compact(db);
      } on SqliteException {
        // اختياري.
      }
    });
  }

  @override
  Future<List<ChapterInfo>> chapters(String bookId) =>
      _run((db) => readChapters(db, bookId));
}

/// نسخة صغيرة قابلة للإرسال بين الـ Isolates من بيانات الفهرس اللازمة.
class _EntryMeta {
  _EntryMeta(this.id, this.version, this.diacritics, this.uncompressedBytes);
  factory _EntryMeta.from(CatalogBook e) =>
      _EntryMeta(e.id, e.version, e.diacritics, e.uncompressedBytes);
  final String id;
  final int version;
  final String diacritics;
  final int uncompressedBytes;
  ({String id, int version}) toEntryCheck() => (id: id, version: version);
}

List<InstalledBook> readInstalled(Database db) => db
    .select('SELECT * FROM books ORDER BY installed_at, id')
    .map((r) {
      final source = jsonDecode(r['source_json'] as String) as Map<String, Object?>;
      return InstalledBook(
        id: r['id'] as String,
        version: r['version'] as int,
        title: LocalizedName(ar: r['title_ar'] as String, en: r['title_en'] as String?),
        author: LocalizedName(ar: r['author_ar'] as String, en: r['author_en'] as String?),
        authorDeathHijri: r['author_death_hijri'] as int?,
        sourceName: source['name'] as String? ?? '',
        license: r['license'] as String,
        bytes: r['bytes'] as int,
      );
    })
    .toList();

List<ChapterInfo> readChapters(Database db, String bookId) => db
    .select('SELECT id, title, level FROM chapters WHERE book_id = ? ORDER BY ord', [bookId])
    .map((r) => ChapterInfo(
          id: r['id'] as String,
          title: r['title'] as String,
          level: r['level'] as int,
        ))
    .toList();

/// يستورد [book] في معاملة واحدة بعد حذف أي إصدار سابق؛ فشل في المنتصف = لا
/// تغيير. يرفض الملف إن لم يطابق معرّف الكتاب وإصداره في الفهرس.
void importBook(
  Database db,
  BookFile book,
  ({String id, int version}) expected,
  String diacritics, {
  DateTime? now,
}) {
  if (book.id != expected.id || book.version != expected.version) {
    throw LibraryFormatException(
        'الملف (${book.id} v${book.version}) لا يطابق الفهرس (${expected.id} v${expected.version})');
  }
  final bytes = book.chapters.fold<int>(
    0,
    (n, c) => n + c.paragraphs.fold<int>(0, (m, p) => m + utf8.encode(p.text).length),
  );
  db.execute('BEGIN IMMEDIATE');
  try {
    db.execute('DELETE FROM books WHERE id = ?', [book.id]);
    db.execute(
      'INSERT INTO books (id, version, title_ar, title_en, author_ar, author_en, '
      'author_death_hijri, diacritics, source_json, license, installed_at, bytes) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        book.id,
        book.version,
        book.title.ar,
        book.title.en,
        book.author.ar,
        book.author.en,
        book.authorDeathHijri,
        diacritics,
        jsonEncode({'name': book.sourceName, 'url': book.sourceUrl}),
        book.license,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
        bytes,
      ],
    );
    final insertChapter = db.prepare(
        'INSERT INTO chapters (id, book_id, ord, level, title) VALUES (?, ?, ?, ?, ?)');
    final insertParagraph = db.prepare(
        'INSERT INTO paragraphs (id, book_id, chapter_id, ord, kind, text) VALUES (?, ?, ?, ?, ?, ?)');
    final insertRedirect =
        db.prepare('INSERT INTO redirects (old_id, book_id, new_id) VALUES (?, ?, ?)');
    try {
      var paragraphOrd = 0;
      for (var c = 0; c < book.chapters.length; c++) {
        final chapter = book.chapters[c];
        insertChapter.execute([chapter.id, book.id, c, chapter.level, chapter.title]);
        for (final p in chapter.paragraphs) {
          insertParagraph.execute([p.id, book.id, chapter.id, paragraphOrd++, p.kind, p.text]);
        }
      }
      book.redirects.forEach((from, to) => insertRedirect.execute([from, book.id, to]));
    } finally {
      insertChapter.close();
      insertParagraph.close();
      insertRedirect.close();
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void vacuumDatabase(Database db) => db.execute('VACUUM');

void deleteBook(Database db, String bookId) {
  db.execute('BEGIN IMMEDIATE');
  try {
    // الحذف المتسلسل يزيل الأبواب والفقرات والتحويلات.
    db.execute('DELETE FROM books WHERE id = ?', [bookId]);
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
