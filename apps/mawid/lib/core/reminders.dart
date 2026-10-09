import '../model/programs.dart';
import 'payout_rules.dart';

class Reminder {
  final int id;
  final DateTime when;
  final String title, body;
  const Reminder(this.id, this.when, this.title, this.body);
}

/// يخطط التنبيهات القادمة (9 صباحاً). iOS يسمح بـ 64 تنبيهاً معلّقاً، فنكتفي بأقرب [maxCount].
List<Reminder> planReminders(
  DateTime now,
  List<Program> ps, {
  required bool d3,
  required bool d1,
  required bool d0,
  int horizonDays = 75,
  int maxCount = 60,
}) {
  final out = <Reminder>[];
  final limit = now.add(Duration(days: horizonDays));
  for (var pi = 0; pi < ps.length; pi++) {
    final p = ps[pi];
    for (var k = 0; k <= 3; k++) {
      final first = DateTime(now.year, now.month + k, 1);
      final e = effectiveDate(first.year, first.month, p.day);
      final what = '${p.name}: ${weekdayAr[e.weekday]} ${e.day} ${monthAr[e.month - 1]}';
      final opts = <(int, bool, String)>[
        (3, d3, 'بعد 3 أيام — $what'),
        (1, d1, 'غداً — $what'),
        (0, d0, 'اليوم — $what'),
      ];
      for (final (before, on, body) in opts) {
        if (!on) continue;
        final d = e.subtract(Duration(days: before));
        final when = DateTime(d.year, d.month, d.day, 9);
        if (!when.isAfter(now) || when.isAfter(limit)) continue;
        final id = ((e.year % 100) * 10000 + e.month * 100 + e.day) * 100 + pi * 10 + before;
        out.add(Reminder(id, when, 'موعد', body));
      }
    }
  }
  out.sort((a, b) => a.when.compareTo(b.when));
  return out.take(maxCount).toList();
}
