import 'dart:io';

import 'package:adeeb/library/book_file.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/library/library_controller.dart';
import 'package:adeeb/storage/app_database.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/catalog_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

/// ترحيل مستخدم الإصدار السابق: قاعدة بالإصدار 4 فيها كتاب من الخمسة (المعرّف
/// نفسه في الفهرس الجديد) بموضع ومفضلة، ونسخة `catalog.json` (schema 1).
void main() {
  late TestEnv env;
  late ProviderContainer container;
  late File legacyFile;
  final kalila = miniBook(id: 'kalila', version: 2);
  const position = 'kalila-b001-p00002';
  const favorite = 'kalila-b002-p00001';

  setUp(() {
    env = TestEnv();
    // قاعدة الإصدار السابق (user_version 4) بالكتاب مستورداً من ملف الصيغة 1.
    final db = sqlite3.open('${env.dir.path}/adeeb.db');
    db.execute('PRAGMA foreign_keys = ON');
    for (var i = 0; i < 4; i++) {
      migrations[i](db);
    }
    db.userVersion = 4;
    importBook(db, decodeBookGz(gzJson(kalila)), (
      id: 'kalila',
      version: 2,
    ), 'partial');
    db.execute('INSERT INTO positions VALUES (?, ?, ?)', [
      'kalila',
      position,
      1,
    ]);
    db.execute('INSERT INTO favorites VALUES (?, ?, ?)', [
      favorite,
      'kalila',
      2,
    ]);
    db.close();
    legacyFile = File('${env.dir.path}/catalog.json')
      ..writeAsStringSync(
        catalogJson([legacyCatalogEntry(kalila, gzJson(kalila))], schema: 1),
      );
    // الفهرس الجديد: الكتاب نفسه بإصداره 2 (أعضاء gzip، sha مختلف) وكتاب آلي.
    env.server.catalog = catalogJson([
      env.server.addBook(kalila),
      env.server.addBook(miniBook(id: 'o00113')),
    ]);
  });
  tearDown(() {
    container.dispose();
    env.dispose();
  });

  Future<LibraryState> load() async {
    container = env.container();
    container.read(libraryControllerProvider);
    await container.read(libraryControllerProvider.notifier).refresh();
    return container.read(libraryControllerProvider);
  }

  test('دون إنترنت: الفهرس القديم يُعرض والكتاب محمّل بلا «تحديث»', () async {
    env.server.offline = true;
    final s = await load();
    expect(s.status, CatalogStatus.ready);
    expect(s.notice, CatalogNotice.offline);
    expect(s.items.single.id, 'kalila');
    expect(s.items.single.status, BookStatus.installed);
    expect(s.items.single.title.en, 'Synthetic Test Book');
    // الترحيل 5 جرى ولم يمسّ الكتاب ولا الموضع ولا المفضلة.
    final db = openAppDatabase('${env.dir.path}/adeeb.db');
    addTearDown(db.close);
    expect(db.userVersion, schemaVersion);
    expect((await env.reading.position('kalila'))!.paragraphId, position);
    expect((await env.reading.favorites()).single.paragraphId, favorite);
    // النسخة القديمة تبقى حتى يصل فهرس schema 2.
    expect(legacyFile.existsSync(), isTrue);
    expect(
      await env.catalogStore.query(const CatalogQuery(), offset: 0, limit: 50),
      ['kalila'],
    );
  });

  test('مع الاتصال: فهرس schema 2 يحل محله، والكتب الخمسة بمواضعها', () async {
    final s = await load();
    expect(s.notice, CatalogNotice.none);
    expect(s.items.map((i) => i.id), ['kalila', 'o00113']);
    final k = s.item('kalila')!;
    expect(k.status, BookStatus.installed);
    expect(k.entry!.file, 'books/la/kalila/kalila.v2.json.gz');
    expect(k.entry!.category, 'adab');
    expect(s.item('o00113')!.status, BookStatus.notInstalled);
    expect(legacyFile.existsSync(), isFalse);
    expect((await env.catalogStore.load())!.catalog.schema, 2);
    expect((await env.reading.position('kalila'))!.paragraphId, position);
    expect((await env.reading.favorites()).single.paragraphId, favorite);

    // تحميل كتاب آلي بالمسار المقسّم والفك متعدد الأعضاء وsha256.
    expect(
      await container
          .read(libraryControllerProvider.notifier)
          .download('o00113'),
      DownloadOutcome.installed,
    );
    expect(
      env.server.requests.last.toString(),
      '${testBaseUrl}books/13/o00113/o00113.v1.json.gz',
    );
    final installed = await env.books.installed();
    expect(installed.map((b) => b.id), containsAll(['kalila', 'o00113']));
    // إعادة تحميل الكتاب القديم (الصيغة 2) تُبقي موضعه ومفضلته.
    expect(
      await container
          .read(libraryControllerProvider.notifier)
          .download('kalila'),
      DownloadOutcome.updated,
    );
    expect((await env.reading.position('kalila'))!.paragraphId, position);
    expect((await env.reading.favorites()).single.paragraphId, favorite);
  });

  test('فتح المكتبة خلال 6 ساعات لا يعيد الجلب، وبعدها جلب شرطي 304', () async {
    int fetches() => env.server.requests
        .where((u) => u.path.endsWith('catalog.json.gz'))
        .length;

    /// فتح المكتبة كما في التطبيق (جلب غير إجباري من build).
    Future<LibraryState> open() async {
      container = env.container();
      container.read(libraryControllerProvider);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return container.read(libraryControllerProvider);
    }

    var s = await open();
    expect(fetches(), 1);
    expect(s.items, hasLength(2));
    container.dispose();

    // بعد ساعة: من SQLite بلا طلب.
    env.now = env.now.add(const Duration(hours: 1));
    s = await open();
    expect(s.status, CatalogStatus.ready);
    expect(s.items, hasLength(2));
    expect(fetches(), 1);
    container.dispose();

    // بعد 7 ساعات: طلب بـ If-None-Match ورد 304، والفهرس كما هو.
    env.now = env.now.add(const Duration(hours: 7));
    s = await open();
    expect(fetches(), 2);
    expect(s.notice, CatalogNotice.none);
    expect(s.items, hasLength(2));
    expect(
      (await env.catalogStore.load())!.fetchedAt,
      env.now.millisecondsSinceEpoch,
    );
  });

  test('فهرس schema 2 بلا كتب محلية ولا نسخة قديمة: يُستورد مباشرة', () async {
    legacyFile.deleteSync();
    final s = await load();
    expect(s.items.map((i) => i.id), ['kalila', 'o00113']);
    expect(
      parseCatalog(catalogJson([catalogEntry(kalila, gzV2(kalila))]))
          .books
          .single
          .sha256,
      s.item('kalila')!.entry!.sha256,
    );
  });
}
