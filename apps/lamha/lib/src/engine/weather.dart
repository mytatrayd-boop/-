import 'arabic.dart';

/// الطقس الحالي من Open-Meteo (DECISIONS ٣): الحرارة ورمز WMO ووقت الجلب.
/// يُحفظ في الجدول (`weather`) لتعرضه المعاينة والودجت.
class WeatherReading {
  const WeatherReading({
    required this.temp,
    required this.code,
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
  });

  factory WeatherReading.fromJson(Map<String, dynamic> j) => WeatherReading(
        temp: (j['temp'] as num).toDouble(),
        code: (j['code'] as num).toInt(),
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
      );

  final double temp;
  final int code;
  final DateTime fetchedAt;

  /// الإحداثيات التي جُلبت لها القراءة (لا تُعرض لمدينة أخرى).
  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
        'temp': temp,
        'code': code,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      };

  /// هل القراءة لهذا المكان؟ (فرق أقل من ٠٫٠٥° ≈ ٥ كم)
  bool isFor(double lat, double lon) =>
      (latitude - lat).abs() < 0.05 && (longitude - lon).abs() < 0.05;
}

/// أقصى عمر للقراءة؛ بعده تُعرض «--°».
const weatherMaxAge = Duration(hours: 3);

/// رابط Open-Meteo (بلا مفتاح).
Uri openMeteoUri(double latitude, double longitude) => Uri.parse(
    'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude'
    '&current=temperature_2m,weather_code&timezone=auto');

/// يقرأ رد Open-Meteo؛ يرمي FormatException إن لم يكن فيه current.
WeatherReading parseOpenMeteo(
    Map<String, dynamic> json, DateTime fetchedAt, double lat, double lon) {
  final c = json['current'];
  if (c is! Map || c['temperature_2m'] is! num || c['weather_code'] is! num) {
    throw const FormatException('رد Open-Meteo بلا current');
  }
  return WeatherReading(
    temp: (c['temperature_2m'] as num).toDouble(),
    code: (c['weather_code'] as num).toInt(),
    fetchedAt: fetchedAt,
    latitude: lat,
    longitude: lon,
  );
}

/// رمز WMO (weather_code) إلى رمز تعبيري ونص عربي.
/// https://open-meteo.com/en/docs (WMO Weather interpretation codes).
const weatherConditions = <int, ({String emoji, String text})>{
  0: (emoji: '☀️', text: 'صحو'),
  1: (emoji: '🌤️', text: 'صحو غالباً'),
  2: (emoji: '⛅', text: 'غائم جزئياً'),
  3: (emoji: '☁️', text: 'غائم'),
  45: (emoji: '🌫️', text: 'ضباب'),
  48: (emoji: '🌫️', text: 'ضباب متجمد'),
  51: (emoji: '🌦️', text: 'رذاذ خفيف'),
  53: (emoji: '🌦️', text: 'رذاذ'),
  55: (emoji: '🌦️', text: 'رذاذ كثيف'),
  56: (emoji: '🌧️', text: 'رذاذ متجمد'),
  57: (emoji: '🌧️', text: 'رذاذ متجمد كثيف'),
  61: (emoji: '🌧️', text: 'مطر خفيف'),
  63: (emoji: '🌧️', text: 'مطر'),
  65: (emoji: '🌧️', text: 'مطر غزير'),
  66: (emoji: '🌧️', text: 'مطر متجمد'),
  67: (emoji: '🌧️', text: 'مطر متجمد غزير'),
  71: (emoji: '🌨️', text: 'ثلج خفيف'),
  73: (emoji: '🌨️', text: 'ثلج'),
  75: (emoji: '🌨️', text: 'ثلج كثيف'),
  77: (emoji: '🌨️', text: 'حبيبات ثلج'),
  80: (emoji: '🌦️', text: 'زخات مطر'),
  81: (emoji: '🌧️', text: 'زخات مطر'),
  82: (emoji: '⛈️', text: 'زخات مطر غزيرة'),
  85: (emoji: '🌨️', text: 'زخات ثلج'),
  86: (emoji: '🌨️', text: 'زخات ثلج كثيفة'),
  95: (emoji: '⛈️', text: 'عاصفة رعدية'),
  96: (emoji: '⛈️', text: 'عاصفة رعدية مع برد'),
  99: (emoji: '⛈️', text: 'عاصفة رعدية مع برد كثيف'),
};

/// رمز غير معروف: ميزان حرارة بلا نص.
({String emoji, String text}) weatherCondition(int code) =>
    weatherConditions[code] ?? (emoji: '🌡️', text: '');

/// عزل اتجاه من اليسار لليمين (LRI…PDI): تبقى الدرجة يمين الرقم («٢٦°» لا «°٢٦») داخل نص عربي.
const ltrIsolate = '\u2066';
const popIsolate = '\u2069';

/// «٣١°» أو «-٣°» بأرقام [style]، معزولاً باتجاه LTR (الميزة ٦).
String temperatureText(double temp, [DigitStyle style = DigitStyle.arabic]) {
  final t = temp.round();
  return '$ltrIsolate${t < 0 ? '-' : ''}${formatDigits(t.abs(), style)}°$popIsolate';
}

/// القراءة إذا كانت أحدث من [weatherMaxAge]، وإلا null.
WeatherReading? freshWeather(WeatherReading? r, DateTime now) =>
    r == null || now.difference(r.fetchedAt) > weatherMaxAge ? null : r;

/// «☀️ ٣١°» إذا كانت القراءة أحدث من [weatherMaxAge]، وإلا null (تُعرض «--°»).
String? weatherText(
  WeatherReading? r,
  DateTime now, [
  DigitStyle style = DigitStyle.arabic,
]) {
  final f = freshWeather(r, now);
  if (f == null) return null;
  return '${weatherCondition(f.code).emoji} ${temperatureText(f.temp, style)}';
}

/// الجزء الذي يحمله الجدول: القراءة مع رمزها ونصها، وجدول الرموز لتعرض الودجت
/// قراءة جلبتها بنفسها (WorkManager) دون أن تحسب.
Map<String, Object?> weatherScheduleJson(WeatherReading? r) => {
      if (r != null) ...{
        ...r.toJson(),
        'emoji': weatherCondition(r.code).emoji,
        'text': weatherCondition(r.code).text,
        'tempText': temperatureText(r.temp),
      },
      'maxAgeMinutes': weatherMaxAge.inMinutes,
      'icons': {
        for (final e in weatherConditions.entries) '${e.key}': e.value.emoji,
      },
    };
