// Domain logic ported from design/prototype.html (pk/dk/wk, tierOf, ranking,
// reportText). Display-only on the client: the server is the source of truth
// for points and permissions.
import 'dart:math' as math;

import 'models.dart';
import 'prayer.dart';

const _riyadhOffset = Duration(hours: 3); // Asia/Riyadh, no DST.

String _pad(int n) => n.toString().padLeft(2, '0');

DateTime _riyadh(DateTime t) => t.toUtc().add(_riyadhOffset);

String dayKey(DateTime t) {
  final d = _riyadh(t);
  return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
}

/// "w" + Riyadh date of the Sunday that starts the week.
String weekKey(DateTime t) {
  final d = _riyadh(t);
  final sunday = DateTime.utc(d.year, d.month, d.day - (d.weekday % 7));
  return 'w${sunday.year}-${_pad(sunday.month)}-${_pad(sunday.day)}';
}

/// Honor board keys: "m" + Riyadh YYYY-MM and "y" + Riyadh year.
String monthKey(DateTime t) => 'm${dayKey(t).substring(0, 7)}';
String yearKey(DateTime t) => 'y${dayKey(t).substring(0, 4)}';
String honorKey(Honor h, DateTime t) => h == Honor.monthly ? monthKey(t) : yearKey(t);

/// A one-time task's single period is "once": done once, it stays done.
String periodKey(Period p, DateTime t) => switch (p) {
      Period.daily => dayKey(t),
      Period.weekly => weekKey(t),
      Period.monthly => monthKey(t),
      Period.yearly => yearKey(t),
      Period.once => 'once',
    };

String spanKey(Span s, DateTime t) => switch (s) { Span.daily => dayKey(t), Span.weekly => weekKey(t), Span.monthly => monthKey(t), Span.yearly => yearKey(t) };

/// How many times a task repeating every [p] falls due within the current [s] so far
/// (e.g. a daily task, 3 days into the week, counts 3 for the weekly report).
int dueCount(Period p, Span s, DateTime now) {
  final d = _riyadh(now);
  final today = DateTime.utc(d.year, d.month, d.day);
  final start = switch (s) {
    Span.daily => today,
    Span.weekly => today.subtract(Duration(days: d.weekday % 7)),
    Span.monthly => DateTime.utc(d.year, d.month),
    Span.yearly => DateTime.utc(d.year),
  };
  final days = today.difference(start).inDays + 1;
  return switch (p) {
    Period.daily => days,
    Period.weekly => s == Span.daily ? 0 : (s == Span.weekly ? 1 : ((days + start.weekday % 7 + 6) ~/ 7)),
    Period.monthly => s == Span.monthly || s == Span.yearly ? (s == Span.monthly ? 1 : d.month) : 0,
    Period.yearly => s == Span.yearly ? 1 : 0,
    Period.once => 0,
  };
}

/// An old hand-made prayer task ("صلاة الفجر"...). Mirrors functions/src/logic.ts isManualPrayerTitle.
bool isManualPrayerTitle(String title) => RegExp('صلا[ةه]').hasMatch(title);

bool can(Person? p, Perm perm) {
  if (p == null) return false;
  if (p.role == Role.owner) return true;
  return p.role == Role.admin && (p.perms[perm] ?? false);
}

int competitionPoints(int start, int rank) => (start - (rank - 1)).clamp(1, 1 << 30);

String medal(int i) => i < 3 ? const ['🥇', '🥈', '🥉'][i] : '${i + 1}';

class RankRow {
  RankRow(this.person, this.points, this.count, [this.done = 0, this.notDone = 0]);
  final Person person;
  final int points;
  final int count;

  /// Approved tasks in the period, and the ones due so far that are not done.
  final int done, notDone;
}

extension SnapshotLogic on FamilySnapshot {
  List<Person> get members => people.where((p) => p.role == Role.member).toList();

  Person? person(String id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  int earned(String personId, Span s) => sumsFor(s)[personId]?.points ?? 0;

  Map<String, PeriodSum> sumsFor(Span s) => switch (s) {
        Span.daily => daily,
        Span.weekly => weekly,
        Span.monthly => monthly,
        Span.yearly => yearly,
      };

  /// Report ranking for any period, most points first, with done / not-done tasks.
  List<RankRow> rankingFor(Span s, [DateTime? at]) {
    final m = sumsFor(s), now = at ?? DateTime.now();
    return members.map((x) {
      final done = m[x.id]?.tasks ?? 0;
      final due = tasks.where((t) => t.personId == x.id).fold(0, (a, t) => a + dueCount(t.repeat, s, now));
      return RankRow(x, m[x.id]?.points ?? 0, m[x.id]?.count ?? 0, done, (due - done).clamp(0, 1 << 30));
    }).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
  }

  /// 1-based place of a member in the period (ties share the place).
  int placeOf(String personId, Span s) {
    final m = sumsFor(s);
    final mine = m[personId]?.points ?? 0;
    return 1 + members.where((x) => (m[x.id]?.points ?? 0) > mine).length;
  }

  /// A member's tasks, plus the prayer whose time is running when reminders are on: worth its points for
  /// half an hour after the adhan (Isha until 11 pm), then still listed but worth nothing, until the next
  /// prayer. With the automatic prayers on, old hand-made prayer tasks are hidden from the member; the
  /// admin's list ([admin]) still shows them, marked, so they can be deleted.
  List<TaskItem> tasksOf(String personId, DateTime now, {bool admin = false}) {
    final own = tasks.where((x) => x.personId == personId).toList();
    final p = prayer;
    if (p == null || !p.enabled || person(personId)?.role != Role.member) return own;
    final slot = currentPrayer(p, now);
    final legacy = own.where((x) => isManualPrayerTitle(x.title)).toList();
    return [
      TaskItem(id: prayerTaskId(slot.key, personId), title: 'صلاة ${prayerNames[slot.key]}', personId: personId, points: slot.lateAt(now) ? 0 : p.points, repeat: Period.daily, prayer: slot),
      ...own.where((x) => !isManualPrayerTitle(x.title)),
      if (admin) ...[for (final x in legacy) TaskItem(id: x.id, title: x.title, personId: x.personId, points: x.points, repeat: x.repeat, legacyPrayer: true)],
    ];
  }

  int familyEarnedFor(Span s) => sumsFor(s).entries.where((e) => members.any((m) => m.id == e.key)).fold(0, (a, e) => a + e.value.points);

  /// Honor board ranking for this month or year.
  List<RankRow> honorRanking(Honor h) {
    final m = h == Honor.monthly ? monthly : yearly;
    return members.map((x) => RankRow(x, m[x.id]?.points ?? 0, m[x.id]?.count ?? 0)).toList()..sort((a, b) => b.points.compareTo(a.points));
  }

  /// Current completion of a task in its current period (non-rejected), if any.
  Completion? completionOf(TaskItem t, DateTime now) {
    final key = t.prayer?.dayKey ?? periodKey(t.repeat, now);
    Completion? found;
    for (final c in completions) {
      if (c.taskId == t.id && c.periodKey == key && c.status != Status.rejected) found = c;
    }
    return found;
  }

  int pendingCount() =>
      completions.where((c) => c.status == Status.pending).length +
      competitions.fold(0, (a, c) => a + c.entries.values.where((e) => e.status == Status.pending).length);

  List<Notice> noticesFor(Person u) => notices.where((n) => n.to == 'all' || n.to == u.id).toList();
}

// ---------------------------------------------------------------- family trip ("أنا هنا")

/// Great-circle distance in metres (same formula as functions/src/logic.ts distanceMeters).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371000 * math.asin(math.min(1.0, math.sqrt(h)));
}

/// May [actor] switch sharing on/off for [target]? Children are managed by a trip admin.
bool canToggleShare(Person actor, Person target) => can(actor, Perm.trip) || (actor.id == target.id && actor.role != Role.member);
