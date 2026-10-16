import 'dart:io';

import 'package:adeeb/library/book_file.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/storage/app_database.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/library_fixtures.dart';

/// VACUUM فاشل فعلاً (مخطط غير موجود) لاختبار أن الحذف لا يفشل بسببه.
void failingVacuum(Database db) => db.execute('VACUUM no_such_schema');

CatalogBook entryFor(Map<String, Object?> book) =>
    parseCatalog(catalogJson([catalogEntry(book, gzJson(book))])).books.single;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('adeeb_db_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('الترحيلات تضبط user_version وتنشئ الجداول', () {
    final db = openAppDatabase('${dir.path}/a.db');
    addTearDown(db.close);
    expect(db.userVersion, schemaVersion);
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r['name'])
        .toSet();
    expect(
      tables,
      containsAll(['books', 'chapters', 'paragraphs', 'redirects']),
    );
    // فتح ثانٍ لا يعيد الترحيل.
    migrate(db);
    expect(db.userVersion, schemaVersion);
  });

  test('قاعدة أحدث من التطبيق ترمي خطأ', () {
    final db = sqlite3.open('${dir.path}/b.db')..userVersion = 99;
    addTearDown(db.close);
    expect(() => migrate(db), throwsStateError);
  });

  for (final useIsolate in [false, true]) {
    group(useIsolate ? 'في Isolate' : 'في الـ isolate نفسه', () {
      late SqliteBookRepository repo;
      setUp(
        () => repo = SqliteBookRepository(
          '${dir.path}/adeeb.db',
          useIsolate: useIsolate,
        ),
      );

      test('استيراد ثم قراءة الأبواب والفقرات كاملة', () async {
        final book = miniBook();
        await repo.install(gzJson(book), entryFor(book));
        final installed = await repo.installed();
        expect(installed.single.id, 'mini');
        expect(installed.single.version, 1);
        expect(installed.single.title.ar, 'كتاب اختبار اصطناعي');
        expect(installed.single.bytes, greaterThan(0));
        final chapters = await repo.chapters('mini');
        expect(chapters.map((c) => c.title), [
          'الباب الأول: فقرات اختبار',
          'فصل اختبار فرعي',
        ]);
        expect(chapters.map((c) => c.level), [1, 2]);

        final db = openAppDatabase(repo.dbPath);
        addTearDown(db.close);
        final paras = db.select(
          'SELECT id, kind, text FROM paragraphs ORDER BY ord',
        );
        expect(paras.map((r) => r['id']), [
          'mini-b001-p00001',
          'mini-b001-p00002',
          'mini-b002-p00001',
        ]);
        expect(paras.last['kind'], 'verse');
        expect(paras[1]['text'], contains('الحِكْمَةُ'));
      });

      test('التحديث يستبدل الإصدار القديم ويحفظ redirects', () async {
        final v1 = miniBook();
        await repo.install(gzJson(v1), entryFor(v1));
        final v2 = miniBook(version: 2)
          ..['redirects'] = {'mini-b001-p00009': 'mini-b001-p00001'};
        ((v2['chapters']! as List).first as Map)['title'] =
            'الباب الأول (إصدار ٢)';
        await repo.install(gzJson(v2), entryFor(v2));
        expect((await repo.installed()).single.version, 2);
        expect(
          (await repo.chapters('mini')).first.title,
          'الباب الأول (إصدار ٢)',
        );
        final db = openAppDatabase(repo.dbPath);
        addTearDown(db.close);
        expect(
          db.select('SELECT COUNT(*) AS n FROM paragraphs').single['n'],
          3,
        );
        expect(
          db.select('SELECT new_id FROM redirects').single['new_id'],
          'mini-b001-p00001',
        );
      });

      test('ملف لا يطابق الفهرس يُرفض ولا يغيّر شيئاً', () async {
        final v1 = miniBook();
        await repo.install(gzJson(v1), entryFor(v1));
        final wrong = miniBook(version: 3);
        await expectLater(
          repo.install(gzJson(wrong), entryFor(miniBook(version: 2))),
          throwsA(isA<LibraryFormatException>()),
        );
        expect((await repo.installed()).single.version, 1);
      });

      test('الحذف يزيل الكتاب وأبوابه وفقراته', () async {
        final book = miniBook();
        final other = miniBook(id: 'other');
        await repo.install(gzJson(book), entryFor(book));
        await repo.install(gzJson(other), entryFor(other));
        await repo.delete('mini');
        expect((await repo.installed()).map((b) => b.id), ['other']);
        expect(await repo.chapters('mini'), isEmpty);
        final db = openAppDatabase(repo.dbPath);
        addTearDown(db.close);
        expect(
          db
              .select(
                "SELECT COUNT(*) AS n FROM paragraphs WHERE book_id = 'mini'",
              )
              .single['n'],
          0,
        );
        expect(
          db
              .select(
                "SELECT COUNT(*) AS n FROM paragraphs WHERE book_id = 'other'",
              )
              .single['n'],
          3,
        );
      });
    });
  }

  for (final useIsolate in [false, true]) {
    test('فشل VACUUM لا يُفشل الحذف (isolate=$useIsolate)', () async {
      final repo = SqliteBookRepository(
        '${dir.path}/v.db',
        useIsolate: useIsolate,
        vacuum: failingVacuum,
      );
      final book = miniBook();
      await repo.install(gzJson(book), entryFor(book));
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      expect(() => failingVacuum(db), throwsA(isA<SqliteException>()));
      await repo.delete('mini');
      expect(await repo.installed(), isEmpty);
    });
  }

  test('طابور الكتابة: استيراد وحذف متزامنان يُنفَّذان بالترتيب', () async {
    final repo = SqliteBookRepository('${dir.path}/q.db', useIsolate: true);
    final book = miniBook();
    final other = miniBook(id: 'other');
    final ops = [
      repo.install(gzJson(book), entryFor(book)),
      repo.install(gzJson(other), entryFor(other)),
      repo.delete('mini'),
    ];
    await Future.wait(ops);
    expect((await repo.installed()).map((b) => b.id), ['other']);
  });

  test('فشل عملية في الطابور لا يوقف ما بعدها', () async {
    final repo = SqliteBookRepository('${dir.path}/q2.db', useIsolate: false);
    final book = miniBook();
    final bad = repo.install(gzJson(book), entryFor(miniBook(version: 2)));
    final good = repo.install(gzJson(book), entryFor(book));
    await expectLater(bad, throwsA(isA<LibraryFormatException>()));
    await good;
    expect((await repo.installed()).single.id, 'mini');
  });

  test('ملف يتجاوز uncompressed_bytes يُرفض عند الاستيراد', () async {
    final repo = SqliteBookRepository('${dir.path}/u.db', useIsolate: false);
    final book = miniBook();
    final gz = gzJson(book);
    final entryMap = catalogEntry(book, gz)..['u'] = 100;
    final entry = parseCatalog(catalogJson([entryMap])).books.single;
    await expectLater(
      repo.install(gz, entry),
      throwsA(isA<LibraryFormatException>()),
    );
    expect(await repo.installed(), isEmpty);
  });

  test('فشل في منتصف الاستيراد لا يترك أثراً (معاملة واحدة)', () {
    final db = openAppDatabase('${dir.path}/c.db');
    addTearDown(db.close);
    final v1 = miniBook();
    importBook(db, decodeBookGz(gzJson(v1)), (
      id: 'mini',
      version: 1,
    ), 'partial');
    // فقرة بمعرّف موجود في كتاب آخر تكسر قيد UNIQUE بعد إدراج أجزاء.
    final clash = miniBook(id: 'clash');
    final para =
        (((clash['chapters']! as List)[1] as Map)['paragraphs']! as List).first
            as Map;
    para['id'] = 'clash-b002-p00001';
    final parsed = decodeBookGz(gzJson(clash));
    db.execute(
      "INSERT INTO books VALUES ('zzz', 1, 't', null, 'a', null, null, 'none', '{}', 'x', 0, 0)",
    );
    db.execute(
      'INSERT INTO paragraphs (id, book_id, chapter_id, ord, kind, text) '
      "VALUES ('clash-b002-p00001', 'zzz', 'c', 0, 'prose', 'x')",
    );
    expect(
      () => importBook(db, parsed, (id: 'clash', version: 1), 'partial'),
      throwsA(isA<SqliteException>()),
    );
    expect(
      db
          .select("SELECT COUNT(*) AS n FROM books WHERE id = 'clash'")
          .single['n'],
      0,
    );
    expect(
      db
          .select("SELECT COUNT(*) AS n FROM chapters WHERE book_id = 'clash'")
          .single['n'],
      0,
    );
    expect(
      db
          .select(
            "SELECT COUNT(*) AS n FROM paragraphs WHERE book_id = 'clash'",
          )
          .single['n'],
      0,
    );
  });
}
