import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, Object?> autoBook({String id = 'o00012', int chapters = 3}) {
  final b = validBook();
  b['id'] = id;
  b['chapters'] = [
    for (var c = 1; c <= chapters; c++)
      {
        'id': '$id-b${c.toString().padLeft(3, '0')}',
        'title': 'باب $c',
        'level': 1,
        'paragraphs': [
          for (var p = 1; p <= 3; p++)
            {'id': '$id-b${c.toString().padLeft(3, '0')}-p${p.toString().padLeft(5, '0')}', 'text': 'فقرة $p من الباب $c.'},
        ],
      },
  ];
  b['source'] = {
    'name': 'OpenITI',
    'url': 'https://github.com/OpenITI/RELEASE/x',
    'retrieved': '2026-10-16',
    'openiti': {'uri': '0300A.Kitab.X-ara1'},
  };
  return b;
}

void main() {
  group('الصيغة 2', () {
    test('فك الملف كاملاً يعطي JSON نفسه، وكل عضو باب يُفك وحده', () {
      final book = autoBook();
      final v2 = encodeBookV2(book);
      expect(gzip.decode(v2.gz), encodeBookJson(book));
      final chapters = (v2.index['chapters']! as List).cast<Map<String, Object?>>();
      expect(chapters, hasLength(3));
      for (final (i, c) in chapters.indexed) {
        final member = v2.gz.sublist(c['o']! as int, (c['o']! as int) + (c['l']! as int));
        expect(decodeChapterMember(member), (book['chapters']! as List)[i]);
      }
      expect(checkBookV2Index(v2.gz, v2.index, book), isEmpty);
      // حتمي.
      expect(encodeBookV2(book).gz, v2.gz);
    });

    test('إزاحة خاطئة أو sha خاطئ يُكشف', () {
      final book = autoBook();
      final v2 = encodeBookV2(book);
      final bad = jsonDecode(jsonEncode(v2.index)) as Map<String, Object?>;
      ((bad['chapters']! as List)[1] as Map)['o'] = 3;
      expect(checkBookV2Index(v2.gz, bad, book), isNotEmpty);
      final bad2 = jsonDecode(jsonEncode(v2.index)) as Map<String, Object?>;
      ((bad2['chapters']! as List)[0] as Map)['sha'] = 'x';
      expect(checkBookV2Index(v2.gz, bad2, book).single, contains('sha'));
    });

    test('الكتب الخمسة: الصيغة 2 تعطي JSON الإصدار المنشور نفسه بايتاً ببايت', () {
      for (final f in latestBookFiles(Directory('..'))) {
        final raw = gzip.decode(f.readAsBytesSync());
        final book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
        final v2 = encodeBookV2(book);
        expect(gzip.decode(v2.gz), raw, reason: f.path);
        expect(checkBookV2Index(v2.gz, v2.index, book), isEmpty, reason: f.path);
      }
    });
  });

  group('التصنيف والعصر', () {
    test('الأولوية بالترتيب، والوسوم العربية قبل GAL', () {
      expect(categorize(['JK@دواوين الشعر العربي', 'JK@كتب التاريخ']), 'poetry');
      expect(categorize(['Shamela@التاريخ', 'Shamela@التراجم والطبقات']), 'history');
      expect(categorize(['Shamela@الأدب والبلاغة', 'GAL@poetry']), 'adab');
      expect(categorize(['JK@البلاغة والفصاحة']), 'rhetoric');
      expect(categorize(['Shamela@الغريب والمعاجم ولغة الفقه']), 'lexicon');
      expect(categorize(['Shamela@النحو والصرف']), 'grammar');
      expect(categorize(['Shamela@الأنساب', 'Shamela@التاريخ']), 'ayyam');
      expect(categorize(['Shamela@البلدان والجغرافيا والرحلات']), 'travel');
      expect(categorize(['GAL@biography']), 'biography');
      expect(categorize(['PRIMARY_VERSION']), 'adab');
    });
    test('العصر من سنة الوفاة', () {
      expect([eraOf(1), eraOf(40), eraOf(41), eraOf(132), eraOf(133), eraOf(656), eraOf(657), eraOf(1300)],
          ['jahili', 'jahili', 'umayyad', 'umayyad', 'abbasid', 'abbasid', 'late', 'late']);
    });
  });

  group('فهرس schema 2 والمدقق', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('adeeb_v2_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('بناء الفهرس حتمي، والمدقق يقبل ويكشف الأخطاء', () {
      writeBookV2(root, autoBookRelativePath('o00012', 1), autoBook());
      writeBookV2(root, autoBookRelativePath('kalila', 1), autoBook(id: 'kalila', chapters: 1));
      final tags = {
        'o00012': ['JK@كتب التاريخ'],
        'kalila': ['Shamela@الأدب والبلاغة'],
      };
      final text = buildCatalogV2(root, date: '2026-10-16', tagsById: tags);
      final cat = jsonDecode(text) as Map<String, Object?>;
      expect(cat['schema'], 2);
      final books = (cat['books']! as List).cast<Map<String, Object?>>();
      expect(books.map((b) => b['id']), ['kalila', 'o00012']);
      expect(books[1]['f'], 'books/12/o00012/o00012.v1.json.gz');
      expect(books[1]['c'], 'history');
      expect(books[1]['e'], 'abbasid');
      expect(books[1]['src'], '0300A.Kitab.X-ara1');
      final catBytes = File('${root.path}/$catalogV2Path').readAsBytesSync();
      buildCatalogV2(root, date: '2026-10-17', tagsById: tags);
      expect(File('${root.path}/$catalogV2Path').readAsBytesSync(), catBytes);

      final ok = validateLibraryV2(root);
      expect(ok.errors, isEmpty);
      expect(ok.books, 2);

      // كتاب غير مدرج، وفهرس جانبي مفقود.
      writeBookV2(root, autoBookRelativePath('o00013', 1), autoBook(id: 'o00013'));
      File('${root.path}/${indexPathFor(autoBookRelativePath('o00012', 1))}').deleteSync();
      final codes = validateLibraryV2(root).errors.map((i) => i.code).toSet();
      expect(codes, containsAll(['not_listed', 'file']));
    });

    test('مسار غير مقسّم مرفوض', () {
      writeBookV2(root, 'books/o00012/o00012.v1.json.gz', autoBook());
      buildCatalogV2(root, date: '2026-10-16', tagsById: const {});
      expect(validateLibraryV2(root).errors.map((i) => i.code), contains('file_name'));
    });
  });

  test('عمود الوسوم في ملف الاختيار', () {
    final s = parseSelectionTsv('${selectionColumns.join('\t')}\n'
        'include\ttags: x\t0300A.K.X-ara1\t0300A.K\t\t300\t1\tك\tم\tK\tA\tdata/x\tJK@كتب التاريخ::GAL@history\n');
    expect(s.single.tags, ['JK@كتب التاريخ', 'GAL@history']);
    expect(parseSelectionTsv('decision\tversion_uri\ninclude\tx\n').single.tags, isEmpty);
  });
}
