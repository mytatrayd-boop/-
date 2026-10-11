import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('adeeb_lib_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, List<int>> runOnce(Directory root) {
    final out = convertToLibrary(fixtureRecipe(), fixtureTexts(), root);
    buildCatalog(root, date: '2026-10-11');
    return {
      'book': out.file.readAsBytesSync(),
      'catalog': File('${root.path}/catalog.json').readAsBytesSync(),
    };
  }

  test('الحتمية: تشغيلان مستقلان = ملفان متطابقان بايتاً ببايت', () {
    final a = runOnce(Directory('${tmp.path}/a')..createSync());
    final b = runOnce(Directory('${tmp.path}/b')..createSync());
    expect(a['book'], b['book']);
    expect(a['catalog'], b['catalog']);
  });

  test('إعادة التشغيل في المكان نفسه لا تغيّر الكتاب ولا الفهرس (ولا catalog_version)', () {
    final first = runOnce(tmp);
    final second = runOnce(tmp);
    expect(second['book'], first['book']);
    expect(second['catalog'], first['catalog']);
    final cat = jsonDecode(utf8.decode(second['catalog']!)) as Map;
    expect(cat['catalog_version'], 1);
  });

  test('المخرَج يجتاز المدقق، والبنية والمحتوى كما هو متوقع', () {
    runOnce(tmp);
    final report = validateLibrary(tmp);
    expect(report.issues, isEmpty);
    expect(report.books, 1);

    final book = decodeGzJson(File('${tmp.path}/books/testbook/testbook.v1.json.gz').readAsBytesSync());
    final chapters = (book['chapters']! as List).cast<Map<String, Object?>>();
    expect(chapters.map((c) => '${c['id']}|${c['level']}|${c['title']}').toList(), [
      'testbook-b01|1|الباب الأول',
      'testbook-b02|2|أول الكتاب',
      'testbook-b03|1|الباب الثاني: في الشعر',
      'testbook-b04|1|الباب الثالث',
      'testbook-b05|2|فصل فرعي',
    ]);
    final all = paragraphsOf(book).toList();
    final joined = all.map((p) => p['text']).join('\n');
    expect(joined, isNot(contains('محقق')));
    expect(joined, isNot(contains('حاشية')));
    expect(joined, isNot(contains('عنوان')));
    expect(joined, isNot(contains('تصنيف')));
    expect(all.first, {
      'id': 'testbook-b02-p0001',
      'text': 'هذه فقرة تجريبية أولى، كُتبت لاختبار الأداة فقط. وهذا سطر ثانٍ في الفقرة نفسها يُضمّ إليها بمسافة.',
    });
    expect(all[1]['text'], 'نَصٌّ مَشْكُولٌ لِلِاخْتِبَارِ، فيه رابط وصفحة أخرى.');
    final verses = all.where((p) => p['kind'] == 'verse').toList();
    expect(verses.map((v) => v['text']), [
      'الشطر الأول من البيت الأول\tالشطر الثاني من البيت الأول\n'
          'الشطر الأول من البيت الثاني\tالشطر الثاني من البيت الثاني',
      'صدر بيت بالقالب\tعجز بيت بالقالب\nصدر بيت ثانٍ\tعجز بيت ثانٍ',
    ]);
    expect((book['source']! as Map)['revisions'], [101, 102, 103]);
  });

  test('الفهرس يطابق الملف (sha256 والأحجام والعدد)', () {
    runOnce(tmp);
    final cat = jsonDecode(File('${tmp.path}/catalog.json').readAsStringSync()) as Map<String, Object?>;
    final e = (cat['books']! as List).single as Map<String, Object?>;
    expect(e['file'], 'books/testbook/testbook.v1.json.gz');
    expect(e['paragraph_count'], 10);
    expect(e['diacritics'], 'partial');
    expect(e['title'], {'ar': 'كتاب الاختبار', 'en': 'Test Book'});
  });

  test('المدقق يكشف عبث الملف بعد بناء الفهرس', () {
    runOnce(tmp);
    final f = File('${tmp.path}/books/testbook/testbook.v1.json.gz');
    final book = decodeGzJson(f.readAsBytesSync());
    final c = ((book['chapters']! as List)[1] as Map)['paragraphs']! as List;
    (c[0] as Map)['text'] = 'نص مع حاشية [1]';
    f.writeAsBytesSync(gzipDeterministic(encodeBookJson(book)));
    final codes = validateLibrary(tmp).issues.map((i) => i.code).toSet();
    expect(codes, containsAll(['sha256', 'footnote_bracket_number']));
  });

  test('تغيير المصدر يرفع catalog_version، والإصدار المنشور لا يُستبدل بلا --overwrite', () {
    runOnce(tmp);
    final texts = fixtureTexts();
    texts[103] = '${texts[103]}\nفقرة جديدة.';
    expect(() => convertToLibrary(fixtureRecipe(), texts, tmp), throwsStateError);
    convertToLibrary(fixtureRecipe(), texts, tmp, overwrite: true);
    buildCatalog(tmp, date: '2026-10-12');
    final cat = jsonDecode(File('${tmp.path}/catalog.json').readAsStringSync()) as Map;
    expect(cat['catalog_version'], 2);
    expect(cat['updated'], '2026-10-12');
  });

  test('تصنيف التشكيل', () {
    expect(classifyDiacritics(['نَصٌّ مَشْكُولٌ']), 'full');
    expect(classifyDiacritics(['نص بلا تشكيل في أغلبه إلا حرفاً واحداً: بَ']), 'partial');
    expect(classifyDiacritics(['نص بلا تشكيل']), 'none');
  });

  test('مكتبة بلا فهرس تفشل في التحقق', () {
    expect(validateLibrary(tmp).issues.map((i) => i.code), contains('missing'));
  });

  test('العيّنة حتمية بالبذرة وتحوي المعرّفات', () {
    runOnce(tmp);
    final book = decodeGzJson(File('${tmp.path}/books/testbook/testbook.v1.json.gz').readAsBytesSync());
    final a = buildSampleMarkdown(book, count: 5, seed: 7);
    expect(buildSampleMarkdown(book, count: 5, seed: 7), a);
    expect(RegExp(r'`testbook-b\d\d-p\d{4}`').allMatches(a), hasLength(5));
  });
}
