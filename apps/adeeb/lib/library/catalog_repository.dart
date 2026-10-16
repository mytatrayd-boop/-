/// جلب فهرس schema 2 من GitHub raw مع مهلة و`ETag` (ARCHITECTURE §18.5).
/// آخر نسخة صالحة تُحفظ في SQLite (catalog_store.dart) لتُعرض دون إنترنت.
/// Dart صافٍ.
library;

import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/network_errors.dart';
import 'book_file.dart';
import 'catalog.dart';

enum CatalogFailure {
  /// لا اتصال.
  network,

  /// رد غير 200، أو فهرس تالف، أو إعداد ناقص.
  server,

  /// `schema` أحدث مما يفهمه التطبيق.
  unsupportedSchema,
}

class CatalogFetchException implements Exception {
  const CatalogFetchException(this.failure, [this.detail]);
  final CatalogFailure failure;
  final String? detail;
  @override
  String toString() => 'CatalogFetchException(${failure.name}: $detail)';
}

/// نتيجة الجلب: فهرس جديد مع `ETag`، أو «لم يتغير» (HTTP 304).
sealed class CatalogFetchResult {
  const CatalogFetchResult();
}

class CatalogFetched extends CatalogFetchResult {
  const CatalogFetched(this.catalog, this.etag);
  final Catalog catalog;
  final String? etag;
}

class CatalogNotModified extends CatalogFetchResult {
  const CatalogNotModified();
}

/// أقصى حجم للفهرس بعد الفك (نحو 0.5 م.ب متوقعاً لـ 1,400 كتاب، §18.5).
const maxCatalogBytes = 16 * 1024 * 1024;

class CatalogRepository {
  CatalogRepository({
    required this._client,
    required this._baseUri,
    required this._legacyCacheFile,
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final Uri? _baseUri;

  /// نسخة `catalog.json` (schema 1) التي حفظتها الإصدارات السابقة؛ تُقرأ مرة
  /// للترحيل ثم تُحذف بعد أول استيراد لفهرس schema 2.
  final File _legacyCacheFile;
  final Duration timeout;

  Uri? bookUrl(CatalogBook book) => _baseUri?.resolve(book.file);

  /// يجلب `catalog/v2/catalog.json.gz`؛ مع [etag] يرسل `If-None-Match`.
  /// يرمي [CatalogFetchException].
  Future<CatalogFetchResult> fetch({String? etag}) async {
    final base = _baseUri;
    if (base == null) {
      throw const CatalogFetchException(
        CatalogFailure.server,
        'LIBRARY_BASE_URL missing',
      );
    }
    final http.Response response;
    try {
      response = await _client
          .get(base.resolve(catalogV2Path), headers: {'If-None-Match': ?etag})
          .timeout(timeout);
    } catch (e) {
      throw CatalogFetchException(
        isNetworkError(e) ? CatalogFailure.network : CatalogFailure.server,
        e.toString(),
      );
    }
    if (response.statusCode == 304 && etag != null) {
      return const CatalogNotModified();
    }
    if (response.statusCode != 200) {
      throw CatalogFetchException(
        CatalogFailure.server,
        'HTTP ${response.statusCode}',
      );
    }
    try {
      final text = gunzipUtf8(response.bodyBytes, maxBytes: maxCatalogBytes);
      return CatalogFetched(parseCatalog(text), response.headers['etag']);
    } on UnsupportedSchemaException catch (e) {
      throw CatalogFetchException(CatalogFailure.unsupportedSchema, '$e');
    } on LibraryFormatException catch (e) {
      throw CatalogFetchException(CatalogFailure.server, e.message);
    }
  }

  /// الفهرس القديم المحفوظ (schema 1) بمسارات مقسّمة، أو null. الملف صغير
  /// (بضعة كيلوبايت) فالقراءة متزامنة عمداً.
  Catalog? readLegacyCache() {
    try {
      if (!_legacyCacheFile.existsSync()) return null;
      final old = parseCatalog(_legacyCacheFile.readAsStringSync());
      if (old.schema != 1) return null;
      return Catalog(
        schema: 1,
        catalogVersion: old.catalogVersion,
        updated: old.updated,
        books: [
          for (final b in old.books)
            CatalogBook(
              id: b.id,
              title: b.title,
              author: b.author,
              authorDeathHijri: b.authorDeathHijri,
              version: b.version,
              file: shardedBookPath(b.id, b.version),
              sha256: b.sha256,
              sizeBytes: b.sizeBytes,
              uncompressedBytes: b.uncompressedBytes,
              paragraphCount: b.paragraphCount,
              diacritics: b.diacritics,
              sourceName: b.sourceName,
              sourceUrl: b.sourceUrl,
              license: b.license,
            ),
        ],
      );
    } on Exception {
      return null;
    }
  }

  void deleteLegacyCache() {
    try {
      if (_legacyCacheFile.existsSync()) _legacyCacheFile.deleteSync();
    } on FileSystemException {
      // يُعاد في الاستيراد التالي.
    }
  }
}
