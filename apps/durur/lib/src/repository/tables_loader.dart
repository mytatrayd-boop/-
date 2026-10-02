import 'dart:convert';

import '../domain/json_utils.dart';
import '../domain/tables.dart';

/// يقرأ نص ملف من مسار أصل (مثل assets/tables/meta.json).
typedef TextReader = Future<String> Function(String assetPath);

/// يحمّل الجداول من مكان الأصول المحدد (ARCHITECTURE §2). Dart صافٍ:
/// التطبيق يمرّر AssetBundle، والأداة والاختبارات تمرّر قراءة ملفات.
///
/// جدول كل منطقة يُقرأ من `regions/<id>.json` حسب معرّفات regions.json،
/// فاستبدال البيانات التجريبية بالحقيقية لا يحتاج تغيير الكود.
class TablesLoader {
  const TablesLoader(this.read);

  static const root = 'assets/tables';
  static const metaPath = '$root/meta.json';
  static const regionsPath = '$root/regions.json';
  static const itemsPath = '$root/items.json';
  static String regionTablePath(String regionId) =>
      '$root/regions/$regionId.json';

  final TextReader read;

  Future<Tables> load() async {
    final regionsJson = await _readJson(regionsPath);
    final regionTables = <String, Object?>{};
    for (final (i, r) in asList(regionsJson, 'regions.json').indexed) {
      final id = readField<String>(
          asObject(r, 'regions.json[$i]'), 'id', 'regions.json[$i]');
      regionTables[id] = await _readJson(regionTablePath(id));
    }
    return Tables.fromJson(
      metaJson: await _readJson(metaPath),
      regionsJson: regionsJson,
      itemsJson: await _readJson(itemsPath),
      regionTablesJson: regionTables,
    );
  }

  Future<Object?> _readJson(String path) async => jsonDecode(await read(path));
}
