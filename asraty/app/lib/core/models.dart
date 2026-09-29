enum Role { owner, admin, member }

enum Perm { addMembers, approve, tasks, report, comps, viewReports }

enum Period { daily, weekly }

enum Scope { each, family }

enum Status { pending, approved, rejected }

T _enum<T extends Enum>(List<T> values, Object? v, T fallback) {
  for (final e in values) {
    if (e.name == v) return e;
  }
  return fallback;
}

Role roleFrom(Object? v) => _enum(Role.values, v, Role.member);
Period periodFrom(Object? v) => _enum(Period.values, v, Period.daily);
Scope scopeFrom(Object? v) => _enum(Scope.values, v, Scope.each);
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
  }) : perms = perms ?? {};

  final String id;
  String name;
  String email;
  Role role;
  String avatar;
  bool active;
  Map<Perm, bool> perms;
}

class TaskItem {
  TaskItem({required this.id, required this.title, required this.personId, required this.points, required this.repeat});
  final String id;
  String title;
  String personId;
  int points;
  Period repeat;
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
  });
  final String id;
  final String taskId;
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

class Tier {
  Tier({required this.id, required this.name, required this.emoji, required this.threshold, required this.period, required this.scope});
  final String id;
  final String name;
  final String emoji;
  final int threshold;
  final Period period;
  final Scope scope;
}

class Notice {
  Notice({required this.id, required this.to, required this.title, required this.body, required this.from, required this.createdAt, List<String>? readBy})
      : readBy = readBy ?? [];
  final String id;
  final String to; // 'all' or personId
  final String title;
  final String body;
  final String from;
  final DateTime createdAt;
  final List<String> readBy;
}

class PeriodSum {
  const PeriodSum(this.points, this.count);
  final int points;
  final int count;
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
    required this.tiers,
    required this.deliveries,
    required this.notices,
    required this.daily,
    required this.weekly,
  });

  final String familyName;
  final List<Person> people;
  final List<TaskItem> tasks;
  final List<Completion> completions;
  final List<Competition> competitions;
  final List<Tier> tiers;
  final Set<String> deliveries; // "{tierId}_{who}_{periodKey}"
  final List<Notice> notices;
  final Map<String, PeriodSum> daily; // personId -> today's points
  final Map<String, PeriodSum> weekly; // personId -> this week's points
}
