// Prayer times for the family's location, Umm al-Qura method. Mirrors
// functions/src/prayer.ts, which checks the same window on the server.
import 'package:adhan/adhan.dart' as adhan;

import 'logic.dart';
import 'models.dart';

const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

const prayerNames = {'fajr': 'الفجر', 'dhuhr': 'الظهر', 'asr': 'العصر', 'maghrib': 'المغرب', 'isha': 'العشاء'};

const _riyadh = Duration(hours: 3);

/// Prayer times (UTC) on the Riyadh calendar day that contains [t].
Map<String, DateTime> prayerTimesOn(PrayerSettings s, DateTime t) {
  final d = t.toUtc().add(_riyadh);
  final p = adhan.PrayerTimes.utc(
    adhan.Coordinates(s.lat, s.lng),
    adhan.DateComponents(d.year, d.month, d.day),
    adhan.CalculationMethod.umm_al_qura.getParameters(),
  );
  return {'fajr': p.fajr, 'dhuhr': p.dhuhr, 'asr': p.asr, 'maghrib': p.maghrib, 'isha': p.isha};
}

/// Every prayer from yesterday to the day after [t], in order.
List<(String, DateTime)> _events(PrayerSettings s, DateTime t, {int days = 1}) => [
      for (var off = -1; off <= days; off++)
        for (final e in prayerTimesOn(s, t.add(Duration(days: off))).entries) (e.key, e.value),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

/// The prayer whose time is running at [now] (from its adhan until the next one).
PrayerSlot currentPrayer(PrayerSettings s, DateTime now) {
  final ev = _events(s, now);
  var i = ev.length - 2;
  while (i > 0 && ev[i].$2.isAfter(now)) {
    i--;
  }
  return PrayerSlot(key: ev[i].$1, start: ev[i].$2, end: ev[i + 1].$2, dayKey: dayKey(ev[i].$2));
}

/// Upcoming prayer times within [days] days, for the phone's reminders.
List<(String, DateTime)> upcomingPrayers(PrayerSettings s, DateTime now, {int days = 3}) =>
    _events(s, now, days: days).where((e) => e.$2.isAfter(now)).toList();

String prayerTaskId(String key, String personId) => 'prayer-$key-$personId';
