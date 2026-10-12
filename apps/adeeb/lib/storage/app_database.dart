/// فتح `adeeb.db` وترحيلاته المرقّمة عبر `PRAGMA user_version`
/// (ARCHITECTURE §5). Dart صافٍ.
library;

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'search_index.dart';
import 'write_queue.dart';

/// الترحيل رقم i ينقل القاعدة من الإصدار i إلى i+1. لا يُعدَّل ترحيل منشور.
final List<void Function(Database)> migrations = [_v1, _v2, _v3, _v4];

int get schemaVersion => migrations.length;

Database openAppDatabase(String path) {
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000');
    migrate(db);
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

final _ready = <String, Future<void>>{};

/// يفتح القاعدة مرة في كل تشغيل عبر طابور الكتابة فتجري الترحيلات (ومنها
/// فهرسة الكتب المثبّتة في الترحيل 3) ككاتب واحد لا يتزاحم مع الاستيراد أو
/// حفظ الموضع. على كل مستودع انتظاره قبل أي فتح، ولا يُستدعى من داخل مهمة
/// في الطابور نفسه (ينتظر نفسه). الفشل لا يُخزَّن فيُعاد في الطلب التالي.
Future<void> ensureDatabaseReady(String path, {bool useIsolate = true}) {
  final existing = _ready[path];
  if (existing != null) return existing;
  final ready = enqueueWrite(path, () => _openOnce(path, useIsolate));
  _ready[path] = ready;
  ready.then<void>(
    (_) {},
    onError: (Object _) {
      if (identical(_ready[path], ready)) _ready.remove(path);
    },
  );
  return ready;
}

/// في دالة مستقلة حتى لا يحمل إغلاق الـ Isolate متغيرات غير قابلة للإرسال.
Future<void> _openOnce(String path, bool useIsolate) {
  void task() => openAppDatabase(path).close();
  return useIsolate ? Isolate.run(task) : Future.sync(task);
}

void migrate(Database db) {
  db.execute('PRAGMA foreign_keys = ON');
  var version = db.userVersion;
  if (version > migrations.length) {
    throw StateError('قاعدة البيانات أحدث من التطبيق ($version)');
  }
  while (version < migrations.length) {
    db.execute('BEGIN IMMEDIATE');
    try {
      migrations[version](db);
      db.userVersion = version + 1;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    version++;
  }
}

/// الإصدار 1 (الميزة 2): الكتب وأبوابها وفقراتها وتحويلات المعرّفات.
void _v1(Database db) {
  db.execute('''
    CREATE TABLE books (
      id TEXT PRIMARY KEY,
      version INTEGER NOT NULL,
      title_ar TEXT NOT NULL,
      title_en TEXT,
      author_ar TEXT NOT NULL,
      author_en TEXT,
      author_death_hijri INTEGER,
      diacritics TEXT NOT NULL,
      source_json TEXT NOT NULL,
      license TEXT NOT NULL,
      installed_at INTEGER NOT NULL,
      bytes INTEGER NOT NULL
    )''');
  db.execute('''
    CREATE TABLE chapters (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      ord INTEGER NOT NULL,
      level INTEGER NOT NULL,
      title TEXT NOT NULL
    )''');
  db.execute('CREATE INDEX chapters_book ON chapters(book_id, ord)');
  db.execute('''
    CREATE TABLE paragraphs (
      rowid INTEGER PRIMARY KEY,
      id TEXT NOT NULL UNIQUE,
      book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      chapter_id TEXT NOT NULL,
      ord INTEGER NOT NULL,
      kind TEXT NOT NULL,
      text TEXT NOT NULL
    )''');
  db.execute('CREATE INDEX paragraphs_book ON paragraphs(book_id, ord)');
  db.execute('''
    CREATE TABLE redirects (
      old_id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      new_id TEXT NOT NULL
    )''');
}

/// الإصدار 2 (الميزة 3): المفضلة وآخر موضع قراءة. بلا مفتاح أجنبي إلى
/// `books` أو `paragraphs` عمداً (D18): حذف الكتاب أو تحديثه لا يمسّهما،
/// وبعد التحديث تُنقل معرّفاتهما عبر `redirects`.
void _v2(Database db) {
  db.execute('''
    CREATE TABLE favorites (
      paragraph_id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )''');
  db.execute('CREATE INDEX favorites_recent ON favorites(created_at)');
  db.execute('''
    CREATE TABLE positions (
      book_id TEXT PRIMARY KEY,
      paragraph_id TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
}

/// الإصدار 3 (الميزة 4): فهرس البحث FTS5، وفهرسة الكتب المثبّتة سابقاً
/// داخل معاملة الترحيل نفسها.
void _v3(Database db) {
  db.execute(createSearchIndexSql);
  indexAllParagraphs(db);
}

/// الإصدار 4 (إصلاح مراجعة الميزة 4): الجذع الخفيف صار لا يحذف «و/ف» المفردتين
/// إلا إن بقي 4 أحرف، فتُعاد فهرسة كل الفقرات بالجذوع الجديدة حتى لا تبقى
/// جذوع قديمة («فكرة» ← «كره») في الكتب المثبّتة.
void _v4(Database db) {
  db.execute("INSERT INTO paragraphs_fts (paragraphs_fts) VALUES ('delete-all')");
  indexAllParagraphs(db);
}
