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

  test('يحلل فهرساً صالحاً بالترتيب', () {
    final other = miniBook(id: 'other');
    final c = parseCatalog(catalogJson([entry, catalogEntry(other, gzJson(other))], catalogVersion: 3));
    expect(c.catalogVersion, 3);
    expect(c.books.map((b) => b.id), ['mini', 'other']);
    final b = c.byId('mini')!;
    expect(b.title.ar, 'كتاب اختبار اصطناعي');
    expect(b.title.en, 'Synthetic Test Book');
    expect(b.authorDeathHijri, 100);
    expect(b.file, 'books/mini/mini.v1.json.gz');
    expect(b.license, 'public-domain');
  });

  test('schema أحدث ← UnsupportedSchemaException', () {
    expect(() => parseCatalog(catalogJson([entry], schema: 2)),
        throwsA(isA<UnsupportedSchemaException>()));
  });

  for (final (name, mutate) in <(String, void Function(Map<String, Object?>))>[
    ('مسار خارج مجلد الكتاب', (e) => e['file'] = '../../etc/passwd'),
    ('مسار لا يطابق الإصدار', (e) => e['file'] = 'books/mini/mini.v2.json.gz'),
    ('رابط مطلق', (e) => e['file'] = 'https://evil.test/x.json.gz'),
    ('sha256 غير صالح', (e) => e['sha256'] = 'abc'),
    ('حجم صفر', (e) => e['size_bytes'] = 0),
    ('معرّف بأحرف كبيرة', (e) => e['id'] = 'Mini'),
    ('عنوان عربي مفقود', (e) => e['title'] = {'en': 'x'}),
  ]) {
    test('يرفض: $name', () {
      final bad = Map<String, Object?>.of(entry);
      mutate(bad);
      expect(() => parseCatalog(catalogJson([bad])), throwsA(isA<LibraryFormatException>()));
    });
  }

  test('يرفض معرّفاً مكرراً وJSON تالفاً', () {
    expect(() => parseCatalog(catalogJson([entry, entry])), throwsA(isA<LibraryFormatException>()));
    expect(() => parseCatalog('{'), throwsA(isA<LibraryFormatException>()));
    expect(() => parseCatalog(jsonEncode([1])), throwsA(isA<LibraryFormatException>()));
  });
}
