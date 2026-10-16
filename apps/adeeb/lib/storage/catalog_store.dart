/// الفهرس الكبير في SQLite (ARCHITECTURE §18.5): جدول `catalog_books` وفهرس
/// FTS5 على العنوان والمؤلف المطبَّعين، والبحث والتصفية والترتيب بصفحات
/// `LIMIT/OFFSET`. يُستبدل كله في معاملة واحدة عند كل فهرس جديد. Dart صافٍ.
library;

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../library/catalog.dart';
import '../text/arabic_normalizer.dart';
import '../text/light_stemmer.dart';
import 'app_database.dart';
import 'write_queue.dart';

void createCatalogTables(Database db) {
  db.execute('''
    CREATE TABLE catalog_books (
      rowid INTEGER PRIMARY KEY,
      id TEXT NOT NULL UNIQUE,
      title_ar TEXT NOT NULL,
      title_en TEXT,
      author_ar TEXT NOT NULL,
      author_en TEXT,
      death INTEGER,
      category TEXT,
      era TEXT,
      version INTEGER NOT NULL,
      file TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      uncompressed_bytes INTEGER NOT NULL,
      paragraph_count INTEGER NOT NULL,
      diacritics TEXT NOT NULL,
      source_name TEXT NOT NULL,
      source_url TEXT NOT NULL,
      license TEXT NOT NULL,
      title_norm TEXT NOT NULL
    )''');
  db.execute(
    'CREATE INDEX catalog_books_filter ON catalog_books(category, era)',
  );
  // نصّ صغير (عنوان ومؤلف) فيُخزَّن مع الفهرس، لا جدول بلا محتوى.
  db.execute(
    'CREATE VIRTUAL TABLE catalog_fts USING fts5('
    "text, tokenize='unicode61 remove_diacritics 0')",
  );
  db.execute('CREATE TABLE catalog_meta (key TEXT PRIMARY KEY, value)');
}

enum CatalogSort {
  /// سنة الوفاة تصاعدياً (الافتراضي).
  death,
  title,

  /// الأصغر أولاً.
  size,
}

/// استعلام شاشة المكتبة: نص البحث والتصنيف والعصر (null = الكل) والترتيب.
class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.category,
    this.era,
    this.sort = CatalogSort.death,
  });

  final String text;
  final String? category;
  final String? era;
  final CatalogSort sort;

  CatalogQuery copyWith({
    String? text,
    String? Function()? category,
    String? Function()? era,
    CatalogSort? sort,
  }) => CatalogQuery(
    text: text ?? this.text,
    category: category == null ? this.category : category(),
    era: era == null ? this.era : era(),
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery &&
      other.text == text &&
      other.category == category &&
      other.era == era &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(text, category, era, sort);
}

/// الفهرس المحفوظ مع بياناته: [etag] و[fetchedAt] (ميلي ثانية) لتقليل الجلب.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.catalog,
    required this.etag,
    required this.fetchedAt,
  });
  final Catalog catalog;
  final String? etag;
  final int fetchedAt;
}

abstract interface class CatalogStore {
  /// آخر فهرس مستورد، أو null إن لم يُستورد شيء بعد.
  Future<CatalogSnapshot?> load();

  /// يستبدل الفهرس كله في معاملة واحدة.
  Future<void> replace(Catalog catalog, {String? etag, required int fetchedAt});

  /// «لم يتغير» (304): يُحدَّث وقت الجلب فقط.
  Future<void> touch(int fetchedAt);

  /// معرّفات صفحة من النتائج بترتيب [query].
  Future<List<String>> query(
    CatalogQuery query, {
    required int offset,
    required int limit,
  });
}

class SqliteCatalogStore implements CatalogStore {
  SqliteCatalogStore(this.dbPath, {this.useIsolate = true});

  final String dbPath;
  final bool useIsolate;

  Future<T> _exec<T>(T Function(Database db) body) {
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

  Future<T> _run<T>(T Function(Database db) body) async {
    await ensureDatabaseReady(dbPath, useIsolate: useIsolate);
    return _exec(body);
  }

  Future<T> _write<T>(T Function(Database db) body) async {
    await ensureDatabaseReady(dbPath, useIsolate: useIsolate);
    return enqueueWrite(dbPath, () => _exec(body));
  }

  @override
  Future<CatalogSnapshot?> load() => _run(readCatalogSnapshot);

  @override
  Future<void> replace(
    Catalog catalog, {
    String? etag,
    required int fetchedAt,
  }) => _write(
    (db) => replaceCatalog(db, catalog, etag: etag, fetchedAt: fetchedAt),
  );

  @override
  Future<void> touch(int fetchedAt) =>
      _write((db) => _setMeta(db, {'fetched_at': fetchedAt}));

  @override
  Future<List<String>> query(
    CatalogQuery query, {
    required int offset,
    required int limit,
  }) => _run((db) => queryCatalogIds(db, query, offset: offset, limit: limit));
}

void _setMeta(Database db, Map<String, Object?> values) {
  final stmt = db.prepare(
    'INSERT OR REPLACE INTO catalog_meta (key, value) VALUES (?, ?)',
  );
  try {
    values.forEach((k, v) => stmt.execute([k, v]));
  } finally {
    stmt.close();
  }
}

/// نص الفهرسة: العنوان والمؤلف (والنقل اللاتيني إن وُجد) مطبَّعين ثم جذوعهما،
/// فيطابق «بخلاء» عنوان «البخلاء».
String catalogSearchText(CatalogBook b) {
  final norm = normalizeArabic(
    [b.title.ar, b.author.ar, ?b.title.en, ?b.author.en].join(' '),
  );
  return '$norm ${stemNormalized(norm)}';
}

void replaceCatalog(
  Database db,
  Catalog catalog, {
  String? etag,
  required int fetchedAt,
}) {
  db.execute('BEGIN IMMEDIATE');
  try {
    db.execute('DELETE FROM catalog_books');
    db.execute('DELETE FROM catalog_fts');
    final insert = db.prepare(
      'INSERT INTO catalog_books (id, title_ar, title_en, author_ar, author_en, '
      'death, category, era, version, file, sha256, size_bytes, '
      'uncompressed_bytes, paragraph_count, diacritics, source_name, '
      'source_url, license, title_norm) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    final index = db.prepare(
      'INSERT INTO catalog_fts (rowid, text) VALUES (?, ?)',
    );
    try {
      for (final b in catalog.books) {
        insert.execute([
          b.id,
          b.title.ar,
          b.title.en,
          b.author.ar,
          b.author.en,
          b.authorDeathHijri,
          b.category,
          b.era,
          b.version,
          b.file,
          b.sha256,
          b.sizeBytes,
          b.uncompressedBytes,
          b.paragraphCount,
          b.diacritics,
          b.sourceName,
          b.sourceUrl,
          b.license,
          normalizeArabic(b.title.ar),
        ]);
        index.execute([db.lastInsertRowId, catalogSearchText(b)]);
      }
    } finally {
      insert.close();
      index.close();
    }
    db.execute('DELETE FROM catalog_meta');
    _setMeta(db, {
      'schema': catalog.schema,
      'catalog_version': catalog.catalogVersion,
      'updated': catalog.updated,
      'etag': etag,
      'fetched_at': fetchedAt,
    });
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

CatalogSnapshot? readCatalogSnapshot(Database db) {
  final meta = {
    for (final r in db.select('SELECT key, value FROM catalog_meta'))
      r['key'] as String: r['value'],
  };
  if (meta['schema'] is! int) return null;
  final books = db
      .select('SELECT * FROM catalog_books ORDER BY rowid')
      .map(
        (r) => CatalogBook(
          id: r['id'] as String,
          title: LocalizedName(
            ar: r['title_ar'] as String,
            en: r['title_en'] as String?,
          ),
          author: LocalizedName(
            ar: r['author_ar'] as String,
            en: r['author_en'] as String?,
          ),
          authorDeathHijri: r['death'] as int?,
          version: r['version'] as int,
          file: r['file'] as String,
          sha256: r['sha256'] as String,
          sizeBytes: r['size_bytes'] as int,
          uncompressedBytes: r['uncompressed_bytes'] as int,
          paragraphCount: r['paragraph_count'] as int,
          diacritics: r['diacritics'] as String,
          sourceName: r['source_name'] as String,
          sourceUrl: r['source_url'] as String,
          license: r['license'] as String,
          category: r['category'] as String?,
          era: r['era'] as String?,
        ),
      )
      .toList();
  return CatalogSnapshot(
    catalog: Catalog(
      schema: meta['schema']! as int,
      catalogVersion: meta['catalog_version'] as int? ?? 0,
      updated: meta['updated'] as String? ?? '',
      books: List.unmodifiable(books),
    ),
    etag: meta['etag'] as String?,
    fetchedAt: meta['fetched_at'] as int? ?? 0,
  );
}

/// تعبير FTS5 لنص البحث: كل كلمة مطبَّعة بادئةً لكلمة أو لجذعها، والكلمات
/// كلها مطلوبة. null إن لم يبقَ شيء بعد التطبيع.
String? catalogMatchExpression(String text) {
  final words = normalizeArabic(text)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  // بعد التطبيع لا يبقى إلا حروف وأرقام، فالتنصيص آمن.
  return words
      .map((w) {
        final stem = lightStem(w);
        return stem == w ? '"$w"*' : '("$w"* OR "$stem"*)';
      })
      .join(' AND ');
}

List<String> queryCatalogIds(
  Database db,
  CatalogQuery q, {
  required int offset,
  required int limit,
}) {
  final where = <String>[];
  final args = <Object?>[];
  final match = catalogMatchExpression(q.text);
  if (match != null) {
    where.add(
      'rowid IN (SELECT rowid FROM catalog_fts WHERE catalog_fts MATCH ?)',
    );
    args.add(match);
  }
  if (q.category != null) {
    where.add('category = ?');
    args.add(q.category);
  }
  if (q.era != null) {
    where.add('era = ?');
    args.add(q.era);
  }
  final order = switch (q.sort) {
    CatalogSort.death => 'death IS NULL, death, title_norm, id',
    CatalogSort.title => 'title_norm, id',
    CatalogSort.size => 'size_bytes, id',
  };
  final sql =
      'SELECT id FROM catalog_books'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
      ' ORDER BY $order LIMIT ? OFFSET ?';
  return db
      .select(sql, [...args, limit, offset])
      .map((r) => r['id'] as String)
      .toList();
}
