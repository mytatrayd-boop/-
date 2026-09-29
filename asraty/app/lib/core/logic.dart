// Domain logic ported from design/prototype.html (pk/dk/wk, tierOf, ranking,
// reportText). Display-only on the client: the server is the source of truth
// for points and permissions.
import 'models.dart';

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

String periodKey(Period p, DateTime t) => p == Period.daily ? dayKey(t) : weekKey(t);

bool can(Person? p, Perm perm) {
  if (p == null) return false;
  if (p.role == Role.owner) return true;
  return p.role == Role.admin && (p.perms[perm] ?? false);
}

int competitionPoints(int start, int rank) => (start - (rank - 1)).clamp(1, 1 << 30);

Tier? tierOf(List<Tier> tiers, int pts, Period p, Scope s) {
  final ok = tiers.where((t) => t.period == p && t.scope == s && pts >= t.threshold).toList()
    ..sort((a, b) => b.threshold.compareTo(a.threshold));
  return ok.isEmpty ? null : ok.first;
}

Tier? nextTier(List<Tier> tiers, int pts, Period p, Scope s) {
  final ok = tiers.where((t) => t.period == p && t.scope == s && pts < t.threshold).toList()
    ..sort((a, b) => a.threshold.compareTo(b.threshold));
  return ok.isEmpty ? null : ok.first;
}

String medal(int i) => i < 3 ? const ['🥇', '🥈', '🥉'][i] : '${i + 1}';

class RankRow {
  RankRow(this.person, this.points, this.count);
  final Person person;
  final int points;
  final int count;
}

extension SnapshotLogic on FamilySnapshot {
  List<Person> get members => people.where((p) => p.role == Role.member).toList();

  Person? person(String id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  int earned(String personId, Period p) => (p == Period.daily ? daily : weekly)[personId]?.points ?? 0;
  int earnedCount(String personId, Period p) => (p == Period.daily ? daily : weekly)[personId]?.count ?? 0;
  int familyEarned(Period p) => members.fold(0, (a, m) => a + earned(m.id, p));

  List<RankRow> ranking(Period p) =>
      members.map((m) => RankRow(m, earned(m.id, p), earnedCount(m.id, p))).toList()
        ..sort((a, b) => b.points.compareTo(a.points));

  /// Current completion of a task in its current period (non-rejected), if any.
  Completion? completionOf(TaskItem t, DateTime now) {
    final key = periodKey(t.repeat, now);
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
