/// جلب `catalog.json` من GitHub raw مع مهلة، وحفظ آخر نسخة صالحة محلياً
/// لتُعرض دون إنترنت (ARCHITECTURE §4.1). Dart صافٍ.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/network_errors.dart';
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

class CatalogRepository {
  CatalogRepository({
    required this._client,
    required this._baseUri,
    required this._cacheFile,
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final Uri? _baseUri;
  final File _cacheFile;
  final Duration timeout;

  Uri? bookUrl(CatalogBook book) => _baseUri?.resolve(book.file);

  /// يجلب الفهرس ويحفظه. يرمي [CatalogFetchException].
  Future<Catalog> fetch() async {
    final base = _baseUri;
    if (base == null) {
      throw const CatalogFetchException(CatalogFailure.server, 'LIBRARY_BASE_URL missing');
    }
    final http.Response response;
    try {
      response = await _client.get(base.resolve('catalog.json')).timeout(timeout);
    } catch (e) {
      throw CatalogFetchException(
        isNetworkError(e) ? CatalogFailure.network : CatalogFailure.server,
        e.toString(),
      );
    }
    if (response.statusCode != 200) {
      throw CatalogFetchException(CatalogFailure.server, 'HTTP ${response.statusCode}');
    }
    final text = _decodeUtf8(response.bodyBytes);
    final Catalog catalog;
    try {
      catalog = parseCatalog(text);
    } on UnsupportedSchemaException catch (e) {
      throw CatalogFetchException(CatalogFailure.unsupportedSchema, '$e');
    } on LibraryFormatException catch (e) {
      throw CatalogFetchException(CatalogFailure.server, e.message);
    }
    _writeCache(text);
    return catalog;
  }

  /// آخر فهرس صالح محفوظ، أو null.
  /// الملف صغير (بضعة كيلوبايت) فالقراءة والكتابة متزامنتان عمداً.
  Catalog? readCache() {
    try {
      if (!_cacheFile.existsSync()) return null;
      return parseCatalog(_cacheFile.readAsStringSync());
    } on Exception {
      return null;
    }
  }

  void _writeCache(String text) {
    _cacheFile.parent.createSync(recursive: true);
    final tmp = File('${_cacheFile.path}.tmp');
    tmp.writeAsStringSync(text, flush: true);
    tmp.renameSync(_cacheFile.path);
  }

  static String _decodeUtf8(List<int> bytes) {
    try {
      return const Utf8Decoder().convert(bytes);
    } on FormatException catch (e) {
      throw CatalogFetchException(CatalogFailure.server, 'not UTF-8: ${e.message}');
    }
  }
}
