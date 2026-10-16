import 'dart:io';

import 'package:adeeb/library/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixtures.dart';

void main() {
  late Directory dir;
  late FakeLibraryServer server;
  late CatalogRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('adeeb_catalog_');
    server = FakeLibraryServer();
    server.catalog = catalogJson([server.addBook(miniBook())]);
    repo = CatalogRepository(
      client: server.client(),
      baseUri: Uri.parse(testBaseUrl),
      legacyCacheFile: File('${dir.path}/catalog.json'),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Matcher failsWith(CatalogFailure f) => throwsA(
    isA<CatalogFetchException>().having((e) => e.failure, 'failure', f),
  );

  test('يجلب catalog/v2/catalog.json.gz ويفكه، ورابط الكتاب مقسّم', () async {
    final r = await repo.fetch() as CatalogFetched;
    expect(r.catalog.books.single.id, 'mini');
    expect(r.etag, isNotNull);
    expect(
      server.requests.single.toString(),
      '${testBaseUrl}catalog/v2/catalog.json.gz',
    );
    expect(
      repo.bookUrl(r.catalog.books.single).toString(),
      '${testBaseUrl}books/ni/mini/mini.v1.json.gz',
    );
  });

  test('ETag نفسه ← 304 «لم يتغير»، وبعد التغيير فهرس جديد', () async {
    final first = await repo.fetch() as CatalogFetched;
    expect(await repo.fetch(etag: first.etag), isA<CatalogNotModified>());
    server.catalog = catalogJson([], catalogVersion: 2);
    final second = await repo.fetch(etag: first.etag) as CatalogFetched;
    expect(second.catalog.catalogVersion, 2);
  });

  test('دون إنترنت ← network', () async {
    server.offline = true;
    await expectLater(repo.fetch(), failsWith(CatalogFailure.network));
  });

  test('رد 500 أو فهرس تالف ← server', () async {
    server.catalogStatus = 500;
    await expectLater(repo.fetch(), failsWith(CatalogFailure.server));
    server
      ..catalogStatus = 200
      ..catalog = '{"broken"';
    await expectLater(repo.fetch(), failsWith(CatalogFailure.server));
  });

  test('schema أحدث ← unsupportedSchema', () async {
    server.catalog = catalogJson([], schema: 3);
    await expectLater(
      repo.fetch(),
      failsWith(CatalogFailure.unsupportedSchema),
    );
  });

  test('إعداد ناقص ← server بلا طلب', () async {
    final noConfig = CatalogRepository(
      client: server.client(),
      baseUri: null,
      legacyCacheFile: File('${dir.path}/c.json'),
    );
    await expectLater(noConfig.fetch(), failsWith(CatalogFailure.server));
    expect(server.requests, isEmpty);
  });

  test('النسخة القديمة (schema 1) تُقرأ بمسار مقسّم ثم تُحذف', () {
    expect(repo.readLegacyCache(), isNull);
    final book = miniBook(id: 'kalila', version: 2);
    File('${dir.path}/catalog.json').writeAsStringSync(
      catalogJson([legacyCatalogEntry(book, gzJson(book))], schema: 1),
    );
    final legacy = repo.readLegacyCache()!;
    expect(legacy.schema, 1);
    expect(legacy.books.single.file, 'books/la/kalila/kalila.v2.json.gz');
    repo.deleteLegacyCache();
    expect(File('${dir.path}/catalog.json').existsSync(), isFalse);
    expect(repo.readLegacyCache(), isNull);
  });
}
