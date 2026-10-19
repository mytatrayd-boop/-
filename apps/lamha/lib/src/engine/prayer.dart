import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'arabic.dart';

/// أوقات الصلاة بمكتبة adhan_dart (DECISIONS ٧)، بالتوقيت المحلي للمنطقة
/// الزمنية الممررة.

const defaultTimeZone = 'Asia/Riyadh';
const defaultPrayerMethod = 'ummAlQura';

bool _tzReady = false;

/// المنطقة الزمنية باسمها (مثل `Asia/Riyadh`) من قاعدة بيانات IANA المضمّنة.
tz.Location timeZone(String name) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  return tz.getLocation(name);
}

/// طرق الحساب المتاحة بمعرّفاتها المحفوظة في الإعدادات.
final Map<String, adhan.CalculationParameters Function()> prayerMethods = {
  'ummAlQura': adhan.CalculationMethodParameters.ummAlQura,
  'muslimWorldLeague': adhan.CalculationMethodParameters.muslimWorldLeague,
  'egyptian': adhan.CalculationMethodParameters.egyptian,
  'karachi': adhan.CalculationMethodParameters.karachi,
  'dubai': adhan.CalculationMethodParameters.dubai,
  'kuwait': adhan.CalculationMethodParameters.kuwait,
  'qatar': adhan.CalculationMethodParameters.qatar,
  'gulfRegion': adhan.CalculationMethodParameters.gulfRegion,
  'northAmerica': adhan.CalculationMethodParameters.northAmerica,
  'turkiye': adhan.CalculationMethodParameters.turkiye,
};

enum PrayerName {
  fajr('الفجر'),
  sunrise('الشروق'),
  dhuhr('الظهر'),
  asr('العصر'),
  maghrib('المغرب'),
  isha('العشاء');

  const PrayerName(this.arabic);

  final String arabic;

  /// الشروق ليس صلاة؛ يُعرض في الجدول ولا يكون «الصلاة القادمة».
  bool get isPrayer => this != sunrise;
}

class PrayerTime {
  const PrayerTime(this.name, this.time);

  final PrayerName name;

  /// بالتوقيت المحلي للمنطقة الزمنية.
  final tz.TZDateTime time;
}

/// أوقات يوم واحد.
class DayPrayers {
  DayPrayers(this.date, this.times);

  /// التاريخ المحلي.
  final DateTime date;

  /// الستة بالترتيب: الفجر، الشروق، الظهر، العصر، المغرب، العشاء.
  final List<PrayerTime> times;

  tz.TZDateTime operator [](PrayerName n) => times[n.index].time;

  Map<String, Object> toJson() => {
        for (final p in times)
          p.name.name: {'name': p.name.arabic, 'time': p.time.toIso8601String()},
      };
}

class PrayerCalculator {
  PrayerCalculator({
    required this.latitude,
    required this.longitude,
    String timeZoneName = defaultTimeZone,
    this.method = defaultPrayerMethod,
  }) : location = timeZone(timeZoneName) {
    if (!prayerMethods.containsKey(method)) {
      throw ArgumentError.value(method, 'method', 'طريقة حساب غير معروفة');
    }
  }

  final double latitude;
  final double longitude;
  final tz.Location location;
  final String method;

  /// أوقات التاريخ المحلي [date] (يؤخذ التاريخ فقط).
  DayPrayers forDate(DateTime date) {
    final pt = adhan.PrayerTimes(
      date: DateTime.utc(date.year, date.month, date.day),
      coordinates: adhan.Coordinates(latitude, longitude),
      calculationParameters: prayerMethods[method]!(),
    );
    tz.TZDateTime local(DateTime utc) => tz.TZDateTime.from(utc, location);
    return DayPrayers(DateTime(date.year, date.month, date.day), [
      PrayerTime(PrayerName.fajr, local(pt.fajr)),
      PrayerTime(PrayerName.sunrise, local(pt.sunrise)),
      PrayerTime(PrayerName.dhuhr, local(pt.dhuhr)),
      PrayerTime(PrayerName.asr, local(pt.asr)),
      PrayerTime(PrayerName.maghrib, local(pt.maghrib)),
      PrayerTime(PrayerName.isha, local(pt.isha)),
    ]);
  }

  /// الصلاة القادمة بعد اللحظة [now] (بعد العشاء: فجر الغد).
  PrayerTime nextPrayer(DateTime now) {
    final local = tz.TZDateTime.from(now, location);
    final today = forDate(local);
    for (final p in today.times) {
      if (p.name.isPrayer && p.time.isAfter(now)) return p;
    }
    final tomorrow = forDate(DateTime(local.year, local.month, local.day + 1));
    return tomorrow.times.first;
  }

  /// «باقي ٣٤ دقيقة» للصلاة القادمة بعد [now].
  String nextPrayerRemainingText(DateTime now) {
    final next = nextPrayer(now);
    final seconds = next.time.difference(now).inSeconds;
    return remainingMinutesText((seconds / 60).ceil());
  }
}
