/// التحويل الكامل: وصفة + نصوص مخزّنة ← ملف الكتاب المضغوط في المكتبة.
library;

import 'dart:io';

import 'book_builder.dart';
import 'recipe.dart';

class ConvertOutput {
  ConvertOutput(this.file, this.result, this.json, this.gz);
  final File file;
  final BuildResult result;
  final List<int> json;
  final List<int> gz;
}

/// يكتب `books/<id>/<id>.v<N>.json.gz`. ملف إصدار منشور لا يُستبدل بمحتوى مختلف
/// (ARCHITECTURE §4.1: ملفات الإصدارات لا تُعدَّل بعد نشرها) إلا مع [overwrite].
ConvertOutput convertToLibrary(
  Recipe recipe,
  Map<int, String> pageTexts,
  Directory libraryRoot, {
  bool overwrite = false,
}) {
  final result = buildBook(recipe, pageTexts);
  final json = encodeBookJson(result.book);
  final gz = gzipDeterministic(json);
  final file = File('${libraryRoot.path}/${bookRelativePath(recipe.id, recipe.version)}');
  if (file.existsSync() && !overwrite) {
    final old = file.readAsBytesSync();
    if (!_same(old, gz)) {
      throw StateError(
        '${file.path} موجود بمحتوى مختلف. ارفع version في الوصفة (مع redirects عند تغيّر المعرّفات) '
        'أو استخدم --overwrite لإصدار لم يُنشر بعد.',
      );
    }
  }
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(gz);
  return ConvertOutput(file, result, json, gz);
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
