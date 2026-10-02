import 'json_utils.dart';
import 'localized_text.dart';
import 'record_meta.dart';

/// دول الخليج في قائمة المدن، بترتيب العرض في شرائح التصفية (DESIGN 5.3).
enum Country {
  sa('SA'),
  kw('KW'),
  ae('AE'),
  om('OM'),
  qa('QA'),
  bh('BH');

  const Country(this.code);

  /// رمز ISO 3166-1 كما في cities.json.
  final String code;

  static Country parse(String code, String where) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    throw FormatException('$where: رمز دولة غير معروف "$code".');
  }
}

/// مدينة في `assets/tables/cities.json` مرتبطة بجدول منطقة واحد (SPEC الميزة 3).
/// إحداثياتها تقريبية (مركز المدينة) وتُستخدم لحساب الطلوع (الميزة 5)
/// ولأقرب مدينة (الميزة 4). لا تُحفظ إحداثيات المستخدم أبداً.
class City implements Sourced {
  const City({
    required this.id,
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    required this.regionId,
    required this.source,
    required this.approval,
    this.area,
    this.regionNote,
  });

  factory City.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    final id = readField<String>(map, 'id', where);
    final w = '$where[$id]';
    return City(
      id: id,
      name: LocalizedText.fromJson(map['name'], '$w.name'),
      country: Country.parse(readField<String>(map, 'country', w), w),
      area: readOptional<String>(map, 'area', w),
      lat: readField<num>(map, 'lat', w).toDouble(),
      lon: readField<num>(map, 'lon', w).toDouble(),
      regionId: readField<String>(map, 'regionId', w),
      regionNote: readOptional<String>(map, 'regionNote', w),
      source: Source.fromJson(map['source'], w),
      approval: Approval.fromJson(map['approval'], w),
    );
  }

  final String id;
  final LocalizedText name;
  final Country country;

  /// المنطقة داخل الدولة (للسعودية: najd، eastern، hijaz، south، north)
  /// للتوثيق والمراجعة فقط.
  final String? area;

  /// خط العرض والطول بالدرجات (WGS84).
  final double lat;
  final double lon;

  /// معرّف جدول المنطقة في regions.json.
  final String regionId;

  /// ملاحظة للمراجع عن سبب الربط إن كان مؤقتاً (لا تُعرض للمستخدم).
  final String? regionNote;

  final Source source;
  @override
  final Approval approval;

  @override
  String get recordPath => 'cities.json[$id]';

  @override
  List<Source> get sources => [source];
}
