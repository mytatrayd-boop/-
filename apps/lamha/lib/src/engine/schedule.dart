import '../hijri/umm_al_qura_calendar.dart';
import 'arabic.dart';
import 'astro_season.dart';
import 'deposits.dart';
import 'prayer.dart';
import 'qibla.dart';
import 'settings.dart';
import 'traditional_seasons.dart';

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
    'text': '${arabicDigits(h.day)} $monthName ${arabicDigits(h.year)}',
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
        'text': '${arabicDigits(d.day)} $monthName ${arabicDigits(d.year)}',
      },
      'hijri': hijriJson(data.hijri, d),
      'prayers': prayers.forDate(d).toJson(),
      'season': astroSeasonOn(d, noon.timeZoneOffset).toJson(),
      'tradSeason': data.tradSeasons.on(d).toJson(),
      'deposits': [
        for (final o in data.deposits.nextDeposits(d, s.deposits)) o.toJson(),
      ],
    });
  }

  return {
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
      'text': '${arabicDigits(qibla.round())}° ${directionName(qibla)}',
    },
    'visible': {for (final e in WidgetElement.values) e.name: s.visible.contains(e)},
    'opacity': s.opacity,
    // اسم ملف اللقطة نسبياً داخل حاوية group.sa.lamha.shared؛ null بلا صورة أو في أندرويد.
    'background': s.background,
    'days': dayList,
  };
}
