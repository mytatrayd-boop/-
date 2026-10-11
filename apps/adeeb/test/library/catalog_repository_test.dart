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
      cacheFile: File('${dir.path}/catalog.json'),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Matcher failsWith(CatalogFailure f) =>
      throwsA(isA<CatalogFetchException>().having((e) => e.failure, 'failure', f));

  test('يجلب الفهرس ويحفظ نسخة محلية', () async {
    expect(repo.readCache(), isNull);
    final c = await repo.fetch();
    expect(c.books.single.id, 'mini');
    expect(server.requests.single.toString(), '${testBaseUrl}catalog.json');
    expect(repo.readCache()!.books.single.id, 'mini');
    expect(repo.bookUrl(c.books.single).toString(), '${testBaseUrl}books/mini/mini.v1.json.gz');
  });

  test('فشل حفظ النسخة المحلية لا يُفشل الجلب', () async {
    // الأب ملف عادي، فإنشاء المجلد والكتابة يفشلان بـ FileSystemException.
    final blocker = File('${dir.path}/blocker')..writeAsStringSync('x');
    final unwritable = CatalogRepository(
      client: server.client(),
      baseUri: Uri.parse(testBaseUrl),
      cacheFile: File('${blocker.path}/catalog.json'),
    );
    final c = await unwritable.fetch();
    expect(c.books.single.id, 'mini');
    expect(unwritable.readCache(), isNull);
  });

  test('دون إنترنت ← network، وتبقى النسخة المحفوظة', () async {
    await repo.fetch();
    server.offline = true;
    await expectLater(repo.fetch(), failsWith(CatalogFailure.network));
    expect(repo.readCache(), isNotNull);
  });

  test('رد 500 أو فهرس تالف ← server، ولا يُستبدل المحفوظ بالتالف', () async {
    await repo.fetch();
    server.catalogStatus = 500;
    await expectLater(repo.fetch(), failsWith(CatalogFailure.server));
    server
      ..catalogStatus = 200
      ..catalog = '{"broken"';
    await expectLater(repo.fetch(), failsWith(CatalogFailure.server));
    expect(repo.readCache()!.books.single.id, 'mini');
  });

  test('schema أحدث ← unsupportedSchema', () async {
    server.catalog = catalogJson([], schema: 2);
    await expectLater(repo.fetch(), failsWith(CatalogFailure.unsupportedSchema));
  });

  test('إعداد ناقص ← server بلا طلب', () async {
    final noConfig = CatalogRepository(
      client: server.client(),
      baseUri: null,
      cacheFile: File('${dir.path}/c.json'),
    );
    await expectLater(noConfig.fetch(), failsWith(CatalogFailure.server));
    expect(server.requests, isEmpty);
  });
}
