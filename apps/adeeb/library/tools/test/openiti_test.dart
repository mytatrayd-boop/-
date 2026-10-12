// اختبارات قارئ OpenITI mARkdown (D21) وفكّ أشكال العرض. النصوص اصطناعية للاختبار.
import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _header = '######OpenITI#\n\n#META# 020.BookTITLE\t:: كتاب\n#META#Header#End#\n';

OpenitiRecipe recipeFor(String body, [Map<String, Object?> extra = const {}]) {
  final bytes = utf8.encode(_header + body);
  return OpenitiRecipe.fromJson({
    'format': 'openiti',
    'id': 'testbook',
    'version': 1,
    'title': {'ar': 'كتاب الاختبار', 'en': 'Test'},
    'author': {'ar': 'مؤلف', 'en': 'Author'},
    'author_death_hijri': 100,
    'openiti': {
      'repo': 'OpenITI/0100AH',
      'commit': 'a' * 40,
      'path': 'data/x/y.txt',
      'uri': 'X.Y.Test-ara1',
      'sha256': sha256.convert(bytes).toString(),
    },
    'retrieved': '2026-10-12',
    'license': 'CC BY-NC-SA 4.0',
    'removed': 'اختبار',
    ...extra,
  });
}

BuildResult build(String body, [Map<String, Object?> extra = const {}, RemovalStats? out]) {
  final r = recipeFor(body, extra);
  final res = buildOpenitiBook(r, utf8.encode(_header + body));
  out?.merge(res.stats);
  return res;
}

List<Map<String, Object?>> paras(BuildResult r) =>
    [for (final c in r.chapters) ...(c['paragraphs']! as List).cast<Map<String, Object?>>()];

List<String> toc(BuildResult r) => [for (final c in r.chapters) '${c['level']}:${c['title']}'];

Matcher throwsOpeniti([String? text]) =>
    throwsA(isA<WikitextException>().having((e) => e.message, 'message', text == null ? anything : contains(text)));

void main() {
  group('الترويسة', () {
    test('السطر الأول يجب أن يكون ######OpenITI#', () {
      final r = recipeFor('');
      final bytes = utf8.encode('# نص\n');
      final bad = OpenitiRecipe.fromJson({...r.toJson(), 'openiti': {...(r.toJson()['openiti']! as Map), 'sha256': sha256.convert(bytes).toString()}});
      expect(() => buildOpenitiBook(bad, bytes), throwsOpeniti('######OpenITI#'));
    });
    test('سطر مجهول في الترويسة خطأ', () {
      final body = '';
      final src = '######OpenITI#\nسطر غريب\n#META#Header#End#\n$body';
      final r = recipeFor(body);
      final j = r.toJson();
      (j['openiti']! as Map)['sha256'] = sha256.convert(utf8.encode(src)).toString();
      expect(() => buildOpenitiBook(OpenitiRecipe.fromJson(j), utf8.encode(src)), throwsOpeniti('ترويسة'));
    });
  });

  group('العناوين والفقرات', () {
    test('# فقرة و~~ سطر ملحق، والمستوى بعدد |، وأعمق من 3 يصير 3', () {
      final r = build('### | باب أول\n# سطر أول\n~~تتمته.\n### || فصل\n# فقرة.\n### |||| عميق\n# نص.\n');
      expect(toc(r), ['1:باب أول', '2:فصل', '3:عميق']);
      expect(paras(r).map((p) => p['text']), ['سطر أول تتمته.', 'فقرة.', 'نص.']);
      expect(r.chapters.first['id'], 'testbook-b001');
      expect(paras(r).first['id'], 'testbook-b001-p00001');
    });
    test('قسم PARATEXT يُحذف حتى العنوان التالي، ووسم قسم مجهول خطأ', () {
      final st = RemovalStats();
      final r = build('### | باب\n# نص.\n### |PARATEXT|\n# تم الكتاب.\n### | باب ثان\n# نص ثان.\n', {}, st);
      expect(paras(r).map((p) => p['text']), ['نص.', 'نص ثان.']);
      expect(st.counts['قسم محذوف بوسم OpenITI |PARATEXT|'], 1);
      expect(() => build('### |FOO|\n# نص.\n'), throwsOpeniti('|FOO|'));
    });
    test('بداية سطر مجهولة وعنوان بوسم غير مدعوم خطأ', () {
      expect(() => build('### | باب\nنص بلا وسم\n'), throwsOpeniti('بداية سطر'));
      expect(() => build('### \$ ترجمة\n# نص.\n'), throwsOpeniti('عنوان'));
    });
    test('~~ بلا فقرة قبله خطأ', () {
      expect(() => build('### | باب\n~~نص\n'), throwsOpeniti('~~'));
    });
    test('نص قبل أول عنوان يحتاج preface_title', () {
      expect(() => build('# نص.\n'), throwsOpeniti('preface_title'));
      expect(toc(build('# نص.\n', {'preface_title': 'تمهيد'})), ['1:تمهيد']);
    });
  });

  group('علامات الصفحات والمعالم', () {
    test('العلامة في نهاية الصفحة: الفقرة تأخذ صفحة بدايتها، والمعالم تُحذف', () {
      final st = RemovalStats();
      final r = build(
        '### | باب\n# أول ms1 نص.\n# ثان. PageV01P009\n# ثالث يمتد PageV01P010 إلى صفحة أخرى.\nPageV01P011\n# PageV01P012\n',
        {},
        st,
      );
      expect(paras(r).map((p) => '${p['page']}|${p['text']}'), [
        'V01P009|أول نص.',
        'V01P009|ثان.',
        'V01P010|ثالث يمتد إلى صفحة أخرى.',
      ]);
      expect(st.counts['علامة مَعلَم ms (حُذفت)'], 1);
      expect(st.counts['علامة صفحة (حُفظت في page)'], 4);
    });
    test('فقرة بعد آخر علامة بلا page', () {
      final p = paras(build('### | باب\n# نص. PageV01P001\n# أخير.\n'));
      expect(p.last.containsKey('page'), isFalse);
    });
    test('merge_page_breaks: يوصل ما شقّه حدّ الصفحة إن لم تنته الفقرة بعلامة وقف', () {
      const body = '### | باب\n# جملة لم\n# PageV01P001\n# تنته بعد.\n# PageV01P002\n# فقرة جديدة.\n';
      final st = RemovalStats();
      final merged = build(body, {'merge_page_breaks': true}, st);
      expect(paras(merged).map((p) => '${p['page']}|${p['text']}'), [
        'V01P001|جملة لم تنته بعد.',
        'null|فقرة جديدة.',
      ]);
      expect(st.counts['فقرة موصولة عبر حدّ الصفحة'], 1);
      expect(paras(build(body)).length, 3);
    });
  });

  group('الشعر', () {
    test('الأبيات المتتالية فقرة شعر واحدة، والشطر الفارغ يُعدّ', () {
      final st = RemovalStats();
      final r = build('### | باب\n# قال:\n# صدر أ %~% عجز أ\n# صدر ب %~% عجز ب PageV01P001\n# %~% شطر وحيد\n# نثر.\n', {}, st);
      final p = paras(r);
      expect(p[1], {'id': 'testbook-b001-p00002', 'kind': 'verse', 'text': 'صدر أ\tعجز أ\nصدر ب\tعجز ب\nشطر وحيد', 'page': 'V01P001'});
      expect(p[2]['text'], 'نثر.');
      expect(st.counts['شطر فارغ حول %~% (بيت بشطر واحد)'], 1);
    });
    test('أكثر من شطرين خطأ، وبيت ممتد على سطرين خطأ', () {
      expect(() => build('### | باب\n# أ %~% ب %~% ج\n'), throwsOpeniti('شطرين'));
      expect(() => build('### | باب\n# أ\n~~ب %~% ج\n'), throwsOpeniti('%~%'));
    });
    test('سطر نثر ~~ بعد بيت يصير فقرة جديدة', () {
      final r = build('### | باب\n# صدر %~% عجز\n~~PageV01P001\n~~نثر بعده.\n');
      expect(paras(r).map((p) => p['kind'] ?? 'prose'), ['verse', 'prose']);
    });
  });

  group('الوسوم المجهولة وقواعد الوصفة', () {
    test('وسم مجهول يوقف التحويل ولا يُحذف بصمت', () {
      expect(() => build('### | باب\n# نص <span>x</span>\n'), throwsOpeniti('<'));
      expect(() => build('### | باب\n# نص @QB@ آخر\n'), throwsOpeniti('@'));
      expect(() => build('### | باب\n# نص {آية}\n'), throwsOpeniti('{'));
      expect(() => build('### | باب\n# كلمة abc\n'), throwsOpeniti('a'));
    });
    test('rules (حذف واستبدال بـ \$1) وdrop_lines تُطبَّق وتُعدّ', () {
      final st = RemovalStats();
      final r = build(
        '### | باب\n# نص «1» آخر «2» .\n# ***\n# قال {آية} تمت.\n',
        {
          'rules': [
            {'name': 'رقم حاشية', 'pattern': ' ?«[0-9]+»'},
            {'name': 'قوس', 'pattern': r'\{([^}]*)\}', 'with': r'($1)'},
          ],
          'drop_lines': [
            {'name': 'فاصل', 'pattern': r'# \*\*\*'},
          ],
        },
        st,
      );
      expect(paras(r).map((p) => p['text']), ['نص آخر .', 'قال (آية) تمت.']);
      expect(st.counts['قاعدة: رقم حاشية'], 2);
      expect(st.counts['قاعدة: قوس'], 1);
      expect(st.counts['سطر محذوف: فاصل'], 1);
    });
    test('drop_headings وheading_rules وheading_levels وheadings', () {
      final st = RemovalStats();
      final r = build(
        '### | [الباب الأول\n### | فضل\n# نص.\n### | [عنوان المحقق]\n# تابع.\n### | [فصل في كذا]\n# نص فصل.\n### | قديم\n# نص.\n',
        {
          'drop_headings': [
            {'name': 'معقوف المحقق', 'pattern': r'\[عنوان[^\]]*\]'},
          ],
          'heading_rules': [
            {'name': 'معقوفان', 'pattern': r'[\[\]]'},
          ],
          'heading_levels': [
            {'name': 'فصل', 'pattern': r'\[فصل.*', 'with': '2'},
          ],
          'headings': {
            '[الباب الأول': {'title': 'الباب الأول فضل', 'level': 1},
            'فضل': {'drop': true},
            'قديم': {'title': 'جديد'},
          },
        },
        st,
      );
      expect(toc(r), ['1:الباب الأول فضل', '2:فصل في كذا', '1:جديد']);
      expect(paras(r).map((p) => p['text']).take(2), ['نص.', 'تابع.']);
      expect(st.counts['عنوان محذوف (نصه يبقى في الباب السابق): معقوف المحقق'], 1);
    });
    test('مفتاح headings غير موجود في المصدر خطأ (وصفة قديمة)', () {
      expect(
        () => build('### | باب\n# نص.\n', {
          'headings': {
            'غير موجود': {'title': 'س'},
          },
        }),
        throwsOpeniti('غير موجودة'),
      );
    });
  });

  group('التثبيت والحتمية', () {
    test('sha256 مختلف أو وصفة غير مثبّتة: خطأ', () {
      final r = recipeFor('### | باب\n# نص.\n');
      expect(() => buildOpenitiBook(r, utf8.encode('${_header}x')), throwsStateError);
      final draft = OpenitiRecipe.fromJson({...r.toJson(), 'retrieved': null});
      expect(() => buildOpenitiBook(draft, utf8.encode(_header)), throwsStateError);
    });
    test('commit غير صالح يُرفض', () {
      final j = recipeFor('').toJson();
      (j['openiti']! as Map)['commit'] = 'main';
      expect(() => OpenitiRecipe.fromJson(j), throwsOpeniti('commit'));
    });
    test('تشغيلان = ملف واحد بايتاً ببايت، والناتج يجتاز المدقق مع page', () {
      const body = '### | باب\n# نص ms1 أول. PageV01P001\n# صدر %~% عجز\n# نص. PageV01P002\n';
      final tmp = Directory.systemTemp.createTempSync('adeeb_openiti_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      List<int> run(String sub) {
        final root = Directory('${tmp.path}/$sub')..createSync();
        final out = writeBookToLibrary(build(body), 'testbook', 1, root);
        buildCatalog(root, date: '2026-10-12');
        final rep = validateLibrary(root, exceptions: const {});
        expect(rep.issues, isEmpty);
        return out.file.readAsBytesSync();
      }

      expect(run('a'), run('b'));
      final book = decodeGzJson(File('${tmp.path}/a/books/testbook/testbook.v1.json.gz').readAsBytesSync());
      final src = book['source']! as Map;
      expect(src['url'], startsWith('https://github.com/OpenITI/0100AH/blob/${'a' * 40}/'));
      expect((src['openiti']! as Map)['uri'], 'X.Y.Test-ara1');
    });
  });

  group('أشكال العرض العربية', () {
    test('تُفكّ إلى حروفها العادية وتُعدّ', () {
      final st = RemovalStats();
      expect(foldPresentationForms('ﻻبد ﷲ ﷺ ﺍﻟﻤ', st), 'لابد الله صلى الله عليه وسلم الم');
      expect(st.counts.values.fold<int>(0, (a, b) => a + b), 6);
      // حركة معزولة تلتصق بحرفها بلا مسافة.
      expect(foldPresentationForms('بﹰ', RemovalStats()), 'بً');
    });
    test('ما لا مقابل قياسياً له خطأ: ﴿ ﴾ ﷽ وU+0620 وU+063B–U+063F', () {
      for (final c in ['﴿', '﴾', '﷽', 'ؠ', 'ػ', 'ؿ']) {
        expect(() => foldPresentationForms('نص $c', RemovalStats()), throwsA(isA<WikitextException>()),
            reason: 'U+${c.codeUnitAt(0).toRadixString(16)}');
      }
    });
    test('قارئ OpenITI يفكّها قبل التحويل', () {
      final st = RemovalStats();
      final r = build('### | باب\n# ﻻبد منه.\n', {}, st);
      expect(paras(r).single['text'], 'لابد منه.');
    });
    test('محوّل ويكي مصدر يفكّها أيضاً (ومن الكيانات)', () {
      final b = WikitextConverter(TemplateRules()).convert('ﻻبد و&#xFEFB;', RemovalStats());
      expect((b.single as ProseBlock).text, 'لابد ولا');
    });
    test('المدقق يرفض أي محرف متبقٍّ منها', () {
      for (final c in ['ﻻ', 'ﷺ', 'ﹰ', 'ؠ', 'ؽ']) {
        final issues = checkParagraphText('نص $c', verse: false, where: 't');
        expect(issues.map((i) => i.code), contains('presentation_form'));
        expect(issues.firstWhere((i) => i.code == 'presentation_form').warning, isFalse);
      }
    });
  });

  group('المدقق', () {
    test('page اختياري بصيغة V01P009', () {
      Map<String, Object?> book(Object? page) => {
            'schema': 1,
            'id': 'testbook',
            'version': 1,
            'title': {'ar': 'ك', 'en': 'B'},
            'author': {'ar': 'م', 'en': 'A'},
            'author_death_hijri': 1,
            'source': {'name': 'OpenITI', 'url': 'https://x', 'retrieved': '2026-10-12'},
            'license': 'x',
            'removed': 'x',
            'chapters': [
              {
                'id': 'testbook-b001',
                'title': 'باب',
                'level': 1,
                'paragraphs': [
                  {'id': 'testbook-b001-p00001', 'text': 'نص.', 'page': page},
                ],
              },
            ],
          };
      expect(validateBook(book('V01P009'), 't'), isEmpty);
      expect(validateBook(book(null), 't'), isEmpty);
      expect(validateBook(book('ص 9'), 't').map((i) => i.code), ['page']);
      expect(validateBook(book(9), 't').map((i) => i.code), ['page']);
    });
    test('«1» خطأ حاشية، و[..] تحذير للمراجعة', () {
      expect(checkParagraphText('نص «1» .', verse: false, where: 't').map((i) => i.code),
          contains('footnote_guillemet_number'));
      final w = checkParagraphText('نص [زيادة] هنا', verse: false, where: 't');
      expect(w.map((i) => i.code), ['square_bracket']);
      expect(w.single.warning, isTrue);
    });
  });

  group('الجلب', () {
    test('مسودة: يثبّت sha256 وretrieved، والجلب التالي يتحقق منهما', () async {
      final tmp = Directory.systemTemp.createTempSync('adeeb_ofetch_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final j = recipeFor('').toJson();
      (j['openiti']! as Map)['sha256'] = null;
      j['retrieved'] = null;
      final f = File('${tmp.path}/r.json')..writeAsStringSync(jsonEncode(j));
      var body = '${_header}# نص\n';
      final urls = <Uri>[];
      final client = MockClient((req) async {
        urls.add(req.url);
        return http.Response.bytes(utf8.encode(body), 200);
      });
      final r = OpenitiRecipe.load(f);
      await fetchOpeniti(recipe: r, recipeFile: f, cacheDir: Directory('${tmp.path}/c'), today: '2026-10-12', client: client);
      expect(urls.single.toString(), 'https://raw.githubusercontent.com/OpenITI/0100AH/${'a' * 40}/data/x/y.txt');
      final saved = OpenitiRecipe.load(f);
      expect(saved.sha256, sha256.convert(utf8.encode(body)).toString());
      expect(saved.retrieved, '2026-10-12');
      expect(openitiCacheFile(Directory('${tmp.path}/c')).readAsStringSync(), body);

      body = '${_header}# نص معدّل\n';
      expect(
        () => fetchOpeniti(recipe: saved, recipeFile: f, cacheDir: Directory('${tmp.path}/c'), today: 'x', client: client),
        throwsA(isA<OpenitiFetchException>().having((e) => e.network, 'network', isFalse)),
      );
    });
    test('انقطاع الشبكة: خطأ network', () async {
      final tmp = Directory.systemTemp.createTempSync('adeeb_ofetch_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final client = MockClient((req) async => throw http.ClientException('blocked'));
      final r = recipeFor('');
      expect(
        () => fetchOpeniti(
            recipe: r, recipeFile: File('${tmp.path}/r.json'), cacheDir: tmp, today: 'x', client: client),
        throwsA(isA<OpenitiFetchException>().having((e) => e.network, 'network', isTrue)),
      );
    });
  });

  test('وصفات المكتبة الفعلية: صيغة openiti مثبّتة (commit وsha256 وretrieved)', () {
    final files = Directory('recipes').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      final r = OpenitiRecipe.load(f);
      expect(r.isPinned, isTrue, reason: f.path);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(r.sha256!), isTrue, reason: f.path);
      expect(r.removed, isNot('TBD'), reason: f.path);
    }
  });
}
