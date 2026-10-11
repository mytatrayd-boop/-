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
      'testbook-b001|1|الباب الأول',
      'testbook-b002|2|أول الكتاب',
      'testbook-b003|1|الباب الثاني: في الشعر',
      'testbook-b004|1|الباب الثالث',
      'testbook-b005|2|فصل فرعي',
    ]);
    final all = paragraphsOf(book).toList();
    final joined = all.map((p) => p['text']).join('\n');
    expect(joined, isNot(contains('محقق')));
    expect(joined, isNot(contains('حاشية')));
    expect(joined, isNot(contains('عنوان')));
    expect(joined, isNot(contains('تصنيف')));
    expect(all.first, {
      'id': 'testbook-b002-p00001',
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
    expect(RegExp(r'`testbook-b\d{3}-p\d{5}`').allMatches(a), hasLength(5));
  });

  test('العيّنة: العدد الافتراضي 20 (أو كل الفقرات إن قلّت) وقسم التحذيرات', () {
    final texts = fixtureTexts();
    texts[103] = '${texts[103]}\nمضى من عمره (١٥) سنة.';
    final book = buildBook(fixtureRecipe(), texts).book;
    final md = buildSampleMarkdown(book, seed: 1);
    expect(defaultSampleCount, 20);
    expect(RegExp(r'^## \d+\. ', multiLine: true).allMatches(md), hasLength(11));
    expect(md, contains('## تحذيرات للمراجعة (1)'));
    expect(md, contains('[footnote_paren_number]'));
    expect(md, contains('فيها تحذير'));
  });

  test('redirects في الوصفة تُنسخ إلى الكتاب مرتبة', () {
    final j = jsonDecode(File('${fixtures.path}/recipe.json').readAsStringSync()) as Map<String, Object?>;
    j['redirects'] = {'testbook-b009-p00001': 'testbook-b002-p00001'};
    final book = buildBook(Recipe.fromJson(j), fixtureTexts()).book;
    expect(book['redirects'], {'testbook-b009-p00001': 'testbook-b002-p00001'});
    expect(validateBook(book, 't'), isEmpty);
  });

  test('ثبات المعرّفات بين الإصدارات: المفقود من v1 بلا redirect خطأ', () {
    runOnce(tmp);
    final j = jsonDecode(File('${fixtures.path}/recipe.json').readAsStringSync()) as Map<String, Object?>;
    j['version'] = 2;
    final texts = fixtureTexts();
    texts[103] = texts[103]!.replaceFirst('فقرة في فصل فرعي.', '');
    convertToLibrary(Recipe.fromJson(j), texts, tmp);
    buildCatalog(tmp, date: '2026-10-12');
    final lost = validateLibrary(tmp).issues.where((i) => i.code == 'lost_id').toList();
    expect(lost, hasLength(1));
    expect(lost.single.detail, contains('testbook-b005-p00003'));

    // مع redirects للمعرّف المفقود: لا خطأ.
    j['redirects'] = {'testbook-b005-p00003': 'testbook-b005-p00002'};
    convertToLibrary(Recipe.fromJson(j), texts, tmp, overwrite: true);
    buildCatalog(tmp, date: '2026-10-12');
    expect(validateLibrary(tmp).issues, isEmpty);
  });

  test('المقارنة على JSON بعد فك الضغط: gzip مختلف لنفس المحتوى ليس تغييراً', () {
    runOnce(tmp);
    final f = File('${tmp.path}/books/testbook/testbook.v1.json.gz');
    final json = gzip.decode(f.readAsBytesSync());
    final other = GZipCodec(level: 1).encode(json); // بايتات مضغوطة مختلفة، محتوى واحد
    f.writeAsBytesSync(other);
    final out = convertToLibrary(fixtureRecipe(), fixtureTexts(), tmp);
    expect(out.gz, other, reason: 'لا يُستبدل الملف المنشور ما دام المحتوى نفسه');
  });

  test('validateLibrary يقرأ validation_exceptions من tools/recipes', () {
    final texts = fixtureTexts();
    texts[103] = '${texts[103]}\nانظر باب٢ من هذا الكتاب.';
    convertToLibrary(fixtureRecipe(), texts, tmp);
    buildCatalog(tmp, date: '2026-10-11');
    expect(validateLibrary(tmp).issues.map((i) => i.code), ['footnote_attached_number']);
    final recipes = Directory('${tmp.path}/tools/recipes')..createSync(recursive: true);
    final j = jsonDecode(File('${fixtures.path}/recipe.json').readAsStringSync()) as Map<String, Object?>;
    j['validation_exceptions'] = {
      'testbook-b006-p00001': ['footnote_attached_number'],
    };
    File('${recipes.path}/testbook.json').writeAsStringSync(jsonEncode(j));
    expect(validateLibrary(tmp).issues, isEmpty);
  });

  Map<String, Object?> recipeJson(int version, [Map<String, String> redirects = const {}]) {
    final j = jsonDecode(File('${fixtures.path}/recipe.json').readAsStringSync()) as Map<String, Object?>;
    j['version'] = version;
    j['redirects'] = redirects;
    return j;
  }

  test('سقوط سلسلة التحويل: v1 فقرة، v2 تحويل، v3 بلا تحويل = lost_id', () {
    final full = fixtureTexts();
    final cut = fixtureTexts();
    cut[103] = cut[103]!.replaceFirst('فقرة في فصل فرعي.', '');
    convertToLibrary(Recipe.fromJson(recipeJson(1)), full, tmp);
    convertToLibrary(
        Recipe.fromJson(recipeJson(2, {'testbook-b005-p00003': 'testbook-b005-p00002'})), cut, tmp);
    buildCatalog(tmp, date: '2026-10-11');
    expect(validateLibrary(tmp).issues, isEmpty, reason: 'v2 يحوّل المعرّف المفقود');

    convertToLibrary(Recipe.fromJson(recipeJson(3)), cut, tmp);
    buildCatalog(tmp, date: '2026-10-12');
    final issues = validateLibrary(tmp).issues;
    expect(issues.map((i) => '${i.where}|${i.code}'), ['books/testbook/testbook.v3.json.gz|lost_id']);
    expect(issues.single.detail, contains('testbook-b005-p00003'));
  });

  test('إعادة الاستخدام: معرّف حُوِّل في v2 ثم عاد فقرة في v4 = reused_id', () {
    final full = fixtureTexts();
    // v2 و v3: الفقرة الأولى من الباب الثاني تُحذف فيتحول ترقيم الباب، مع تحويل المعرّف الأخير المفقود.
    final shifted = fixtureTexts();
    shifted[101] = shifted[101]!.replaceFirst(RegExp(r'هذه .*?بمسافة\.', dotAll: true), '');
    const red = {'testbook-b002-p00003': 'testbook-b002-p00002'};
    convertToLibrary(Recipe.fromJson(recipeJson(1)), full, tmp);
    convertToLibrary(Recipe.fromJson(recipeJson(2, red)), shifted, tmp);
    convertToLibrary(Recipe.fromJson(recipeJson(3, red)), shifted, tmp);
    buildCatalog(tmp, date: '2026-10-11');
    expect(validateLibrary(tmp).issues, isEmpty);

    // v4 يعيد المحتوى الأصلي فيعود testbook-b002-p00003 فقرةً بعد أن كان مفتاح تحويل.
    convertToLibrary(Recipe.fromJson(recipeJson(4)), full, tmp);
    buildCatalog(tmp, date: '2026-10-12');
    final issues = validateLibrary(tmp).issues;
    expect(issues.map((i) => '${i.where}|${i.code}'), ['books/testbook/testbook.v4.json.gz|reused_id']);
    expect(issues.single.detail, contains('testbook-b002-p00003'));
  });
}
