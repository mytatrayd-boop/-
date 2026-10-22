enum Role { owner, admin, member }

enum Perm { addMembers, approve, tasks, report, comps, viewReports }

/// How often a task repeats: every day, week, month or year, or [once] only.
enum Period { daily, weekly, monthly, yearly, once }

enum Status { pending, approved, rejected }

/// Report and prize periods.
enum Span { daily, weekly, monthly, yearly }

/// Honor board periods (separate from [Period], which drives tasks and rewards).
enum Honor { monthly, yearly }

T _enum<T extends Enum>(List<T> values, Object? v, T fallback) {
  for (final e in values) {
    if (e.name == v) return e;
  }
  return fallback;
}

Role roleFrom(Object? v) => _enum(Role.values, v, Role.member);
Period periodFrom(Object? v) => _enum(Period.values, v, Period.daily);
Span spanFrom(Object? v) => _enum(Span.values, v, Span.daily);
Status statusFrom(Object? v) => _enum(Status.values, v, Status.pending);

Map<Perm, bool> permsFrom(Object? v) {
  final m = v is Map ? v : const {};
  return {for (final p in Perm.values) p: m[p.name] == true};
}

Map<String, bool> permsToJson(Map<Perm, bool> p) => {for (final e in p.entries) e.key.name: e.value};

class Session {
  const Session({required this.personId, required this.familyId, required this.role});
  final String personId;
  final String familyId;
  final Role role;
}

class Person {
  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatar,
    required this.active,
    Map<Perm, bool>? perms,
    this.avatarLocked = false,
    this.photo,
  }) : perms = perms ?? {};

  final String id;
  String name;
  String email;
  Role role;
  String avatar;
  bool active;
  Map<Perm, bool> perms;

  /// A parent locked this member's avatar.
  bool avatarLocked;

  /// Base64 JPEG when [avatar] is "photo" (uploaded from the device).
  String? photo;
}

class TaskItem {
  TaskItem({required this.id, required this.title, required this.personId, required this.points, required this.repeat, this.prayer});
  final String id;
  String title;
  String personId;
  int points;
  Period repeat;

  /// Set on the generated task of the prayer whose time is running.
  final PrayerSlot? prayer;
}

/// The running prayer for a member: open from its adhan until the next one.
class PrayerSlot {
  const PrayerSlot({required this.key, required this.start, required this.end, required this.dayKey});
  final String key; // fajr | dhuhr | asr | maghrib | isha
  final DateTime start, end;
  final String dayKey;

  /// Shown as late once half an hour has passed without it.
  bool lateAt(DateTime now) => now.difference(start) > const Duration(minutes: 30);
}

/// Prayer reminders, set by the owner from their phone's location.
class PrayerSettings {
  const PrayerSettings({required this.enabled, required this.lat, required this.lng, required this.points});
  final bool enabled;
  final double lat, lng;
  final int points;
}

/// A prize: the member with the most points in [period] wins it at [awardAt].
class Prize {
  Prize({required this.id, required this.name, required this.emoji, required this.period, required this.awardAt, this.awarded = false, this.winnerId, this.winnerPoints = 0});
  final String id;
  final String name;
  final String emoji;
  final Span period;
  final DateTime awardAt;
  bool awarded;
  String? winnerId;
  int winnerPoints;
}

class Completion {
  Completion({
    required this.id,
    required this.taskId,
    required this.personId,
    required this.title,
    required this.points,
    required this.periodKey,
    required this.status,
    required this.createdAt,
    this.photoPath,
    this.prayer = false,
  });
  final String id;
  final String taskId;
  final bool prayer;
  final String personId;
  final String title;
  final int points;
  final String periodKey;
  Status status;
  final DateTime createdAt;
  String? photoPath;
}

class Entry {
  Entry({required this.personId, required this.rank, required this.points, required this.status});
  final String personId;
  final int rank;
  final int points;
  Status status;
}

class Competition {
  Competition({
    required this.id,
    required this.title,
    required this.startPoints,
    required this.createdAt,
    this.deadline,
    this.ended = false,
    Map<String, Entry>? entries,
  }) : entries = entries ?? {};
  final String id;
  final String title;
  final int startPoints;
  final DateTime createdAt;
  final DateTime? deadline;
  bool ended;
  final Map<String, Entry> entries;

  bool activeAt(DateTime now) => !ended && (deadline == null || now.isBefore(deadline!));
}

/// A family goal on the honor board (e.g. read 12 books this year).
class Goal {
  Goal({required this.id, required this.title, required this.target, required this.progress, required this.personId, required this.period, required this.periodKey});
  final String id;
  final String title;
  final int target;
  int progress;
  final String personId; // 'family' or a member id
  final Honor period;
  final String periodKey;

  bool get reached => progress >= target;
}

class Notice {
  Notice({required this.id, required this.to, required this.title, required this.body, required this.from, required this.createdAt, this.expiresAt, List<String>? readBy, this.kind = 'notice'})
      : readBy = readBy ?? [];

  /// 'prize' for the congratulation card sent to everyone when a prize is won.
  final String kind;
  final String id;
  final String to; // 'all' or personId
  final String title;
  final String body;
  final String from;
  final DateTime createdAt;

  /// Timed alert: active until then, shown as ended afterwards (and removed by the server a day later).
  final DateTime? expiresAt;
  final List<String> readBy;

  bool activeAt(DateTime now) => expiresAt == null || now.isBefore(expiresAt!);
}

class PeriodSum {
  const PeriodSum(this.points, this.count, [this.tasks = 0]);
  final int points;
  final int count;

  /// Approved tasks only (no prayers or competitions), for the done / not-done report.
  final int tasks;
}

/// A sent email, shown only in the local demo (the prototype's "📧" mailbox).
class DemoMail {
  DemoMail(this.to, this.subject, this.body, this.at);
  final String to;
  final String subject;
  final String body;
  final DateTime at;
}

class SentFeedback {
  SentFeedback(this.type, this.text, this.at);
  final String type;
  final String text;
  final DateTime at;
}

/// Everything the UI needs about the signed-in family, for the current periods.
class FamilySnapshot {
  FamilySnapshot({
    required this.familyName,
    required this.people,
    required this.tasks,
    required this.completions,
    required this.competitions,
    required this.notices,
    required this.daily,
    required this.weekly,
    this.monthly = const {},
    this.yearly = const {},
    this.goals = const [],
    this.prizes = const [],
    this.prayer,
  });

  final String familyName;
  final List<Person> people;
  final List<TaskItem> tasks;
  final List<Completion> completions;
  final List<Competition> competitions;
  final List<Notice> notices;
  final Map<String, PeriodSum> daily; // personId -> today's points
  final Map<String, PeriodSum> weekly; // personId -> this week's points
  final Map<String, PeriodSum> monthly; // personId -> this month's points (honor board)
  final Map<String, PeriodSum> yearly; // personId -> this year's points (honor board)
  final List<Goal> goals;
  final List<Prize> prizes;
  final PrayerSettings? prayer;
}
