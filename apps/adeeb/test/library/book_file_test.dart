import 'dart:convert';
import 'dart:io';

import 'package:adeeb/library/book_file.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixtures.dart';

void main() {
  test('يفك gzip ويحلل الكتاب الاصطناعي', () {
    final book = decodeBookGz(gzJson(miniBook()));
    expect(book.id, 'mini');
    expect(book.version, 1);
    expect(book.chapters.map((c) => c.id), ['mini-b001', 'mini-b002']);
    expect(book.chapters[1].level, 2);
    expect(book.paragraphCount, 3);
    expect(book.chapters[1].paragraphs.single.kind, 'verse');
    expect(book.chapters[0].paragraphs.first.kind, 'prose');
  });

  test('تفاصيل المصدر الاختيارية: الطبعة والأصل وما حُذف (شاشة المصادر)', () {
    final map = miniBook();
    (map['source']! as Map<String, Object?>)['original'] = 'أصل اختبار';
    final book = decodeBookGz(gzJson(map));
    expect(book.edition, 'لا توجد');
    expect(book.original, 'أصل اختبار');
    expect(book.removed, startsWith('لا شيء'));

    final bare = miniBook()..remove('removed');
    (bare['source']! as Map<String, Object?>).remove('edition');
    final plain = decodeBookGz(gzJson(bare));
    expect(plain.edition, isNull);
    expect(plain.original, isNull);
    expect(plain.removed, isNull);
  });

  test('tts اختياري: يُقرأ إن وُجد، ويُرفض غير النصي', () {
    final map = miniBook();
    final p =
        (((map['chapters']! as List).first as Map)['paragraphs']! as List).first
            as Map<String, Object?>;
    p['tts'] = 'هَذِهِ فقرة';
    final book = decodeBookGz(gzJson(map));
    expect(book.chapters[0].paragraphs[0].tts, 'هَذِهِ فقرة');
    expect(book.chapters[0].paragraphs[0].text, startsWith('هذه فقرة'));
    expect(book.chapters[0].paragraphs[1].tts, isNull);
    p['tts'] = 3;
    expect(
      () => decodeBookGz(gzJson(map)),
      throwsA(isA<LibraryFormatException>()),
    );
  });

  test('يقبل redirects إلى معرّف موجود', () {
    final map = miniBook()
      ..['redirects'] = {'mini-b001-p00009': 'mini-b001-p00001'};
    expect(decodeBookGz(gzJson(map)).redirects, {
      'mini-b001-p00009': 'mini-b001-p00001',
    });
  });

  Map<String, Object?> firstParagraph(Map<String, Object?> book) =>
      ((((book['chapters']! as List).first as Map)['paragraphs']! as List)
              .first)
          as Map<String, Object?>;

  for (final (name, mutate) in <(String, void Function(Map<String, Object?>))>[
    ('فقرة فارغة', (b) => firstParagraph(b)['text'] = '   '),
    (
      'معرّف فقرة لا يتبع الباب',
      (b) => firstParagraph(b)['id'] = 'mini-b002-p00009',
    ),
    ('معرّف فقرة مكرر', (b) => firstParagraph(b)['id'] = 'mini-b001-p00002'),
    ('نوع فقرة مجهول', (b) => firstParagraph(b)['kind'] = 'note'),
    (
      'تحويل إلى معرّف غير موجود',
      (b) => b['redirects'] = {'mini-b001-p00009': 'mini-b009-p00001'},
    ),
    (
      'مفتاح تحويل لكتاب آخر',
      (b) => b['redirects'] = {'other-b001-p00009': 'mini-b001-p00001'},
    ),
    (
      'مفتاح تحويل بصيغة خاطئة',
      (b) => b['redirects'] = {'mini-p9': 'mini-b001-p00001'},
    ),
    (
      'مفتاح تحويل هو معرّف قائم',
      (b) => b['redirects'] = {'mini-b001-p00002': 'mini-b001-p00001'},
    ),
    (
      'مستوى باب 4',
      (b) => ((b['chapters']! as List).first as Map)['level'] = 4,
    ),
    ('بلا أبواب', (b) => b['chapters'] = <Object?>[]),
  ]) {
    test('يرفض: $name', () {
      final map = miniBook();
      mutate(map);
      expect(
        () => decodeBookGz(gzJson(map)),
        throwsA(isA<LibraryFormatException>()),
      );
    });
  }

  test('الحد الأقصى للنص المفكوك', () {
    final gz = gzJson(miniBook());
    final size = gzip.decode(gz).length;
    expect(decodeBookGz(gz, maxUncompressedBytes: size).id, 'mini');
    expect(
      () => decodeBookGz(gz, maxUncompressedBytes: size - 1),
      throwsA(isA<LibraryFormatException>()),
    );
    // قنبلة ضغط: 50 م.ب من الأصفار تُرفض بحد 1 م.ب دون فكها كلها.
    final bomb = gzip.encode(List.filled(50 * 1000 * 1000, 0x20));
    expect(
      () => decodeBookGz(bomb, maxUncompressedBytes: 1000000),
      throwsA(isA<LibraryFormatException>()),
    );
  });

  test('schema أحدث وملف ليس gzip', () {
    expect(
      () => decodeBookGz(gzJson(miniBook()..['schema'] = 2)),
      throwsA(isA<UnsupportedSchemaException>()),
    );
    expect(
      () => decodeBookGz(utf8.encode('not gzip')),
      throwsA(isA<LibraryFormatException>()),
    );
    expect(
      () => decodeBookGz(gzip.encode([0xff, 0xfe])),
      throwsA(isA<LibraryFormatException>()),
    );
  });

  group('الصيغة 2: عضو gzip لكل باب (D35)', () {
    int members(List<int> gz) {
      // كل عضو يبدأ بالترويسة 1f 8b 08.
      var n = 0;
      for (var i = 0; i + 2 < gz.length; i++) {
        if (gz[i] == 0x1f && gz[i + 1] == 0x8b && gz[i + 2] == 8) n++;
      }
      return n;
    }

    test('يفك الأعضاء المتتالية كلها إلى الكتاب نفسه', () {
      final map = syntheticBook(chapters: 5, perChapter: 30);
      final v2 = gzV2(map);
      expect(members(v2), greaterThanOrEqualTo(7)); // رأس + 5 أبواب + ذيل
      expect(utf8.decode(gzip.decode(v2)), jsonEncode(map));
      final a = decodeBookGz(v2);
      final b = decodeBookGz(gzJson(map));
      expect(a.chapters.length, 5);
      expect(a.paragraphCount, b.paragraphCount);
      expect(
        a.chapters.last.paragraphs.last.text,
        b.chapters.last.paragraphs.last.text,
      );
    });

    test('ملف أكبر من دفعة الفك (64 ك.ب) بأعضاء كثيرة', () {
      final map = syntheticBook(chapters: 150, perChapter: 80);
      final v2 = gzV2(map);
      expect(v2.length, greaterThan(64 * 1024));
      expect(decodeBookGz(v2).paragraphCount, 150 * 80);
    });

    test('معرّفات آلية (o00113) وأبواب بأربعة أرقام', () {
      final map = syntheticBook(id: 'o00113', chapters: 2, perChapter: 2);
      final chapters = map['chapters']! as List<Object?>;
      final second = chapters[1]! as Map<String, Object?>;
      second['id'] = 'o00113-b1000';
      for (final p in second['paragraphs']! as List<Object?>) {
        final para = p! as Map<String, Object?>;
        para['id'] = (para['id']! as String).replaceFirst('-b002-', '-b1000-');
      }
      final book = decodeBookGz(gzV2(map));
      expect(book.id, 'o00113');
      expect(book.chapters.last.id, 'o00113-b1000');
    });

    test('عضو مبتور أو تجاوز الحجم المعلن ← LibraryFormatException', () {
      final v2 = gzV2(syntheticBook());
      expect(
        () => decodeBookGz(v2.sublist(0, v2.length - 10)),
        throwsA(isA<LibraryFormatException>()),
      );
      final size = gzip.decode(v2).length;
      expect(
        () => decodeBookGz(v2, maxUncompressedBytes: size - 1),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(decodeBookGz(v2, maxUncompressedBytes: size).paragraphCount, 60);
    });
  });
}
