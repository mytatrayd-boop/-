// الاستخدام (من library/tools): dart run bin/fetch.dart recipes/<id>.json
// يجلب نص الويكي إلى .cache/<id>/ ويثبّت المراجعات في الوصفة إن كانت مسودة.
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('الاستخدام: dart run bin/fetch.dart recipes/<id>.json');
    exit(64);
  }
  final recipeFile = File(args[0]);
  final recipe = Recipe.load(recipeFile);
  final cache = Directory('${recipeFile.absolute.parent.parent.path}/.cache/${recipe.id}');
  final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final client = http.Client();
  try {
    final texts = await fetchRecipe(
      recipe: recipe,
      recipeFile: recipeFile,
      cacheDir: cache,
      client: client,
      today: today,
    );
    stdout.writeln('جُلبت ${texts.length} صفحة إلى ${cache.path} (retrieved=${recipe.retrieved}).');
    for (final p in recipe.pages) {
      stdout.writeln('  ${p.skip ? '[تجاهل] ' : ''}${p.title}  revid=${p.revid}');
    }
  } on WikiFetchException catch (e) {
    stderr.writeln('فشل الجلب: ${e.message}');
    stderr.writeln(e.network
        ? 'تحقق من الاتصال بالإنترنت ومن السماح بالمضيف ${recipe.wiki}، ثم أعد التشغيل. لم يُكتب أي نص.'
        : 'لم يُكتب أي نص. أعد المحاولة لاحقاً أو راجع الوصفة.');
    exitCode = e.network ? 69 : 70; // EX_UNAVAILABLE / EX_SOFTWARE
  } finally {
    client.close();
  }
}
