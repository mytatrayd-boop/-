/// رموز الجو المعتاد: مجموعة مغلقة (ARCHITECTURE §4). الإضافة بقرار.
enum WeatherSymbol {
  hot('hot'),
  veryHot('very_hot'),
  cold('cold'),
  veryCold('very_cold'),
  mild('mild'),
  wind('wind'),
  rain('rain'),
  dust('dust'),
  humidity('humidity'),
  fog('fog');

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
