/// حزمة البيانات الموحّدة `bundle-<seq>.json` (ARCHITECTURE §16.1، §16.4).
/// Dart صافٍ: يستخدمها التطبيق والأداة `tool/sign_bundle.dart` والاختبارات.
///
/// الصيغة: `{"format": 1, "files": {"meta.json": {...}, "regions.json": [...],
/// "regions/najd.json": {...}, ...}}`، والمسارات نسبةً إلى `assets/tables/`.
/// التحميل يمرّ بـ [TablesLoader] نفسه، فلا يتغير المحلل ولا المدقق.
library;

import 'dart:convert';

import '../domain/json_utils.dart';
import '../domain/tables.dart';
import '../repository/tables_loader.dart';

/// رقم صيغة الحزمة (غير رقم مخطط الجداول).
const bundleFormat = 1;

/// يجمع ملفات الجداول من مصدر قراءة (الأصول أو القرص) في خريطة
/// (مسار نسبي ← JSON محلَّل). جدول كل منطقة حسب معرّفات regions.json.
Future<Map<String, Object?>> collectBundleFiles(TextReader read) async {
  Future<Object?> json(String path) async => jsonDecode(await read(path));
  String rel(String path) => path.substring(TablesLoader.root.length + 1);

  final files = <String, Object?>{};
  for (final path in [
    TablesLoader.metaPath,
    TablesLoader.regionsPath,
    TablesLoader.itemsPath,
    TablesLoader.citiesPath,
    TablesLoader.hijriPath,
  ]) {
    files[rel(path)] = await json(path);
  }
  final regions = asList(files[rel(TablesLoader.regionsPath)], 'regions.json');
  for (final (i, r) in regions.indexed) {
    final id = readField<String>(
      asObject(r, 'regions.json[$i]'),
      'id',
      'regions.json[$i]',
    );
    final path = TablesLoader.regionTablePath(id);
    files[rel(path)] = await json(path);
  }
  return files;
}

/// بايتات الحزمة (UTF-8) من خريطة الملفات.
List<int> encodeBundle(Map<String, Object?> files) =>
    utf8.encode(jsonEncode({'format': bundleFormat, 'files': files}));

/// يحلل الحزمة إلى جداول بالمحلل نفسه. يرمي [FormatException] لأي خلل
/// (JSON تالف، صيغة أخرى، ملف ناقص، أو خطأ تحليل في الجداول).
Future<Tables> loadBundleTables(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    throw FormatException('الحزمة: JSON تالف (${e.message}).');
  }
  final map = asObject(decoded, 'الحزمة');
  if (map['format'] != bundleFormat) {
    throw FormatException('الحزمة: صيغة غير مدعومة (${map['format']}).');
  }
  final files = asObject(map['files'], 'الحزمة.files');
  return TablesLoader((path) async {
    final prefix = '${TablesLoader.root}/';
    final rel = path.startsWith(prefix) ? path.substring(prefix.length) : path;
    if (!files.containsKey(rel)) {
      throw FormatException('الحزمة: الملف "$rel" مفقود.');
    }
    return jsonEncode(files[rel]);
  }).load();
}
