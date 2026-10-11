import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Response _json(Object o) => http.Response.bytes(utf8.encode(jsonEncode(o)), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, Object?> _page(String title, int revid, String text) => {
      'title': title,
      'revisions': [
        {
          'revid': revid,
          'slots': {
            'main': {'content': text},
          },
        },
      ],
    };

void main() {
  test('subpageLinks: الصفحات الفرعية بترتيب ظهورها بلا تكرار', () {
    const root = '* [[/الباب الأول|١]]\n* [[كتاب س/الباب الثاني]]\n* [[كتاب س/الباب الأول]]\n* [[كتاب آخر]]';
    expect(subpageLinks('كتاب س', root), ['كتاب س/الباب الأول', 'كتاب س/الباب الثاني']);
  });

  test('fetchRecipe يثبّت المراجعات في المسودة ويخزّن النصوص، والتشغيل التالي يستخدم المثبّت', () async {
    final tmp = Directory.systemTemp.createTempSync('adeeb_fetch_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final requests = <Uri>[];
    final client = MockClient((req) async {
      requests.add(req.url);
      expect(req.headers['User-Agent'], userAgent);
      final q = req.url.queryParameters;
      if (q['titles'] == 'كتاب س') return _json({'query': {'pages': [_page('كتاب س', 10, '[[/أ]] [[/ب]]')]}});
      if (q['titles'] == 'كتاب س/أ') return _json({'query': {'pages': [_page('كتاب س/أ', 11, 'نص أ')]}});
      if (q['titles'] == 'كتاب س/ب') return _json({'query': {'pages': [_page('كتاب س/ب', 12, 'نص ب')]}});
      if (q['revids'] == '11|12') {
        return _json({'query': {'pages': [_page('كتاب س/أ', 11, 'نص أ'), _page('كتاب س/ب', 12, 'نص ب')]}});
      }
      return http.Response('not found', 404);
    });
    final recipeFile = File('${tmp.path}/r.json');
    final draft = Recipe(
      id: 'sin', version: 1, titleAr: 'س', titleEn: 'S', authorAr: 'م', authorEn: 'A',
      authorDeathHijri: 1, wiki: 'ar.wikisource.org', rootPage: 'كتاب س', pages: [],
      license: 'public-domain', removed: 'لا شيء',
    );
    final cache = Directory('${tmp.path}/cache');
    final texts = await fetchRecipe(
        recipe: draft, recipeFile: recipeFile, cacheDir: cache, client: client, today: '2026-10-11');
    expect(texts, {11: 'نص أ', 12: 'نص ب'});
    final pinned = Recipe.load(recipeFile);
    expect(pinned.isPinned, isTrue);
    expect(pinned.retrieved, '2026-10-11');
    expect(pinned.pages.map((p) => '${p.title}#${p.revid}'), ['كتاب س/أ#11', 'كتاب س/ب#12']);

    // تشغيل ثانٍ بوصفة مثبّتة وذاكرة فارغة: يطلب المراجعات المثبّتة نفسها فقط.
    cache.deleteSync(recursive: true);
    requests.clear();
    final again = await fetchRecipe(
        recipe: pinned, recipeFile: recipeFile, cacheDir: cache, client: client, today: '2099-01-01');
    expect(again, texts);
    expect(requests.single.queryParameters['revids'], '11|12');
    expect(Recipe.load(recipeFile).retrieved, '2026-10-11');
  });

  test('خطأ HTTP يُرفع برسالة عربية ولا يُنتج نصاً', () async {
    final f = WikiFetcher(MockClient((_) async => http.Response('', 403)), 'ar.wikisource.org');
    await expectLater(
      f.latest('x'),
      throwsA(isA<WikiFetchException>()
          .having((e) => e.network, 'network', isFalse)
          .having((e) => e.message, 'message', contains('HTTP 403'))),
    );
  });

  test('انقطاع الشبكة: WikiFetchException(network) برسالة عربية', () async {
    final f = WikiFetcher(
        MockClient((_) async => throw http.ClientException('Connection refused')), 'ar.wikisource.org');
    await expectLater(
      f.latest('x'),
      throwsA(isA<WikiFetchException>()
          .having((e) => e.network, 'network', isTrue)
          .having((e) => e.message, 'message', contains('تعذّر الاتصال'))),
    );
  });

  test('maxlag: إعادة محاولة محدودة بمهلة Retry-After ثم النجاح', () async {
    var calls = 0;
    final waits = <Duration>[];
    final client = MockClient((_) async {
      calls++;
      if (calls < 3) {
        return http.Response.bytes(utf8.encode(jsonEncode({'error': {'code': 'maxlag', 'info': 'lag'}})), 200,
            headers: {'retry-after': '2'});
      }
      return _json({'query': {'pages': [_page('س', 5, 'نص')]}});
    });
    final f = WikiFetcher(client, 'ar.wikisource.org', sleep: (d) async => waits.add(d));
    final r = await f.latest('س');
    expect(r.revid, 5);
    expect(calls, 3);
    expect(waits, [const Duration(seconds: 2), const Duration(seconds: 2)]);
  });

  test('maxlag مستمر: يتوقف بعد الحد بخطأ', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response.bytes(utf8.encode(jsonEncode({'error': {'code': 'maxlag'}})), 503);
    });
    final f = WikiFetcher(client, 'ar.wikisource.org', maxRetries: 2, sleep: (_) async {});
    await expectLater(f.latest('س'), throwsA(isA<WikiFetchException>()));
    expect(calls, 3);
  });
}
