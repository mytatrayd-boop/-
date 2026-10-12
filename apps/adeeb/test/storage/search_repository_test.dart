import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/storage/app_database.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/search_repository.dart';
import 'package:adeeb/storage/write_queue.dart';
import 'package:adeeb/text/search_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/library_fixtures.dart';

CatalogBook entryFor(Map<String, Object?> book) =>
    parseCatalog(catalogJson([catalogEntry(book, gzJson(book))])).books.single;

/// كتاب اصطناعي من نصوص فقرات (ليست نصوصاً تراثية): باب لكل [perChapter].
Map<String, Object?> textBook(
  String id,
  List<String> texts, {
  int version = 1,
  int perChapter = 1000,
}) {
  String pad(int n, int w) => n.toString().padLeft(w, '0');
  final chapters = <Map<String, Object?>>[];
  for (var start = 0; start < texts.length; start += perChapter) {
    final c = chapters.length + 1;
    final end = min(start + perChapter, texts.length);
    chapters.add({
      'id': '$id-b${pad(c, 3)}',
      'title': 'باب اختبار $c',
      'level': 1,
      'paragraphs': [
        for (var i = start; i < end; i++)
          {
            'id': '$id-b${pad(c, 3)}-p${pad(i - start + 1, 5)}',
            'text': texts[i],
          },
      ],
    });
  }
  return {
    'schema': 1,
    'id': id,
    'version': version,
    'title': {'ar': 'كتاب $id الاصطناعي'},
    'author': {'ar': 'مولّد الاختبار'},
    'author_death_hijri': 100,
    'source': {
      'name': 'بيانات اختبار اصطناعية',
      'url': 'https://example.invalid/$id',
      'retrieved': '2026-10-12',
      'edition': 'لا توجد',
    },
    'license': 'public-domain',
    'removed': 'لا شيء',
    'chapters': chapters,
    'redirects': <String, String>{},
  };
}

const _sample = [
  'فقرة اختبار أولى فيها الحِكْمَةُ مشكولة.',
  'وقف الأَسَدُ على التل في فقرة اختبار.',
  'رأى الصياد أَسَدٌ ثم عاد إلى البيت.',
  'فقرة بلا كلمات مطلوبة.',
  'شطر فيه الحكمة\tشطر ثانٍ\nبيت آخر',
];

void main() {
  late Directory dir;
  late String path;
  late SqliteBookRepository books;
  late SqliteSearchRepository search;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('adeeb_search_');
    path = '${dir.path}/adeeb.db';
    books = SqliteBookRepository(path, useIsolate: false);
    search = SqliteSearchRepository(path, useIsolate: false);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> install(Map<String, Object?> book) =>
      books.install(gzJson(book), entryFor(book));

  Future<List<String>> ids(String q, {String? bookId}) async =>
      (await search.search(
        SearchQuery.parse(q),
        bookId: bookId,
      )).hits.map((h) => h.paragraphId).toList();

  int ftsRows() {
    final db = openAppDatabase(path);
    try {
      return db.select('SELECT COUNT(*) AS n FROM paragraphs_fts').first['n']
          as int;
    } finally {
      db.close();
    }
  }

  group('أمثلة القبول (SPEC الميزة 4)', () {
    setUp(() => install(textBook('aa', _sample)));

    test('«الحكمه» يجد «الحِكْمَةُ» ويظلّلها بتشكيلها', () async {
      final page = await search.search(SearchQuery.parse('الحكمه'));
      expect(
        page.hits.map((h) => h.paragraphId),
        unorderedEquals(['aa-b001-p00001', 'aa-b001-p00005']),
      );
      final hit = page.hits.firstWhere(
        (h) => h.paragraphId == 'aa-b001-p00001',
      );
      final s = hit.snippet;
      expect(
        s.text.substring(s.spans.single.start, s.spans.single.end),
        'الحِكْمَةُ',
      );
      expect(hit.matchedWords, ['الحِكْمَةُ']);
      expect(hit.bookTitle, 'كتاب aa الاصطناعي');
      expect(hit.chapterTitle, 'باب اختبار 1');
    });

    test('«اسد» يجد «الأَسَدُ» و«أَسَداً»', () async {
      expect(
        await ids('اسد'),
        unorderedEquals(['aa-b001-p00002', 'aa-b001-p00003']),
      );
      expect(
        await ids('أسد'),
        unorderedEquals(['aa-b001-p00002', 'aa-b001-p00003']),
      );
    });

    test('«علي» يجد «على»، و«الي» يجد «إلى»', () async {
      expect(await ids('علي'), ['aa-b001-p00002']);
      expect(await ids('الي'), ['aa-b001-p00003']);
    });

    test('كلمتان بـ AND، وعبارة بين علامتي تنصيص', () async {
      expect(await ids('اسد التل'), ['aa-b001-p00002']);
      expect(
        await ids('"فقرة اختبار"'),
        unorderedEquals(['aa-b001-p00001', 'aa-b001-p00002']),
      );
      expect(await ids('"اختبار فقرة"'), isEmpty);
    });

    test('لا نتائج ← صفحة فارغة بعدد صفر', () async {
      final page = await search.search(SearchQuery.parse('غائبة'));
      expect(page.hits, isEmpty);
      expect(page.total, 0);
    });

    test('مدخلات FTS5 الخاصة لا ترمي خطأ', () async {
      for (final q in ['"', 'NEAR(', 'a OR', '*', 'AND', '(', ':']) {
        await search.search(SearchQuery.parse(q));
      }
    });
  });

  test(
    'النطاق: كتاب واحد أو كل الكتب، والعدد لكل كتاب بترتيب التثبيت',
    () async {
      await install(textBook('aa', _sample));
      await install(textBook('bb', ['الحكمة في كتاب ثانٍ.', 'نص آخر']));
      final all = await search.search(SearchQuery.parse('الحكمة'));
      expect(all.counts.map((c) => (c.bookId, c.count)), [
        ('aa', 2),
        ('bb', 1),
      ]);
      expect(all.total, 3);
      expect(all.hits.map((h) => h.bookId), ['aa', 'aa', 'bb']);
      final one = await search.search(
        SearchQuery.parse('الحكمة'),
        bookId: 'bb',
      );
      expect(one.hits.single.paragraphId, 'bb-b001-p00001');
      expect(one.counts.single.count, 1);
    },
  );

  test('الصفحات: offset وlimit، والعدد مع الصفحة الأولى فقط', () async {
    await install(
      textBook('aa', [for (var i = 0; i < 7; i++) 'كلمة مكررة رقم $i']),
    );
    final q = SearchQuery.parse('مكرره');
    final first = await search.search(q, limit: 5);
    final second = await search.search(q, offset: 5, limit: 5);
    expect(first.hits, hasLength(5));
    expect(first.total, 7);
    expect(second.hits, hasLength(2));
    expect(second.counts, isEmpty);
    expect({
      ...first.hits.map((h) => h.paragraphId),
      ...second.hits.map((h) => h.paragraphId),
    }, hasLength(7));
  });

  test('الحذف يزيل فهرس الكتاب ولا يمس فهرس غيره', () async {
    await install(textBook('aa', _sample));
    await install(textBook('bb', ['الحكمة هنا', 'نص']));
    expect(ftsRows(), 7);
    await books.delete('aa');
    expect(ftsRows(), 2);
    expect(await ids('اسد'), isEmpty);
    expect(await ids('الحكمة'), ['bb-b001-p00001']);
  });

  test('إعادة الاستخدام لأرقام الصفوف لا تُظهر نصاً محذوفاً', () async {
    // aa تأخذ أرقاماً، تُحذف، ثم كتاب جديد قد يأخذ الأرقام نفسها.
    await install(textBook('aa', ['كلمة فريدة أولى', 'ثانية']));
    await books.delete('aa');
    await install(textBook('cc', ['نص جديد', 'نص جديد آخر']));
    expect(await ids('فريده'), isEmpty);
    expect(ftsRows(), 2);
  });

  test('التحديث يستبدل الفهرس: لا نتائج قديمة ولا مكررة', () async {
    await install(textBook('aa', ['نص قديم فيه الحكمة', 'باقٍ']));
    await install(textBook('aa', ['نص جديد فيه الحكمة', 'باقٍ'], version: 2));
    expect(await ids('قديم'), isEmpty);
    expect(await ids('جديد'), ['aa-b001-p00001']);
    expect(await ids('الحكمة'), ['aa-b001-p00001']);
    expect(ftsRows(), 2);
  });

  test('فشل في منتصف الاستيراد يلغي الفهرسة أيضاً (المعاملة نفسها)', () async {
    await install(textBook('aa', ['الإصدار الأول فيه الحكمة']));
    final db = openAppDatabase(path);
    db.execute(
      'CREATE TRIGGER fail_import BEFORE INSERT ON paragraphs '
      "WHEN NEW.text LIKE '%يفشل%' BEGIN SELECT RAISE(ABORT, 'x'); END",
    );
    db.close();
    final bad = textBook('aa', ['الإصدار الثاني', 'هنا يفشل'], version: 2);
    await expectLater(install(bad), throwsA(isA<SqliteException>()));
    expect(await ids('الحكمة'), ['aa-b001-p00001']);
    expect(await ids('الثاني'), isEmpty);
    expect(ftsRows(), 1);
  });

  test('الاستيراد (ومعه الفهرسة) يمر عبر طابور الكتابة', () async {
    await ensureDatabaseReady(path, useIsolate: false);
    final gate = Completer<void>();
    final blocker = enqueueWrite(path, () => gate.future);
    var done = false;
    final installing = install(textBook('aa', _sample))
        .then((_) => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(done, isFalse, reason: 'ينتظر الكاتب السابق في الطابور');
    gate.complete();
    await blocker;
    await installing;
    expect(await ids('الحكمة'), hasLength(2));
  });

  test('الترحيل 3 يفهرس الكتب المثبّتة قبل الميزة 4', () async {
    // قاعدة بإصدار 2 (قبل الفهرس) فيها كتاب مثبّت.
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    migrations[0](db);
    migrations[1](db);
    db.userVersion = 2;
    db.execute(
      "INSERT INTO books VALUES ('old', 1, 'كتاب قديم', NULL, 'مؤلف', NULL, "
      "NULL, 'full', '{}', 'public-domain', 1, 10)",
    );
    db.execute("INSERT INTO chapters VALUES ('old-b001', 'old', 0, 1, 'باب')");
    db.execute(
      'INSERT INTO paragraphs (id, book_id, chapter_id, ord, kind, text) VALUES '
      "('old-b001-p00001', 'old', 'old-b001', 0, 'prose', 'فيها الحِكْمَةُ'), "
      "('old-b001-p00002', 'old', 'old-b001', 1, 'prose', 'وفيها الأَسَدُ')",
    );
    db.close();

    await ensureDatabaseReady(path, useIsolate: false);
    final check = openAppDatabase(path);
    expect(check.userVersion, schemaVersion);
    check.close();
    expect(await ids('الحكمه'), ['old-b001-p00001']);
    expect(await ids('اسد'), ['old-b001-p00002']);
    expect(ftsRows(), 2);
  });

  test('«و/ف» من أصل الكلمة: «كره» لا تجد «فكرة»، «ساد» لا تجد «فساد»، '
      '«جود» لا تجد «وجود»', () async {
    await install(
      textBook('ww', [
        'فقرة فيها فكرة واحدة.',
        'فقرة عن الفساد وفساد الرأي.',
        'فقرة عن وجود الشيء.',
        'وكتاب جديد.',
      ]),
    );
    expect(await ids('كره'), isEmpty);
    expect(await ids('ساد'), isEmpty);
    expect(await ids('جود'), isEmpty);
    expect(await ids('فكرة'), ['ww-b001-p00001']);
    expect(await ids('فساد'), ['ww-b001-p00002']);
    expect(await ids('وجود'), ['ww-b001-p00003']);
    // السابقة المفردة تُحذف حين يبقى 4 أحرف.
    expect(await ids('كتاب'), ['ww-b001-p00004']);
  });

  test('الترحيل 4 يعيد فهرسة الجذوع القديمة', () async {
    // قاعدة بإصدار 3 فيها صف فهرس بجذع قديم («فكره» ← «كره»).
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    for (var i = 0; i < 3; i++) {
      migrations[i](db);
    }
    db.userVersion = 3;
    db.execute(
      "INSERT INTO books VALUES ('old', 1, 'كتاب قديم', NULL, 'مؤلف', NULL, "
      "NULL, 'full', '{}', 'public-domain', 1, 10)",
    );
    db.execute("INSERT INTO chapters VALUES ('old-b001', 'old', 0, 1, 'باب')");
    db.execute(
      'INSERT INTO paragraphs (rowid, id, book_id, chapter_id, ord, kind, text) '
      "VALUES (1, 'old-b001-p00001', 'old', 'old-b001', 0, 'prose', 'فكرة')",
    );
    db.execute(
      "INSERT INTO paragraphs_fts (rowid, norm, stem) VALUES (1, 'فكره', 'كره')",
    );
    db.close();

    await ensureDatabaseReady(path, useIsolate: false);
    expect(await ids('كره'), isEmpty);
    expect(await ids('فكرة'), ['old-b001-p00001']);
    expect(ftsRows(), 1);
  });

  test('البحث في Isolate منفصل يعمل', () async {
    await install(textBook('aa', _sample));
    final isolated = SqliteSearchRepository(path);
    final page = await isolated.search(SearchQuery.parse('الحكمه'));
    expect(page.hits, hasLength(2));
  });

  test(
    'الأداء: كتاب 30,000 فقرة — الاستيراد مع الفهرسة والبحث (قياس على المضيف)',
    () async {
      final rnd = Random(42);
      // مفردات اصطناعية متكررة؛ ليست نصاً تراثياً.
      const vocab = [
        'قال',
        'كان',
        'الرجل',
        'فقال',
        'الكتاب',
        'الباب',
        'في',
        'من',
        'على',
        'إلى',
        'الأَسَدُ',
        'الحِكْمَةُ',
        'والملك',
        'بالقلم',
        'كلمات',
        'حديث',
        'خبر',
        'شعر',
        'الناس',
        'يومًا',
        'ثم',
        'إنَّ',
        'لم',
        'هذا',
        'ذلك',
      ];
      final texts = [
        for (var i = 0; i < 30000; i++)
          [
            for (var w = 0; w < 25 + rnd.nextInt(30); w++)
              vocab[rnd.nextInt(vocab.length)],
            'رمز$i',
          ].join(' '),
      ];
      final book = textBook('big', texts, perChapter: 300);
      final gz = gzJson(book);
      final entry = entryFor(book);

      final sw = Stopwatch()..start();
      await books.install(gz, entry);
      final importMs = sw.elapsedMilliseconds;
      expect(ftsRows(), 30000);

      final timings = <String, int>{};
      for (final q in [
        'الحكمه',
        'اسد',
        'قال',
        'رمز29999',
        'الحكمه اسد',
        '"قال الرجل"',
      ]) {
        sw.reset();
        final page = await search.search(SearchQuery.parse(q));
        timings[q] = sw.elapsedMilliseconds;
        expect(page.total, greaterThan(0), reason: q);
        expect(page.hits.length, min(50, page.total));
        expect(timings[q], lessThan(1000), reason: q);
      }
      // ignore: avoid_print
      print('30,000 فقرة: استيراد+فهرسة ${importMs}ms، بحث $timings');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
