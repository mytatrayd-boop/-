import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Person;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/models.dart';
import '../core/prayer.dart';
import 'push.dart';

/// Reminders scheduled on the phone itself, so they come on time without a
/// server scheduler: prayer times for members (the family's location), and
/// each prize an hour before its hand-over and at the hand-over.
class Reminders {
  static const _prayerBase = 7000, _prizeBase = 8000, _max = 60;
  static String _last = '';

  static Future<void> sync(FamilySnapshot? d, Person? me) async {
    if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) return;
    final now = DateTime.now();
    final items = <(int, String, String, DateTime)>[];
    final p = d?.prayer;
    if (d != null && me != null && p != null && p.enabled && me.role == Role.member) {
      var i = 0;
      for (final (k, at) in upcomingPrayers(p, now).take(_max ~/ 2)) {
        items.add((_prayerBase + i++, '🕌 صلاة ${prayerNames[k]}', 'حان الآن وقت صلاة ${prayerNames[k]}. أنجزها قبل دخول الصلاة التالية لتحصل على نقاطها.', at));
      }
    }
    if (d != null && me != null) {
      var i = 0;
      for (final z in d.prizes.where((z) => !z.awarded && z.awardAt.isAfter(now)).take(_max ~/ 4)) {
        items.add((_prizeBase + i++, '⏰ باقي ساعة على الجائزة', '${z.emoji} ${z.name}: تُسلَّم بعد ساعة لصاحب أعلى النقاط.', z.awardAt.subtract(const Duration(hours: 1))));
        items.add((_prizeBase + i++, '${z.emoji} حان موعد الجائزة', 'افتح التطبيق لترى الفائز بـ${z.name}.', z.awardAt));
      }
    }
    // Only reschedule when something changed (the app state updates often).
    final key = items.map((x) => '${x.$1}|${x.$2}|${x.$4.millisecondsSinceEpoch ~/ 60000}').join(',');
    if (key == _last) return;
    _last = key;
    try {
      await Push.initLocal();
      tzdata.initializeTimeZones();
      final n = Push.local;
      for (var i = 0; i < _max; i++) {
        await n.cancel(id: _prayerBase + i);
        await n.cancel(id: _prizeBase + i);
      }
      for (final (id, title, body, at) in items) {
        if (!at.isAfter(now)) continue;
        await n.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          notificationDetails: NotificationDetails(android: Push.androidDetails, iOS: const DarwinNotificationDetails(presentSound: true)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('reminders: $e');
    }
  }
}
