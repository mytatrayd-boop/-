/// جلب نص الويكي من ويكي مصدر عبر MediaWiki Action API.
/// - مسودة الوصفة (بلا revid): تُكتشف الصفحات الفرعية من روابط الصفحة الجذر
///   بترتيب ظهورها، وتُثبَّت أحدث مراجعة لكل صفحة مع تاريخ الجلب.
/// - وصفة مثبّتة: تُجلب المراجعات المثبّتة نفسها دائماً (نتيجة حتمية).
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'recipe.dart';

const userAgent =
    'AdeebLibraryTools/0.1 (https://github.com/mytatrayd-boop/-; heritage text converter)';

/// فشل الجلب برسالة عربية واضحة. [network] = تعذّر الاتصال أصلاً.
class WikiFetchException implements Exception {
  WikiFetchException(this.message, {this.network = false});
  final String message;
  final bool network;
  @override
  String toString() => message;
}

class WikiFetcher {
  WikiFetcher(this.client, this.wiki, {this.maxRetries = 3, Future<void> Function(Duration)? sleep})
      : _sleep = sleep ?? Future<void>.delayed;
  final http.Client client;
  final String wiki;

  /// عدد إعادات المحاولة عند maxlag (تأخر خوادم ويكيميديا) فقط.
  final int maxRetries;
  final Future<void> Function(Duration) _sleep;

  Future<Map<String, Object?>> _api(Map<String, String> params) async {
    final uri = Uri.https(wiki, '/w/api.php', {
      ...params,
      'format': 'json',
      'formatversion': '2',
      'maxlag': '5',
    });
    for (var attempt = 0;; attempt++) {
      http.Response res;
      try {
        res = await client.get(uri, headers: {'User-Agent': userAgent});
      } on http.ClientException catch (e) {
        throw WikiFetchException('تعذّر الاتصال بـ $wiki (انقطاع الشبكة أو حجب الوكيل): ${e.message}',
            network: true);
      } on SocketException catch (e) {
        throw WikiFetchException('تعذّر الاتصال بـ $wiki (انقطاع الشبكة): ${e.message}', network: true);
      }
      Map<String, Object?>? j;
      try {
        j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>;
      } on Object {
        j = null;
      }
      final error = j?['error'];
      final isMaxlag = error is Map && error['code'] == 'maxlag';
      if (isMaxlag) {
        if (attempt >= maxRetries) {
          throw WikiFetchException('خوادم $wiki مشغولة (maxlag) بعد ${maxRetries + 1} محاولات؛ أعد المحاولة لاحقاً.');
        }
        final wait = int.tryParse(res.headers['retry-after'] ?? '') ?? 5;
        await _sleep(Duration(seconds: wait.clamp(1, 60)));
        continue;
      }
      if (res.statusCode != 200) {
        throw WikiFetchException('ردّ $wiki بالرمز HTTP ${res.statusCode} للطلب $uri');
      }
      if (j == null) throw WikiFetchException('ردّ غير صالح (ليس JSON) من $wiki');
      if (error != null) throw WikiFetchException('خطأ من واجهة $wiki: $error');
      return j;
    }
  }

  /// أحدث مراجعة لصفحة: (revid, wikitext, العنوان بعد التحويلات).
  Future<({int revid, String text, String title})> latest(String title) async {
    final j = await _api({
      'action': 'query',
      'prop': 'revisions',
      'titles': title,
      'redirects': '1',
      'rvprop': 'ids|content',
      'rvslots': 'main',
    });
    final pages = ((j['query']! as Map)['pages']! as List).cast<Map<String, Object?>>();
    final p = pages.single;
    if (p['missing'] == true) throw WikiFetchException('الصفحة غير موجودة: $title');
    final rev = (p['revisions']! as List).cast<Map<String, Object?>>().single;
    final slot = (rev['slots']! as Map)['main']! as Map;
    return (revid: rev['revid']! as int, text: slot['content']! as String, title: p['title']! as String);
  }

  /// نصوص مراجعات محددة (حتى 50 في الطلب).
  Future<Map<int, String>> revisions(List<int> revids) async {
    final out = <int, String>{};
    for (var i = 0; i < revids.length; i += 50) {
      final chunk = revids.sublist(i, i + 50 > revids.length ? revids.length : i + 50);
      final j = await _api({
        'action': 'query',
        'prop': 'revisions',
        'revids': chunk.join('|'),
        'rvprop': 'ids|content',
        'rvslots': 'main',
      });
      final pages = ((j['query']! as Map)['pages']! as List).cast<Map<String, Object?>>();
      for (final p in pages) {
        for (final rev in ((p['revisions'] as List?) ?? const []).cast<Map<String, Object?>>()) {
          final slot = (rev['slots']! as Map)['main']! as Map;
          out[rev['revid']! as int] = slot['content']! as String;
        }
      }
      for (final r in chunk) {
        if (!out.containsKey(r)) throw WikiFetchException('المراجعة $r غير متاحة');
      }
    }
    return out;
  }
}

/// روابط الصفحات الفرعية للجذر بترتيب ظهورها (بلا تكرار).
List<String> subpageLinks(String rootTitle, String rootWikitext) {
  final out = <String>[];
  final seen = <String>{};
  final re = RegExp(r'\[\[([^\[\]|#]+)(?:#[^\[\]|]*)?(?:\|[^\[\]]*)?\]\]');
  final root = rootTitle.replaceAll('_', ' ').trim();
  for (final m in re.allMatches(rootWikitext)) {
    var t = m[1]!.replaceAll('_', ' ').trim();
    if (t.startsWith('/')) t = '$root$t';
    t = t.replaceFirst(RegExp(r'/+$'), '');
    if (t.startsWith('$root/') && seen.add(t)) out.add(t);
  }
  return out;
}

/// يجلب نصوص الوصفة إلى [cacheDir] (ملف لكل revid). إن كانت الوصفة مسودة
/// يثبّتها أولاً ويحفظها في [recipeFile]. [today] تاريخ الجلب YYYY-MM-DD.
Future<Map<int, String>> fetchRecipe({
  required Recipe recipe,
  required File recipeFile,
  required Directory cacheDir,
  required http.Client client,
  required String today,
}) async {
  final f = WikiFetcher(client, recipe.wiki);
  final texts = <int, String>{};
  if (!recipe.isPinned) {
    final root = await f.latest(recipe.rootPage);
    if (recipe.pages.isEmpty) {
      final subs = subpageLinks(root.title, root.text);
      if (subs.isEmpty) {
        recipe.pages.add(RecipePage(title: root.title, revid: root.revid));
        texts[root.revid] = root.text;
      } else {
        for (final s in subs) {
          recipe.pages.add(RecipePage(title: s));
        }
      }
    }
    for (final p in recipe.pages) {
      if (p.revid != null) continue;
      final r = await f.latest(p.title);
      p.revid = r.revid;
      texts[r.revid] = r.text;
    }
    recipe.retrieved = today;
    recipe.save(recipeFile);
  }
  final needed = [
    for (final p in recipe.pages)
      if (!p.skip && !texts.containsKey(p.revid) && !File('${cacheDir.path}/${p.revid}.wiki').existsSync()) p.revid!,
  ];
  if (needed.isNotEmpty) texts.addAll(await f.revisions(needed));
  cacheDir.createSync(recursive: true);
  texts.forEach((rev, t) => File('${cacheDir.path}/$rev.wiki').writeAsStringSync(t));
  return loadCache(recipe, cacheDir);
}

Map<int, String> loadCache(Recipe recipe, Directory cacheDir) {
  final out = <int, String>{};
  for (final p in recipe.pages) {
    if (p.skip) continue;
    final f = File('${cacheDir.path}/${p.revid}.wiki');
    if (!f.existsSync()) throw StateError('غير موجود في الذاكرة المؤقتة: ${f.path} — شغّل fetch.');
    out[p.revid!] = f.readAsStringSync();
  }
  return out;
}
