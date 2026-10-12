// الاستخدام (من library/tools):
//   dart run bin/fetch_openiti.dart recipes/<id>.json [--from <مستنسخ محلي للمستودع>]
// يجلب ملف OpenITI بالـ commit المثبّت من raw.githubusercontent.com (أو من مستنسخ محلي
// على الـ commit نفسه) إلى .cache/<id>/openiti.txt ويتحقق من sha256. في المسودة يثبّت
// sha256 وretrieved في الوصفة.
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

Future<void> main(List<String> args) async {
  final i = args.indexOf('--from');
  final pos = [
    for (var k = 0; k < args.length; k++)
      if (k != i && k != i + 1 || i < 0) args[k],
  ];
  if (pos.length != 1 || (i >= 0 && i + 1 >= args.length)) {
    stderr.writeln('الاستخدام: dart run bin/fetch_openiti.dart recipes/<id>.json [--from <repo-dir>]');
    exit(64);
  }
  final recipeFile = File(pos[0]);
  final recipe = OpenitiRecipe.load(recipeFile);
  final cache = Directory('${recipeFile.absolute.parent.parent.path}/.cache/${recipe.id}');
  final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  try {
    final bytes = await fetchOpeniti(
      recipe: recipe,
      recipeFile: recipeFile,
      cacheDir: cache,
      today: today,
      localRepo: i >= 0 ? Directory(args[i + 1]) : null,
    );
    stdout.writeln('جُلب ${recipe.versionUri} (${bytes.length} بايت، sha256 ${recipe.sha256}) '
        'إلى ${openitiCacheFile(cache).path} (retrieved=${recipe.retrieved}).');
  } on OpenitiFetchException catch (e) {
    stderr.writeln('فشل الجلب: ${e.message}');
    stderr.writeln(e.network
        ? 'تحقق من الاتصال ومن السماح بـ raw.githubusercontent.com ثم أعد التشغيل. لم يُكتب أي نص.'
        : 'لم يُكتب أي نص. راجع الوصفة.');
    exitCode = e.network ? 69 : 70;
  }
}
