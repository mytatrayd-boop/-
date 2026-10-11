/// فتح `adeeb.db` وترحيلاته المرقّمة عبر `PRAGMA user_version`
/// (ARCHITECTURE §5). Dart صافٍ.
library;

import 'package:sqlite3/sqlite3.dart';

/// الترحيل رقم i ينقل القاعدة من الإصدار i إلى i+1. لا يُعدَّل ترحيل منشور.
final List<void Function(Database)> migrations = [
  _v1,
];

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
/// فهرس البحث FTS5 والمفضلة والموضع تُضاف بترحيلات لاحقة (الميزتان 3 و4).
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
