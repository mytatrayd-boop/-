import 'json_utils.dart';
import 'localized_text.dart';
import 'record_meta.dart';
import 'weather_symbol.dart';

enum ItemKind {
  star('star'),
  majorSeason('majorSeason'),
  weatherSeason('weatherSeason'),
  dar('dar');

  const ItemKind(this.code);
  final String code;

  static ItemKind parse(String code, String where) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    throw FormatException('$where: نوع عنصر غير معروف "$code".');
  }
}

enum DateMethod {
  /// التاريخ من جدول المنطقة.
  table('table'),

  /// التاريخ محسوب فلكياً (سهيل والثريا، الميزة 5).
  heliacal('heliacal');

  const DateMethod(this.code);
  final String code;

  static DateMethod parse(String code, String where) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    throw FormatException('$where: طريقة تاريخ غير معروفة "$code".');
  }
}

/// عنصر له صفحة: نجم، موسم كبير، موسم جو.
class Item implements Sourced {
  const Item({
    required this.id,
    required this.kind,
    required this.name,
    required this.important,
    required this.dateMethod,
    required this.definition,
    required this.proverb,
    required this.weather,
    required this.weatherNote,
    required this.sources,
    required this.approval,
  });

  factory Item.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    final id = readField<String>(map, 'id', where);
    final w = '$where[$id]';
    final note = map['weatherNote'];
    return Item(
      id: id,
      kind: ItemKind.parse(readField<String>(map, 'kind', w), w),
      name: LocalizedText.fromJson(map['name'], '$w.name'),
      important: readOptional<bool>(map, 'important', w) ?? false,
      dateMethod: DateMethod.parse(
          readOptional<String>(map, 'dateMethod', w) ?? 'table', w),
      definition: LocalizedText.fromJson(map['definition'], '$w.definition'),
      proverb: LocalizedText.fromJson(map['proverb'], '$w.proverb'),
      weather: WeatherSymbol.parseList(map['weather'], w),
      weatherNote:
          note == null ? null : LocalizedText.fromJson(note, '$w.weatherNote'),
      sources: [
        for (final (i, s) in asList(map['sources'], '$w.sources').indexed)
          Source.fromJson(s, '$w.sources[$i]'),
      ],
      approval: Approval.fromJson(map['approval'], w),
    );
  }

  final String id;
  final ItemKind kind;
  final LocalizedText name;
  final bool important;
  final DateMethod dateMethod;
  final LocalizedText definition;
  final LocalizedText proverb;
  final List<WeatherSymbol> weather;
  final LocalizedText? weatherNote;
  @override
  final List<Source> sources;
  @override
  final Approval approval;

  @override
  String get recordPath => 'items.json[$id]';
}
