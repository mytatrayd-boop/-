/// نماذج الفهرس `catalog.json` (ARCHITECTURE §4.1) وتحليله. Dart صافٍ.
library;

import 'dart:convert';

/// أعلى `schema` يفهمه هذا الإصدار من التطبيق.
const supportedSchema = 1;

final bookIdPattern = RegExp(r'^[a-z]{2,12}$');
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

/// الفهرس أو الكتاب بصيغة لا يفهمها التطبيق أو تالف.
class LibraryFormatException implements Exception {
  const LibraryFormatException(this.message);
  final String message;
  @override
  String toString() => 'LibraryFormatException: $message';
}

/// `schema` أحدث مما يفهمه التطبيق: «حدّث التطبيق».
class UnsupportedSchemaException implements Exception {
  const UnsupportedSchemaException(this.schema);
  final int schema;
  @override
  String toString() => 'UnsupportedSchemaException: $schema';
}

class LocalizedName {
  const LocalizedName({required this.ar, this.en});
  final String ar;
  final String? en;

  Map<String, Object?> toJson() => {'ar': ar, 'en': en};
}

class CatalogBook {
  const CatalogBook({
    required this.id,
    required this.title,
    required this.author,
    required this.authorDeathHijri,
    required this.version,
    required this.file,
    required this.sha256,
    required this.sizeBytes,
    required this.uncompressedBytes,
    required this.paragraphCount,
    required this.diacritics,
    required this.sourceName,
    required this.sourceUrl,
    required this.license,
  });

  final String id;
  final LocalizedName title;
  final LocalizedName author;
  final int? authorDeathHijri;
  final int version;

  /// مسار نسبي داخل `library/`: `books/<id>/<id>.v<N>.json.gz`.
  final String file;
  final String sha256;
  final int sizeBytes;
  final int uncompressedBytes;
  final int paragraphCount;
  final String diacritics;
  final String sourceName;
  final String sourceUrl;
  final String license;
}

class Catalog {
  const Catalog({
    required this.schema,
    required this.catalogVersion,
    required this.updated,
    required this.books,
  });

  final int schema;
  final int catalogVersion;
  final String updated;
  final List<CatalogBook> books;

  CatalogBook? byId(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }
}

T _field<T>(Map<String, Object?> map, String key, String where) {
  final value = map[key];
  if (value is T) return value;
  throw LibraryFormatException('$where: الحقل "$key" مفقود أو بنوع خاطئ');
}

LocalizedName parseLocalizedName(Object? value, String where) {
  if (value is! Map<String, Object?>) {
    throw LibraryFormatException('$where: اسم غير صالح');
  }
  final ar = value['ar'];
  final en = value['en'];
  if (ar is! String || ar.trim().isEmpty || (en != null && en is! String)) {
    throw LibraryFormatException('$where: اسم عربي مفقود');
  }
  return LocalizedName(ar: ar, en: en as String?);
}

/// يحلل نص `catalog.json`. يرمي [UnsupportedSchemaException] إن كان
/// `schema` أحدث، و[LibraryFormatException] لأي خلل.
Catalog parseCatalog(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw LibraryFormatException('JSON غير صالح: ${e.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw const LibraryFormatException('الفهرس ليس كائن JSON');
  }
  final schema = _field<int>(decoded, 'schema', 'catalog');
  if (schema > supportedSchema) throw UnsupportedSchemaException(schema);
  if (schema < 1) throw const LibraryFormatException('schema غير صالح');
  final rawBooks = _field<List<Object?>>(decoded, 'books', 'catalog');
  final seen = <String>{};
  final books = <CatalogBook>[];
  for (final raw in rawBooks) {
    if (raw is! Map<String, Object?>) {
      throw const LibraryFormatException('عنصر كتاب غير صالح');
    }
    final book = _parseBook(raw);
    if (!seen.add(book.id)) {
      throw LibraryFormatException('معرّف مكرر: ${book.id}');
    }
    books.add(book);
  }
  return Catalog(
    schema: schema,
    catalogVersion: _field<int>(decoded, 'catalog_version', 'catalog'),
    updated: _field<String>(decoded, 'updated', 'catalog'),
    books: List.unmodifiable(books),
  );
}

CatalogBook _parseBook(Map<String, Object?> m) {
  final id = _field<String>(m, 'id', 'book');
  if (!bookIdPattern.hasMatch(id)) {
    throw LibraryFormatException('معرّف كتاب غير صالح: $id');
  }
  final where = 'book $id';
  final version = _field<int>(m, 'version', where);
  final file = _field<String>(m, 'file', where);
  // المسار ثابت الصيغة: يمنع أي مسار خارج مجلد الكتاب أو رابط خارجي.
  if (version < 1 || file != 'books/$id/$id.v$version.json.gz') {
    throw LibraryFormatException('$where: مسار الملف غير مطابق للإصدار');
  }
  final sha = _field<String>(m, 'sha256', where);
  if (!_sha256Pattern.hasMatch(sha)) {
    throw LibraryFormatException('$where: sha256 غير صالح');
  }
  final size = _field<int>(m, 'size_bytes', where);
  final uncompressed = _field<int>(m, 'uncompressed_bytes', where);
  if (size <= 0 || uncompressed <= 0) {
    throw LibraryFormatException('$where: حجم غير صالح');
  }
  final source = _field<Map<String, Object?>>(m, 'source', where);
  final death = m['author_death_hijri'];
  if (death != null && death is! int) {
    throw LibraryFormatException('$where: سنة الوفاة غير صالحة');
  }
  return CatalogBook(
    id: id,
    title: parseLocalizedName(m['title'], '$where title'),
    author: parseLocalizedName(m['author'], '$where author'),
    authorDeathHijri: death as int?,
    version: version,
    file: file,
    sha256: sha,
    sizeBytes: size,
    uncompressedBytes: uncompressed,
    paragraphCount: _field<int>(m, 'paragraph_count', where),
    diacritics: _field<String>(m, 'diacritics', where),
    sourceName: _field<String>(source, 'name', '$where source'),
    sourceUrl: _field<String>(source, 'url', '$where source'),
    license: _field<String>(m, 'license', where),
  );
}
