import '../hijri/umm_al_qura_calendar.dart';
import 'city.dart';
import 'item.dart';
import 'json_utils.dart';
import 'record_meta.dart';
import 'region.dart';
import 'region_table.dart';

/// معلومات ملف meta.json.
class TablesMeta {
  const TablesMeta({
    required this.schemaVersion,
    required this.dataVersion,
    this.dataSeq = 0,
  });

  factory TablesMeta.fromJson(Object? json) {
    final map = asObject(json, 'meta.json');
    final dataSeq = readOptional<int>(map, 'dataSeq', 'meta.json') ?? 0;
    if (dataSeq < 0) {
      throw FormatException('meta.json: dataSeq سالب ($dataSeq).');
    }
    return TablesMeta(
      schemaVersion: readField<int>(map, 'schemaVersion', 'meta.json'),
      dataVersion: readField<String>(map, 'dataVersion', 'meta.json'),
      dataSeq: dataSeq,
    );
  }

  /// رقم مخطط البيانات الذي يفهمه هذا الكود.
  static const supportedSchemaVersion = 1;

  final int schemaVersion;
  final String dataVersion;

  /// رقم حزمة البيانات المنشورة (ARCHITECTURE §16.3)؛ يزيد مع كل نشر.
  /// 0 = لم تُنشر حزمة بعد.
  final int dataSeq;
}

/// كل بيانات الجداول بعد التحميل.
class Tables {
  Tables({
    required this.meta,
    required this.regions,
    required this.itemList,
    required this.regionTables,
    this.cities = const [],
    this.hijri,
  }) : items = {for (final item in itemList) item.id: item};

  /// يبني الجداول من JSON محلَّل (بلا Flutter، يستخدمه التطبيق والأداة والاختبارات).
  /// [regionTablesJson]: معرّف المنطقة ← محتوى `regions/<id>.json`.
  /// [citiesJson]: محتوى `cities.json` (اختياري لاختبارات المحرك).
  /// [hijriJson]: محتوى `hijri_umm_al_qura.json` (اختياري لاختبارات المحرك).
  factory Tables.fromJson({
    required Object? metaJson,
    required Object? regionsJson,
    required Object? itemsJson,
    required Map<String, Object?> regionTablesJson,
    Object? citiesJson,
    Object? hijriJson,
  }) {
    final meta = TablesMeta.fromJson(metaJson);
    if (meta.schemaVersion != TablesMeta.supportedSchemaVersion) {
      throw FormatException('meta.json: رقم المخطط ${meta.schemaVersion} '
          'غير مدعوم (المدعوم ${TablesMeta.supportedSchemaVersion}).');
    }
    final regions = [
      for (final (i, r) in asList(regionsJson, 'regions.json').indexed)
        Region.fromJson(r, 'regions.json[$i]'),
    ];
    final items = [
      for (final (i, r) in asList(itemsJson, 'items.json').indexed)
        Item.fromJson(r, 'items.json[$i]'),
    ];
    final tables = <String, RegionTable>{};
    regionTablesJson.forEach((id, json) {
      final table = RegionTable.fromJson(json, 'regions/$id.json');
      if (table.regionId != id) {
        throw FormatException('regions/$id.json: regionId '
            '"${table.regionId}" لا يطابق اسم الملف.');
      }
      tables[id] = table;
    });
    final cities = citiesJson == null
        ? const <City>[]
        : [
            for (final (i, c) in asList(citiesJson, 'cities.json').indexed)
              City.fromJson(c, 'cities.json[$i]'),
          ];
    return Tables(
      meta: meta,
      regions: regions,
      itemList: items,
      regionTables: tables,
      cities: cities,
      hijri: hijriJson == null ? null : UmmAlQuraCalendar.fromJson(hijriJson),
    );
  }

  final TablesMeta meta;
  final List<Region> regions;
  /// معرّف العنصر ← العنصر.
  final Map<String, Item> items;
  final Map<String, RegionTable> regionTables;

  /// القائمة الأصلية بترتيب الملف (لاكتشاف المعرّفات المكررة في المدقق).
  final List<Item> itemList;

  /// المدن بترتيب الملف (SPEC الميزة 3).
  final List<City> cities;

  /// تقويم أم القرى (D22). التطبيق يحمّله دائماً؛ null في جداول اختبار المحرك.
  final UmmAlQuraCalendar? hijri;

  City? city(String id) {
    for (final c in cities) {
      if (c.id == id) return c;
    }
    return null;
  }

  Region? region(String id) {
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  Iterable<Sourced> get allRecords => [
        ...regions,
        ...itemList,
        ...cities,
        ?hijri,
        for (final t in regionTables.values) ...t.allRecords,
      ];

  /// هل في البيانات سجل غير معتمد؟ (لشريط «بيانات تجريبية» وبوابة الإطلاق).
  bool get hasUnapproved => allRecords.any((r) => !r.approval.isApproved);
}
