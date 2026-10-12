import 'dart:async';
import 'dart:io';

import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/reader/reader_book.dart';
import 'package:adeeb/storage/app_database.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/reading_repository.dart';
import 'package:adeeb/storage/write_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/library_fixtures.dart';

CatalogBook entryFor(Map<String, Object?> book) =>
    parseCatalog(catalogJson([catalogEntry(book, gzJson(book))])).books.single;

/// الإصدار 2 من الكتاب الاصطناعي: الفقرة p00002 من الباب الأول قُسمت وأُعطيت
/// معرّفاً جديداً p00003، والقديم في `redirects`.
Map<String, Object?> miniV2() {
  final book = miniBook(version: 2);
  final chapters = book['chapters']! as List<Object?>;
  final first = chapters.first! as Map<String, Object?>;
  final paragraphs = first['paragraphs']! as List<Object?>;
  final second = paragraphs[1]! as Map<String, Object?>;
  second['id'] = 'mini-b001-p00003';
  book['redirects'] = {'mini-b001-p00002': 'mini-b001-p00003'};
  return book;
}

void main() {
  late Directory dir;
  late SqliteBookRepository books;
  late SqliteReadingRepository reading;
  var clock = DateTime.utc(2026, 10, 11);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('adeeb_reading_');
    books = SqliteBookRepository('${dir.path}/adeeb.db', useIsolate: false);
    clock = DateTime.utc(2026, 10, 11);
    reading = SqliteReadingRepository(
      '${dir.path}/adeeb.db',
      useIsolate: false,
      clock: () {
        clock = clock.add(const Duration(seconds: 1));
        return clock;
      },
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> install(Map<String, Object?> book) =>
      books.install(gzJson(book), entryFor(book));

  test('الترحيل 2: جدولا المفضلة والموضع بلا مفتاح أجنبي (D18)', () {
    final db = openAppDatabase('${dir.path}/adeeb.db');
    addTearDown(db.close);
    expect(db.userVersion, 2);
    for (final table in ['favorites', 'positions']) {
      expect(
        db.select('PRAGMA foreign_key_list($table)'),
        isEmpty,
        reason: table,
      );
    }
  });

  test('ترحيل قاعدة من الإصدار 1 يحفظ الكتب ويضيف الجدولين', () async {
    // قاعدة بالإصدار 1 فقط (كما تركتها الميزة 2).
    final path = '${dir.path}/old.db';
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('BEGIN');
    migrations.first(db);
    db.userVersion = 1;
    db.execute('COMMIT');
    db.close();
    final old = SqliteBookRepository(path, useIsolate: false);
    // الاستيراد يفتح القاعدة فيرحّلها.
    final book = miniBook();
    await old.install(gzJson(book), entryFor(book));
    final reopened = openAppDatabase(path);
    addTearDown(reopened.close);
    expect(reopened.userVersion, 2);
    expect(reopened.select('SELECT id FROM books').single['id'], 'mini');
  });

  test('نص الكتاب للقارئ: أبواب وفقرات ومدخلات مسطّحة', () async {
    await install(miniBook());
    final book = (await reading.loadBook('mini'))!;
    expect(book.title.ar, 'كتاب اختبار اصطناعي');
    expect(book.chapters.map((c) => c.id), ['mini-b001', 'mini-b002']);
    expect(book.paragraphs.map((p) => p.id), [
      'mini-b001-p00001',
      'mini-b001-p00002',
      'mini-b002-p00001',
    ]);
    expect(book.entryCount, 5);
    expect(book.entryAt(0), isA<HeadingEntry>());
    expect((book.entryAt(2) as ParagraphEntry).paragraphIndex, 1);
    expect((book.entryAt(3) as HeadingEntry).chapterIndex, 1);
    expect(book.entryOfParagraph(2), 4);
    expect(book.paragraphs[2].isVerse, isTrue);
    expect(book.chapterOfEntry(4), 1);
    // العنوان ← أول فقرة في بابه.
    expect(book.paragraphAtOrAfterEntry(3), 2);
    expect(book.paragraphIndexOf('mini-b002-p00001'), 2);
    expect(ReaderBook.chapterIdOfParagraphId('mini-b002-p00009'), 'mini-b002');
    expect(await reading.loadBook('none'), isNull);
  });

  test('آخر موضع: يُحفظ ويُستبدل، ومعه الباب والنسبة', () async {
    await install(miniBook());
    expect(await reading.position('mini'), isNull);
    await reading.savePosition('mini', 'mini-b001-p00001');
    await reading.savePosition('mini', 'mini-b002-p00001');
    final p = (await reading.position('mini'))!;
    expect(p.paragraphId, 'mini-b002-p00001');
    expect(p.chapterTitle, 'فصل اختبار فرعي');
    expect(p.chapterNumber, 2);
    expect(p.chapterCount, 2);
    expect(p.paragraphNumber, 3);
    expect(p.fraction, 1.0);
    expect(p.bookTitle, 'كتاب اختبار اصطناعي');
  });

  test('أحدث موضع بين الكتب المحمّلة', () async {
    await install(miniBook());
    await install(syntheticBook());
    await reading.savePosition('mini', 'mini-b001-p00002');
    await reading.savePosition('big', 'big-b002-p00005');
    expect((await reading.latestPosition())!.bookId, 'big');
    await reading.savePosition('mini', 'mini-b001-p00001');
    expect((await reading.latestPosition())!.paragraphId, 'mini-b001-p00001');
  });

  test('المفضلة: إضافة (الأحدث أولاً) وإزالة وإعادة بتاريخها الأصلي', () async {
    await install(miniBook());
    await reading.addFavorite('mini', 'mini-b001-p00001');
    await reading.addFavorite('mini', 'mini-b002-p00001');
    var list = await reading.favorites();
    expect(list.map((f) => f.paragraphId), [
      'mini-b002-p00001',
      'mini-b001-p00001',
    ]);
    expect(list.first.chapterTitle, 'فصل اختبار فرعي');
    expect(list.first.bookTitle, 'كتاب اختبار اصطناعي');
    expect(list.last.text, startsWith('هذه فقرة اختبار'));
    final removed = list.last;
    await reading.removeFavorite(removed.paragraphId);
    expect((await reading.favorites()).map((f) => f.paragraphId), [
      'mini-b002-p00001',
    ]);
    await reading.addFavorite(
      'mini',
      removed.paragraphId,
      createdAt: removed.createdAt,
    );
    list = await reading.favorites();
    expect(list.map((f) => f.paragraphId), [
      'mini-b002-p00001',
      'mini-b001-p00001',
    ]);
  });

  test('حذف الكتاب يُبقي المفضلة والموضع، وتعود بعد إعادة التحميل', () async {
    await install(miniBook());
    await reading.addFavorite('mini', 'mini-b001-p00002');
    await reading.savePosition('mini', 'mini-b001-p00002');
    await books.delete('mini');

    final fav = (await reading.favorites()).single;
    expect(fav.bookInstalled, isFalse);
    expect(fav.text, isNull);
    expect(await reading.position('mini'), isNull);
    expect(await reading.latestPosition(), isNull);
    final db = openAppDatabase('${dir.path}/adeeb.db');
    expect(db.select('SELECT * FROM positions'), hasLength(1));
    db.close();

    await install(miniBook());
    expect((await reading.favorites()).single.bookInstalled, isTrue);
    expect((await reading.position('mini'))!.paragraphId, 'mini-b001-p00002');
  });

  test('التحديث ينقل المفضلة وآخر موضع عبر redirects', () async {
    await install(miniBook());
    await reading.addFavorite('mini', 'mini-b001-p00002');
    await reading.addFavorite('mini', 'mini-b001-p00001');
    await reading.savePosition('mini', 'mini-b001-p00002');

    await install(miniV2());
    final favs = await reading.favorites();
    expect(favs.map((f) => f.paragraphId).toSet(), {
      'mini-b001-p00003',
      'mini-b001-p00001',
    });
    expect(
      favs.firstWhere((f) => f.paragraphId == 'mini-b001-p00003').text,
      contains('الحِكْمَةُ'),
    );
    expect((await reading.position('mini'))!.paragraphId, 'mini-b001-p00003');
    expect(
      await reading.resolveParagraph('mini-b001-p00002'),
      'mini-b001-p00003',
    );
    expect(
      await reading.resolveParagraph('mini-b001-p00001'),
      'mini-b001-p00001',
    );
  });

  test(
    'التحديث بعد الحذف (كتاب محذوف ثم حُمّل إصداره الأحدث) ينقل المفضلة',
    () async {
      await install(miniBook());
      await reading.addFavorite('mini', 'mini-b001-p00002');
      await books.delete('mini');
      await install(miniV2());
      expect(
        (await reading.favorites()).single.paragraphId,
        'mini-b001-p00003',
      );
    },
  );

  test('فقرتان قديمتان تُحوَّلان لفقرة واحدة: صف مفضلة واحد', () async {
    await install(miniBook());
    final db = openAppDatabase('${dir.path}/adeeb.db');
    addTearDown(db.close);
    db.execute("INSERT INTO favorites VALUES ('mini-b001-p00008', 'mini', 1)");
    db.execute("INSERT INTO favorites VALUES ('mini-b001-p00009', 'mini', 2)");
    db.execute(
      "INSERT INTO redirects VALUES ('mini-b001-p00008', 'mini', 'mini-b001-p00001')",
    );
    db.execute(
      "INSERT INTO redirects VALUES ('mini-b001-p00009', 'mini', 'mini-b001-p00001')",
    );
    applyRedirects(db, 'mini');
    expect(
      db
          .select('SELECT paragraph_id FROM favorites')
          .map((r) => r['paragraph_id']),
      ['mini-b001-p00001'],
    );
  });

  test('سلسلة تحويلات تُتبع حتى آخرها، والحلقة لا تعلق', () async {
    await install(miniBook());
    final db = openAppDatabase('${dir.path}/adeeb.db');
    addTearDown(db.close);
    db.execute(
      "INSERT INTO redirects VALUES ('mini-b009-p00001', 'mini', 'mini-b009-p00002')",
    );
    db.execute(
      "INSERT INTO redirects VALUES ('mini-b009-p00002', 'mini', 'mini-b001-p00001')",
    );
    expect(resolveRedirect(db, 'mini-b009-p00001'), 'mini-b001-p00001');
    db.execute(
      "INSERT INTO redirects VALUES ('mini-b008-p00001', 'mini', 'mini-b008-p00002')",
    );
    db.execute(
      "INSERT INTO redirects VALUES ('mini-b008-p00002', 'mini', 'mini-b008-p00001')",
    );
    expect(resolveRedirect(db, 'mini-b008-p00001'), isNotNull);
  });

  test('نص الكتاب يُقرأ في Isolate منفصل أيضاً', () async {
    await install(syntheticBook(chapters: 2, perChapter: 5));
    final isolated = SqliteReadingRepository('${dir.path}/adeeb.db');
    final book = (await isolated.loadBook('big'))!;
    expect(book.paragraphs, hasLength(10));
    expect(book.entryCount, 12);
  });

  test('حفظ الموضع والمفضلة أثناء معاملة كتابة مفتوحة ينتظر ثم ينجح', () async {
    await install(miniBook());
    final path = '${dir.path}/adeeb.db';
    final release = Completer<void>();
    final locked = Completer<void>();
    // معاملة طويلة في الطابور (كالاستيراد أو الحذف مع VACUUM).
    final holding = enqueueWrite(path, () async {
      final db = openAppDatabase(path);
      db.execute('BEGIN IMMEDIATE');
      locked.complete();
      await release.future;
      db.execute('COMMIT');
      db.close();
    });
    await locked.future;
    var saved = false;
    final save = reading
        .savePosition('mini', 'mini-b001-p00002')
        .then((_) => saved = true);
    final favorite = reading.addFavorite('mini', 'mini-b001-p00001');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(saved, isFalse);
    release.complete();
    await holding;
    await save;
    await favorite;
    expect((await reading.position('mini'))!.paragraphId, 'mini-b001-p00002');
    expect((await reading.favorites()).single.paragraphId, 'mini-b001-p00001');
  });

  test(
    'الاستيراد والحفظ المتزامنان (الاستيراد في Isolate) ينجحان معاً',
    () async {
      await install(miniBook());
      final isolated = SqliteBookRepository('${dir.path}/adeeb.db');
      final big = syntheticBook(chapters: 20, perChapter: 200);
      final importing = isolated.install(gzJson(big), entryFor(big));
      final writes = [
        for (var i = 0; i < 5; i++)
          reading.savePosition('mini', 'mini-b001-p0000${i % 2 + 1}'),
        reading.addFavorite('mini', 'mini-b002-p00001'),
      ];
      await importing;
      await Future.wait(writes);
      expect(
        (await reading.favorites()).single.paragraphId,
        'mini-b002-p00001',
      );
      expect((await reading.loadBook('big'))!.paragraphs, hasLength(4000));
    },
  );
}
