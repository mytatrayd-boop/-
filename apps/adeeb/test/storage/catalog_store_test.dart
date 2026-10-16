import 'dart:io';

import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/storage/app_database.dart';
import 'package:adeeb/storage/catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// فهرس schema 2 اصطناعي (ليست بيانات تراثية).
CatalogBook entry(
  String id, {
  String title = 'كتاب',
  String author = 'مؤلف',
  int? death = 200,
  String category = 'adab',
  String era = 'abbasid',
  int size = 1000,
}) => CatalogBook(
  id: id,
  title: LocalizedName(ar: title),
  author: LocalizedName(ar: author),
  authorDeathHijri: death,
  version: 1,
  file: shardedBookPath(id, 1),
  sha256: 'a' * 64,
  sizeBytes: size,
  uncompressedBytes: size * 4,
  paragraphCount: 10,
  diacritics: 'none',
  sourceName: 'OpenITI',
  sourceUrl: '',
  license: 'CC BY-NC-SA 4.0',
  category: category,
  era: era,
);

Catalog catalogOf(List<CatalogBook> books, {int version = 1}) => Catalog(
  schema: 2,
  catalogVersion: version,
  updated: '2026-10-16',
  books: books,
);

void main() {
  late Directory dir;
  late SqliteCatalogStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('adeeb_catalog_store_');
    store = SqliteCatalogStore('${dir.path}/adeeb.db', useIsolate: false);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<List<String>> q(
    CatalogQuery query, {
    int offset = 0,
    int limit = 50,
  }) => store.query(query, offset: offset, limit: limit);

  final books = [
    entry('o00113', title: 'البخلاء', author: 'الجاحظ', death: 255, size: 300),
    entry(
      'o00200',
      title: 'ديوان امرئ القيس',
      author: 'امرؤ القيس',
      death: -80,
      category: 'poetry',
      era: 'jahili',
      size: 100,
    ),
    entry(
      'o00300',
      title: 'تاريخ الأمم',
      author: 'مؤرخ اصطناعي',
      death: 700,
      category: 'history',
      era: 'late',
      size: 200,
    ),
    entry(
      'o00400',
      title: 'الحيوان',
      author: 'الجاحظ',
      death: 255,
      category: 'adab',
      size: 900,
    ),
  ];

  test('قبل أي استيراد: لا فهرس ولا نتائج', () async {
    expect(await store.load(), isNull);
    expect(await q(const CatalogQuery()), isEmpty);
  });

  test('الاستيراد يحفظ الكتب والتصنيف والعصر والبيانات الوصفية', () async {
    await store.replace(catalogOf(books), etag: '"e1"', fetchedAt: 42);
    final snap = (await store.load())!;
    expect(snap.catalog.schema, 2);
    expect(snap.etag, '"e1"');
    expect(snap.fetchedAt, 42);
    expect(snap.catalog.books.map((b) => b.id), [
      'o00113',
      'o00200',
      'o00300',
      'o00400',
    ]);
    final b = snap.catalog.books.first;
    expect(b.title.ar, 'البخلاء');
    expect(b.category, 'adab');
    expect(b.era, 'abbasid');
    expect(b.file, 'books/13/o00113/o00113.v1.json.gz');
    await store.touch(99);
    expect((await store.load())!.fetchedAt, 99);
  });

  test('استبدال الفهرس يحذف القديم كله (والفهرس النصي معه)', () async {
    await store.replace(catalogOf(books), fetchedAt: 1);
    await store.replace(
      catalogOf([entry('o00999', title: 'كتاب جديد')], version: 2),
      fetchedAt: 2,
    );
    expect(await q(const CatalogQuery()), ['o00999']);
    expect(await q(const CatalogQuery(text: 'البخلاء')), isEmpty);
    expect((await store.load())!.catalog.catalogVersion, 2);
  });

  group('البحث بالعنوان والمؤلف (FTS)', () {
    setUp(() => store.replace(catalogOf(books), fetchedAt: 1));

    test('بالعنوان، وبلا «ال»، وبادئة كلمة', () async {
      expect(await q(const CatalogQuery(text: 'البخلاء')), ['o00113']);
      expect(await q(const CatalogQuery(text: 'بخلاء')), ['o00113']);
      expect(await q(const CatalogQuery(text: 'البخ')), ['o00113']);
    });

    test('بالمؤلف، مع توحيد الهمزة والتشكيل', () async {
      expect(await q(const CatalogQuery(text: 'الجاحظ')), ['o00113', 'o00400']);
      expect(await q(const CatalogQuery(text: 'امرؤ')), ['o00200']);
      expect(await q(const CatalogQuery(text: 'إمرئ')), ['o00200']);
      expect(await q(const CatalogQuery(text: 'الأُمَم')), ['o00300']);
    });

    test('كل الكلمات مطلوبة، والرموز لا تكسر الاستعلام', () async {
      expect(await q(const CatalogQuery(text: 'الجاحظ الحيوان')), ['o00400']);
      expect(await q(const CatalogQuery(text: 'الجاحظ تاريخ')), isEmpty);
      // رموز فقط ← بلا تصفية؛ وكلمات FTS5 المحجوزة تُنصَّص فلا تكسره.
      expect(await q(const CatalogQuery(text: '"*()^')), hasLength(4));
      expect(await q(const CatalogQuery(text: 'OR NEAR')), isEmpty);
      expect(await q(const CatalogQuery(text: 'غير موجود')), isEmpty);
    });

    test('شرائح التصنيف والعصر مع البحث', () async {
      expect(await q(const CatalogQuery(category: 'poetry')), ['o00200']);
      expect(await q(const CatalogQuery(era: 'abbasid')), ['o00113', 'o00400']);
      expect(
        await q(const CatalogQuery(text: 'الجاحظ', category: 'history')),
        isEmpty,
      );
      expect(
        await q(const CatalogQuery(category: 'adab', era: 'late')),
        isEmpty,
      );
    });

    test('الترتيب: الوفاة (الافتراضي)، العنوان، الحجم', () async {
      expect(await q(const CatalogQuery()), [
        'o00200',
        'o00113',
        'o00400',
        'o00300',
      ]);
      expect(await q(const CatalogQuery(sort: CatalogSort.title)), [
        'o00113',
        'o00400',
        'o00300',
        'o00200',
      ]);
      expect(await q(const CatalogQuery(sort: CatalogSort.size)), [
        'o00200',
        'o00300',
        'o00113',
        'o00400',
      ]);
    });
  });

  test('الصفحات LIMIT/OFFSET بلا تكرار ولا فجوة', () async {
    await store.replace(
      catalogOf([
        for (var i = 0; i < 120; i++)
          entry('o${i.toString().padLeft(5, '0')}', death: i),
      ]),
      fetchedAt: 1,
    );
    final pages = [
      await q(const CatalogQuery(), offset: 0),
      await q(const CatalogQuery(), offset: 50),
      await q(const CatalogQuery(), offset: 100),
    ];
    expect(pages.map((p) => p.length), [50, 50, 20]);
    final all = pages.expand((p) => p).toList();
    expect(all.toSet(), hasLength(120));
    expect(all.first, 'o00000');
    expect(all.last, 'o00119');
  });

  test('فهرس اصطناعي 2,000 كتاب: البحث < 200 ms على المضيف', () async {
    const words = ['أدب', 'تاريخ', 'ديوان', 'معجم', 'رحلة', 'نحو', 'أخبار'];
    await store.replace(
      catalogOf([
        for (var i = 0; i < 2000; i++)
          entry(
            'o${i.toString().padLeft(5, '0')}',
            title: 'كتاب ${words[i % words.length]} رقم $i',
            author: 'مؤلف ${words[(i ~/ 7) % words.length]}',
            death: i % 1300,
            category: catalogCategories[i % catalogCategories.length],
            era: catalogEras[i % catalogEras.length],
            size: 1000 + i,
          ),
      ]),
      fetchedAt: 1,
    );
    // الاستعلام وحده بلا فتح القاعدة (فتحها مرة لكل استعلام في التطبيق).
    final db = openAppDatabase('${dir.path}/adeeb.db');
    addTearDown(db.close);
    for (final query in const [
      CatalogQuery(text: 'تاريخ'),
      CatalogQuery(text: 'ديوان', category: 'poetry', sort: CatalogSort.title),
      CatalogQuery(text: 'مؤلف رحلة', era: 'abbasid', sort: CatalogSort.size),
      CatalogQuery(),
    ]) {
      final watch = Stopwatch()..start();
      final ids = queryCatalogIds(db, query, offset: 50, limit: 50);
      watch.stop();
      expect(ids, isNotEmpty, reason: query.text);
      expect(watch.elapsedMilliseconds, lessThan(200), reason: query.text);
    }
  });
}
