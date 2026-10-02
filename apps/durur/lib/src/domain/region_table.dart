import 'json_utils.dart';
import 'localized_text.dart';
import 'month_day.dart';
import 'record_meta.dart';
import 'weather_symbol.dart';

/// سجل دَرّ في جدول منطقة. النهاية مشتقة من بداية التالي (D6).
class DarRecord implements Sourced {
  const DarRecord({
    required this.regionId,
    required this.start,
    required this.number,
    required this.name,
    required this.seasonId,
    required this.weather,
    required this.weatherNote,
    required this.source,
    required this.approval,
  });

  factory DarRecord.fromJson(Object? json, String regionId, String where) {
    final map = asObject(json, where);
    final note = map['weatherNote'];
    return DarRecord(
      regionId: regionId,
      start: MonthDay.parse(readField<String>(map, 'start', where), where),
      number: readField<int>(map, 'number', where),
      name: LocalizedText.fromJson(map['name'], '$where.name'),
      seasonId: readField<String>(map, 'seasonId', where),
      weather: WeatherSymbol.parseList(map['weather'], where),
      weatherNote: note == null
          ? null
          : LocalizedText.fromJson(note, '$where.weatherNote'),
      source: Source.fromJson(map['source'], where),
      approval: Approval.fromJson(map['approval'], where),
    );
  }

  final String regionId;
  final MonthDay start;
  final int number;
  final LocalizedText name;
  final String seasonId;
  final List<WeatherSymbol> weather;
  final LocalizedText? weatherNote;
  final Source source;
  @override
  final Approval approval;

  @override
  String get recordPath => 'regions/$regionId.json:durur[$start]';

  @override
  List<Source> get sources => [source];
}

/// سجل في طبقة متصلة (موسم كبير أو نجم): بداية فقط (D6).
class LayerRecord implements Sourced {
  const LayerRecord({
    required this.path,
    required this.itemId,
    required this.start,
    required this.source,
    required this.approval,
  });

  factory LayerRecord.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    return LayerRecord(
      path: where,
      itemId: readField<String>(map, 'itemId', where),
      start: MonthDay.parse(readField<String>(map, 'start', where), where),
      source: Source.fromJson(map['source'], where),
      approval: Approval.fromJson(map['approval'], where),
    );
  }

  final String path;
  final String itemId;
  final MonthDay start;
  final Source source;
  @override
  final Approval approval;

  @override
  String get recordPath => path;

  @override
  List<Source> get sources => [source];
}

/// سجل موسم جو: بداية ونهاية (شاملة)، وقد يلتف عبر نهاية السنة.
class WeatherSeasonRecord implements Sourced {
  const WeatherSeasonRecord({
    required this.path,
    required this.itemId,
    required this.start,
    required this.end,
    required this.source,
    required this.approval,
  });

  factory WeatherSeasonRecord.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    return WeatherSeasonRecord(
      path: where,
      itemId: readField<String>(map, 'itemId', where),
      start: MonthDay.parse(readField<String>(map, 'start', where), where),
      end: MonthDay.parse(readField<String>(map, 'end', where), where),
      source: Source.fromJson(map['source'], where),
      approval: Approval.fromJson(map['approval'], where),
    );
  }

  final String path;
  final String itemId;
  final MonthDay start;
  final MonthDay end;
  final Source source;
  @override
  final Approval approval;

  bool get wrapsYear => end < start;

  /// هل يقع (شهر، يوم) داخل الموسم؟ 29 فبراير يُمرَّر بعد تطبيق قاعدة المنطقة.
  bool contains(MonthDay md) =>
      wrapsYear ? (start <= md || md <= end) : (start <= md && md <= end);

  @override
  String get recordPath => path;

  @override
  List<Source> get sources => [source];
}

/// استعارة درور منطقة أخرى (D24، عرض السعودية): المنطقة بلا درور خاصة بها
/// تعرض درور [fromRegionId] مع سطر ثابت [note] من البيانات.
class DururBorrow implements Sourced {
  const DururBorrow({
    required this.regionId,
    required this.fromRegionId,
    required this.note,
    required this.source,
    required this.approval,
  });

  factory DururBorrow.fromJson(Object? json, String regionId, String where) {
    final map = asObject(json, where);
    return DururBorrow(
      regionId: regionId,
      fromRegionId: readField<String>(map, 'fromRegionId', where),
      note: LocalizedText.fromJson(map['note'], '$where.note'),
      source: Source.fromJson(map['source'], where),
      approval: Approval.fromJson(map['approval'], where),
    );
  }

  /// المنطقة المستعيرة.
  final String regionId;

  /// المنطقة المُعيرة (جدول الدرور الفعلي).
  final String fromRegionId;

  /// السطر الثابت المعروض تحت الدَّرّ (النص المعتمد من المالك).
  final LocalizedText note;
  final Source source;
  @override
  final Approval approval;

  @override
  String get recordPath => 'regions/$regionId.json:dururBorrow';

  @override
  List<Source> get sources => [source];
}

/// جدول منطقة واحدة (`assets/tables/regions/<id>.json`).
class RegionTable {
  const RegionTable({
    required this.regionId,
    required this.durur,
    required this.majorSeasons,
    required this.stars,
    required this.weatherSeasons,
    this.dururBorrow,
  });

  factory RegionTable.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    final regionId = readField<String>(map, 'regionId', where);
    List<Object?> list(String key) => asList(map[key], '$where.$key');
    final borrow = map['dururBorrow'];
    return RegionTable(
      regionId: regionId,
      dururBorrow: borrow == null
          ? null
          : DururBorrow.fromJson(borrow, regionId, '$where.dururBorrow'),
      durur: [
        for (final (i, r) in list('durur').indexed)
          DarRecord.fromJson(r, regionId, '$where.durur[$i]'),
      ],
      majorSeasons: [
        for (final (i, r) in list('majorSeasons').indexed)
          LayerRecord.fromJson(r, '$where.majorSeasons[$i]'),
      ],
      stars: [
        for (final (i, r) in list('stars').indexed)
          LayerRecord.fromJson(r, '$where.stars[$i]'),
      ],
      weatherSeasons: [
        for (final (i, r) in list('weatherSeasons').indexed)
          WeatherSeasonRecord.fromJson(r, '$where.weatherSeasons[$i]'),
      ],
    );
  }

  final String regionId;
  final List<DarRecord> durur;
  final List<LayerRecord> majorSeasons;
  final List<LayerRecord> stars;
  final List<WeatherSeasonRecord> weatherSeasons;

  /// استعارة الدرور (D24)، أو null إن كانت للمنطقة درورها الخاصة.
  final DururBorrow? dururBorrow;

  /// هل يُستعار جدول الدرور من منطقة أخرى؟
  bool get borrowsDurur => dururBorrow != null;

  Iterable<Sourced> get allRecords => [
    ...durur,
    ...majorSeasons,
    ...stars,
    ...weatherSeasons,
    ?dururBorrow,
  ];
}
