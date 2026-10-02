import 'package:durur/src/domain/tables.dart';

/// جداول صغيرة جداً بقيم معروفة لاختبار المحرك والمدقق (ليست بيانات تراثية).
///
/// المنطقة a: الدرور 01-05 (أ)، 02-20 (ب)، 03-01 (ج)، 07-01 (هـ)، 12-25 (د).
/// المنطقة b: مثل a لكن (ج) يبدأ 03-05.
const fixtureSource = {'title': 'fixture'};
const draft = {'status': 'draft', 'reviewer': null, 'date': null};
const approved = {
  'status': 'approved',
  'reviewer': 'test',
  'date': '2026-10-02',
};

Map<String, Object?> dar(
  String start,
  int number,
  String name,
  String season, {
  Object approval = approved,
}) => {
  'start': start,
  'number': number,
  'name': {'ar': name},
  'seasonId': season,
  'weather': ['cold'],
  'weatherNote': {'ar': 'ملاحظة'},
  'source': fixtureSource,
  'approval': approval,
};

Map<String, Object?> layer(String itemId, String start) => {
  'itemId': itemId,
  'start': start,
  'source': fixtureSource,
  'approval': approved,
};

Map<String, Object?> wseason(String itemId, String start, String end) => {
  'itemId': itemId,
  'start': start,
  'end': end,
  'source': fixtureSource,
  'approval': approved,
};

Map<String, Object?> item(
  String id,
  String kind, {
  String definition = 'سطر أول\nسطر ثانٍ',
}) => {
  'id': id,
  'kind': kind,
  'name': {'ar': id},
  'important': false,
  'dateMethod': 'table',
  'definition': {'ar': definition},
  'proverb': {'ar': 'مثل'},
  'weather': ['mild'],
  'sources': [fixtureSource],
  'approval': approved,
};

Map<String, Object?> region(String id) => {
  'id': id,
  'name': {'ar': id},
  'leapDayRule': 'extend_feb28',
  'source': fixtureSource,
  'approval': approved,
};

Map<String, Object?> regionTable(String id, {String thirdDarStart = '03-01'}) =>
    {
      'regionId': id,
      'durur': [
        dar('01-05', 1, 'أ', 's1'),
        dar('02-20', 2, 'ب', 's1'),
        dar(thirdDarStart, 3, 'ج', 's1'),
        dar('07-01', 1, 'هـ', 's2'),
        dar('12-25', 2, 'د', 's2'),
      ],
      'majorSeasons': [layer('s1', '01-05'), layer('s2', '07-01')],
      'stars': [layer('st1', '05-01')],
      'weatherSeasons': [
        wseason('w1', '12-20', '01-10'),
        wseason('w2', '02-25', '02-28'),
      ],
    };

List<Map<String, Object?>> fixtureItems() => [
  item('s1', 'majorSeason'),
  item('s2', 'majorSeason'),
  item('st1', 'star'),
  item('w1', 'weatherSeason'),
  item('w2', 'weatherSeason'),
];

/// يبني الجداول؛ [edit] يعدّل JSON قبل التحليل (لاختبارات المدقق).
Tables fixtureTables({
  String dataVersion = 'fixture',
  void Function(
    Map<String, Object?> regionTables,
    List<Object?> regions,
    List<Object?> items,
  )?
  edit,
}) {
  final regions = <Object?>[
    for (final id in ['a', 'b', 'c', 'd']) region(id),
  ];
  final tables = <String, Object?>{
    'a': regionTable('a'),
    'b': regionTable('b', thirdDarStart: '03-05'),
    'c': regionTable('c'),
    'd': regionTable('d'),
  };
  final items = <Object?>[...fixtureItems()];
  edit?.call(tables, regions, items);
  return Tables.fromJson(
    metaJson: {'schemaVersion': 1, 'dataVersion': dataVersion},
    regionsJson: regions,
    itemsJson: items,
    regionTablesJson: tables,
  );
}
