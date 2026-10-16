import 'dart:convert';

import 'package:adeeb/library/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixtures.dart';

void main() {
  late Map<String, Object?> entry;
  setUp(() {
    final book = miniBook();
    entry = catalogEntry(book, gzJson(book));
  });

  test('schema 2: يحلل الحقول المختصرة والتصنيف والعصر والمسار المقسّم', () {
    final other = miniBook(id: 'other');
    final c = parseCatalog(
      catalogJson([
        entry,
        catalogEntry(other, gzJson(other)),
      ], catalogVersion: 3),
    );
    expect(c.catalogVersion, 3);
    expect(c.books.map((b) => b.id), ['mini', 'other']);
    final b = c.byId('mini')!;
    expect(b.title.ar, 'كتاب اختبار اصطناعي');
    expect(b.title.en, isNull);
    expect(b.author.ar, isNotEmpty);
    expect(b.authorDeathHijri, 100);
    expect(b.file, 'books/ni/mini/mini.v1.json.gz');
    expect(b.license, 'public-domain');
    expect(b.category, 'adab');
    expect(b.era, 'abbasid');
    expect(b.sourceName, 'OpenITI');
  });

  test('schema 2: معرّفات آلية (o00113) بمسارها المقسّم', () {
    final book = miniBook(id: 'o00113');
    final c = parseCatalog(catalogJson([catalogEntry(book, gzJson(book))]));
    expect(c.books.single.id, 'o00113');
    expect(c.books.single.file, 'books/13/o00113/o00113.v1.json.gz');
  });

  test('schema 1 القديم ما زال يُقرأ (للترحيل)', () {
    final book = miniBook();
    final c = parseCatalog(
      catalogJson([legacyCatalogEntry(book, gzJson(book))], schema: 1),
    );
    expect(c.schema, 1);
    expect(c.books.single.title.en, 'Synthetic Test Book');
    expect(c.books.single.file, 'books/mini/mini.v1.json.gz');
    expect(c.books.single.category, isNull);
  });

  test('schema أحدث ← UnsupportedSchemaException', () {
    expect(
      () => parseCatalog(catalogJson([entry], schema: 3)),
      throwsA(isA<UnsupportedSchemaException>()),
    );
  });

  for (final (name, mutate) in <(String, void Function(Map<String, Object?>))>[
    ('مسار خارج مجلد الكتاب', (e) => e['f'] = '../../etc/passwd'),
    ('مسار لا يطابق الإصدار', (e) => e['f'] = 'books/ni/mini/mini.v2.json.gz'),
    ('مسار غير مقسّم', (e) => e['f'] = 'books/mini/mini.v1.json.gz'),
    ('رابط مطلق', (e) => e['f'] = 'https://evil.test/x.json.gz'),
    ('sha256 غير صالح', (e) => e['sha'] = 'abc'),
    ('حجم صفر', (e) => e['sz'] = 0),
    ('معرّف بأحرف كبيرة', (e) => e['id'] = 'Mini'),
    ('معرّف يبدأ برقم', (e) => e['id'] = '0mini'),
    ('عنوان فارغ', (e) => e['t'] = ' '),
  ]) {
    test('يرفض: $name', () {
      final bad = Map<String, Object?>.of(entry);
      mutate(bad);
      expect(
        () => parseCatalog(catalogJson([bad])),
        throwsA(isA<LibraryFormatException>()),
      );
    });
  }

  test('يرفض معرّفاً مكرراً وJSON تالفاً', () {
    expect(
      () => parseCatalog(catalogJson([entry, entry])),
      throwsA(isA<LibraryFormatException>()),
    );
    expect(() => parseCatalog('{'), throwsA(isA<LibraryFormatException>()));
    expect(
      () => parseCatalog(jsonEncode([1])),
      throwsA(isA<LibraryFormatException>()),
    );
  });
}
