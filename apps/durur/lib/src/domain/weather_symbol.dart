/// رموز الجو المعتاد: مجموعة مغلقة من 17 رمزاً (D23، ARCHITECTURE §4).
/// الإضافة بقرار وتحديث متجر؛ حزمة البيانات لا تضيف رموزاً (§16.7).
/// `star_rise` ليس رمز جو (أيقونة واجهة فقط)، فلا يُقبل في البيانات.
enum WeatherSymbol {
  hot('hot'),
  veryHot('very_hot'),
  mild('mild'),
  cool('cool'),
  cold('cold'),
  veryCold('very_cold'),
  wind('wind'),
  windStrong('wind_strong'),
  rain('rain'),
  heavyRain('heavy_rain'),
  thunder('thunder'),
  cloud('cloud'),
  dust('dust'),
  humidity('humidity'),
  fog('fog'),
  seaCalm('sea_calm'),
  seaRough('sea_rough');

  const WeatherSymbol(this.code);

  /// الرمز كما يُكتب في JSON.
  final String code;

  static WeatherSymbol parse(String code, String where) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    throw FormatException('$where: رمز جو غير معروف "$code".');
  }

  static List<WeatherSymbol> parseList(Object? json, String where) {
    if (json == null) return const [];
    if (json is! List) {
      throw FormatException('$where.weather: المتوقع قائمة رموز.');
    }
    return [
      for (final code in json)
        if (code is String)
          parse(code, '$where.weather')
        else
          throw FormatException('$where.weather: رمز ليس نصاً.'),
    ];
  }
}
