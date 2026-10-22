import '../hijri/umm_al_qura_calendar.dart';
import 'arabic.dart';
import 'astro_season.dart';
import 'deposits.dart';
import 'prayer.dart';
import 'qibla.dart';
import 'settings.dart';
import 'traditional_seasons.dart';
import 'weather.dart';
import 'widget_theme.dart';

import 'package:timezone/timezone.dart' as tz;

/// الجدول الذي تقرؤه الودجت الأصلية (ARCHITECTURE: تدفق البيانات).
const scheduleSchemaVersion = 1;

/// بيانات المحرك المقروءة من الأصول.
class EngineData {
  const EngineData({
    required this.deposits,
    required this.hijri,
    required this.tradSeasons,
  });

  /// من نصوص ملفات JSON الثلاثة.
  factory EngineData.fromStrings({
    required String depositsJson,
    required Object? hijriJson,
    required String seasonsJson,
  }) =>
      EngineData(
        deposits: DepositsConfig.fromJsonString(depositsJson),
        hijri: UmmAlQuraCalendar.fromJson(hijriJson),
        tradSeasons: TradSeasonsTable.fromJsonString(seasonsJson),
      );

  final DepositsConfig deposits;
  final UmmAlQuraCalendar hijri;
  final TradSeasonsTable tradSeasons;
}

/// التاريخ الهجري لعرضه: {day, month, monthName, year, text}.
Map<String, Object> hijriJson(UmmAlQuraCalendar calendar, DateTime day) {
  final h = calendar.convert(day);
  final monthName = hijriMonthNames[h.month - 1];
  return {
    'day': h.day,
    'month': h.month,
    'monthName': monthName,
    'year': h.year,
    'text': '${formatDigits(h.day)} $monthName ${formatDigits(h.year)}',
  };
}

/// يبني جدول [days] يوماً بدءاً من اليوم المحلي (في منطقة [s]) للحظة [from].
/// [generatedAt] افتراضياً = [from]، فلا يعتمد المحرك على ساعة الجهاز.
Map<String, Object?> buildSchedule(
  DateTime from,
  Settings s,
  EngineData data, {
  int days = 30,
  DateTime? generatedAt,
  WeatherReading? weather,
}) {
  if (days < 1) throw RangeError.value(days, 'days');
  for (final id in s.deposits) {
    data.deposits.rule(id); // يرمي لمعرّف غير معروف.
  }
  final prayers = PrayerCalculator(
    latitude: s.latitude,
    longitude: s.longitude,
    timeZoneName: s.timeZone,
    method: s.prayerMethod,
    isRamadan: (d) => data.hijri.tryConvert(d)?.month == 9,
  );
  final start = tz.TZDateTime.from(from, prayers.location);
  final qibla = qiblaDegrees(s.latitude, s.longitude);

  final dayList = <Map<String, Object?>>[];
  for (var i = 0; i < days; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    final noon = tz.TZDateTime(prayers.location, d.year, d.month, d.day, 12);
    final monthName = gregorianMonthNames[d.month - 1];
    dayList.add({
      'date': isoDate(d),
      'weekday': weekdayNames[d.weekday - 1],
      'gregorian': {
        'day': d.day,
        'month': d.month,
        'monthName': monthName,
        'year': d.year,
        'text': '${formatDigits(d.day)} $monthName ${formatDigits(d.year)}',
      },
      'hijri': hijriJson(data.hijri, d),
      'prayers': prayers.forDate(d).toJson(),
      'season': astroSeasonOn(d, noon.timeZoneOffset).toJson(),
      'tradSeason': data.tradSeasons.on(d).toJson(),
      'deposits': [
        // حتى ثلاثة إيداعات، الأقرب أولاً (أعمدة الإيداعات، الميزة ٦).
        for (final o in data.deposits.nextDeposits(d, s.deposits, count: 3))
          o.toJson(),
      ],
    });
  }

  final schedule = <String, Object?>{
    'schemaVersion': scheduleSchemaVersion,
    'generatedAt': (generatedAt ?? from).toUtc().toIso8601String(),
    'city': {
      'name': s.cityName,
      'latitude': s.latitude,
      'longitude': s.longitude,
      'timeZone': s.timeZone,
    },
    'prayerMethod': s.prayerMethod,
    'qibla': {
      'degrees': double.parse(qibla.toStringAsFixed(1)),
      'direction': directionName(qibla),
      'text': '${formatDigits(qibla.round())}° ${directionName(qibla)}',
    },
    // ما يظهر (يقرؤه عامل الطقس في أندرويد)، ثم التخطيط بترتيبه (الميزة ٥).
    'visible': {
      for (final e in WidgetElement.values) e.name: s.visible.contains(e),
    },
    'layout': [for (final t in s.layout) t.toScheduleJson()],
    'opacity': s.opacity,
    // اسم ملف اللقطة نسبياً داخل حاوية group.sa.lamha.shared؛ null بلا صورة أو في أندرويد.
    'background': s.background,
    'theme': themeScheduleJson(s.theme),
    'lockNotification': s.lockNotification,
    // معامل حجم الخط تضرب به المعاينة والودجت كل حجم نص.
    'fontScale': s.fontScale.factor,
    // شكل الأرقام (الميزة ٦): نصوص الجدول الجاهزة به، والودجت تبني به ما تحسبه (الحرارة).
    'digits': s.digits.name,
    // آخر قراءة للمدينة نفسها فقط؛ عمرها يُفحص عند العرض (weatherMaxAge).
    'weather': weatherScheduleJson(
        weather != null && weather.isFor(s.latitude, s.longitude) ? weather : null),
    'days': dayList,
  };
  // النصوص تُبنى بالأرقام العربية، وبالإنجليزية تُحوَّل كلها مرة واحدة (التواريخ والأوقات والأيام
  // المتبقية والحرارة والقبلة). ISO والمعرّفات بأرقام لاتينية أصلاً فلا تتغير.
  return s.digits == DigitStyle.arabic
      ? schedule
      : localizeDigits(schedule, s.digits)! as Map<String, Object?>;
}
