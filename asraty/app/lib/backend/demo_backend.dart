import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'backend.dart';

final _rnd = Random();
String _uid() => List.generate(8, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rnd.nextInt(36)]).join();

class _Log {
  _Log(this.personId, this.delta, this.at);
  final String personId;
  final int delta;
  final DateTime at;
}

class _Code {
  _Code(this.code, this.at);
  final String code;
  final DateTime at;
  int attempts = 0;
}

/// On-device trial backend. Mirrors the server rules (functions/src/api.ts) so
/// the demo behaves like the real app, but everything stays in memory and no
/// email leaves the device: messages go to the in-app demo mailbox instead.
/// Messages built here mirror the server's (Arabic) email and notice texts.
class DemoBackend extends Backend {
  DemoBackend({bool seeded = true, DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    if (seeded) _seed();
    _publish();
  }

  final DateTime Function() _clock;
  DateTime get _now => _clock();

  String? _familyName;
  final _people = <Person>[];
  final _tasks = <TaskItem>[];
  final _completions = <Completion>[];
  final _comps = <Competition>[];
  final _tiers = <Tier>[];
  final _delivered = <String>{};
  final _notices = <Notice>[];
  final _log = <_Log>[];
  final _codes = <String, _Code>{};
  final _photos = <String, Uint8List>{};
  final _mail = <DemoMail>[];
  ({String familyName, String name})? _pendingSetup;
  String? _me;

  @override
  bool get isDemo => true;

  @override
  List<DemoMail> get outbox => List.unmodifiable(_mail);

  Person? get _meP => _me == null ? null : _people.where((p) => p.id == _me).firstOrNull;

  void _publish() {
    final me = _meP;
    if (me == null || _familyName == null) {
      emit(const AppState());
      return;
    }
    final now = _now;
    Map<String, PeriodSum> sums(Period p) {
      final key = periodKey(p, now);
      final m = <String, PeriodSum>{};
      for (final l in _log) {
        if (l.delta <= 0 || periodKey(p, l.at) != key) continue;
        final s = m[l.personId];
        m[l.personId] = PeriodSum((s?.points ?? 0) + l.delta, (s?.count ?? 0) + 1);
      }
      return m;
    }

    emit(AppState(
      session: Session(personId: me.id, familyId: 'demo', role: me.role),
      data: FamilySnapshot(
        familyName: _familyName!,
        people: List.of(_people),
        tasks: List.of(_tasks),
        completions: List.of(_completions),
        competitions: List.of(_comps),
        tiers: List.of(_tiers),
        deliveries: Set.of(_delivered),
        notices: me.role == Role.member ? _notices.where((n) => n.to == 'all' || n.to == me.id).toList() : List.of(_notices),
        daily: sums(Period.daily),
        weekly: sums(Period.weekly),
      ),
    ));
  }

  Never _fail(String code, [Map<String, dynamic> d = const {}]) => throw AppError(code, d);

  Person _need([Perm? perm, bool owner = false]) {
    final me = _meP ?? _fail('unauthenticated');
    if (owner && me.role != Role.owner) _fail('no-permission');
    if (perm != null && !can(me, perm)) _fail('no-permission');
    return me;
  }

  Person _person(String id) => _people.where((p) => p.id == id).firstOrNull ?? _fail('person-not-found');

  void _sendCode(String email, String subject, String intro) {
    final code = (100000 + _rnd.nextInt(900000)).toString();
    _codes[email] = _Code(code, _now);
    _mail.insert(0, DemoMail(email, subject, '$intro\n\nكود التحقق: $code\nصالح لمدة 30 دقيقة.', _now));
    if (_mail.length > 40) _mail.removeLast();
  }

  void _note(String to, String title, String body) {
    _notices.insert(0, Notice(id: _uid(), to: to, title: title, body: body, from: _meP?.name ?? '', createdAt: _now));
  }

  void _addLog(String personId, int delta) => _log.insert(0, _Log(personId, delta, _now));

  // ---------------------------------------------------------------- seed
  void _seed() {
    final now = _now;
    _familyName = 'أسرة آل محمد';
    Person p(String name, String email, String avatar, Role role, bool active, [Map<Perm, bool>? perms]) =>
        Person(id: _uid(), name: name, email: email, role: role, avatar: avatar, active: active, perms: perms);
    final o = p('أبو أصيل', 'abu@demo.sa', 'dad', Role.owner, true);
    final a = p('أم أصيل', 'um@demo.sa', 'mom', Role.admin, true, {Perm.approve: true, Perm.tasks: true, Perm.viewReports: true});
    final k1 = p('أصيل', 'aseel@demo.sa', 'boy', Role.member, true);
    final k2 = p('لمى', 'lama@demo.sa', 'girl', Role.member, true);
    final k3 = p('سلمان', 'salman@demo.sa', 'boy2', Role.member, false);
    _people.addAll([o, a, k1, k2, k3]);
    TaskItem t(String title, Person m, int pts, Period rep) => TaskItem(id: _uid(), title: title, personId: m.id, points: pts, repeat: rep);
    final t1 = t('ترتيب السرير', k1, 5, Period.daily), t2 = t('مراجعة الرياضيات', k1, 10, Period.daily);
    final t3 = t('قراءة صفحة قرآن', k2, 10, Period.daily), t4 = t('المساعدة في ترتيب المجلس', k2, 15, Period.weekly);
    final t5 = t('ترتيب الألعاب', k3, 5, Period.daily);
    _tasks.addAll([t1, t2, t3, t4, t5]);
    Completion c(TaskItem t, Status st, Duration ago) => Completion(
        id: _uid(), taskId: t.id, personId: t.personId, title: t.title, points: t.points,
        periodKey: periodKey(t.repeat, now), status: st, createdAt: now.subtract(ago));
    const h = Duration(hours: 1);
    _completions.addAll([c(t1, Status.approved, h * 2), c(t2, Status.approved, h), c(t4, Status.approved, const Duration(minutes: 30)), c(t3, Status.pending, const Duration(minutes: 10))]);
    // Keep seeded points inside today's period even right after midnight.
    DateTime ago(Duration d) {
      final x = now.subtract(d);
      return dayKey(x) == dayKey(now) ? x : now;
    }
    _log.addAll([_Log(k1.id, 5, ago(h * 2)), _Log(k1.id, 10, ago(h)), _Log(k2.id, 15, ago(const Duration(minutes: 30)))]);
    _tiers.addAll([
      Tier(id: _uid(), name: 'نزهة عائلية', emoji: '🏞️', threshold: 66, period: Period.weekly, scope: Scope.each),
      Tier(id: _uid(), name: 'وجبة خارجية', emoji: '🍔', threshold: 30, period: Period.weekly, scope: Scope.each),
      Tier(id: _uid(), name: 'ساعة ألعاب إضافية', emoji: '🎮', threshold: 15, period: Period.daily, scope: Scope.each),
    ]);
    _codes[k3.email] = _Code('482915', now);
    _mail.add(DemoMail(k3.email, 'دعوة للانضمام إلى أسرة آل محمد',
        'أضافك أبو أصيل إلى أسرة آل محمد في تطبيق أسرتي.\nللربط: افتح التطبيق، اختر «أحد أفراد الأسرة»، أدخل بريدك ثم هذا الكود.\n\nكود التحقق: 482915\nصالح لمدة 30 دقيقة.', now));
    _me = o.id;
  }

  // ---------------------------------------------------------------- auth
  @override
  Future<bool> requestCode({required String email, required Role role, String? familyName, String? name, bool resend = false}) async {
    final u = _people.where((p) => p.email == email).firstOrNull;
    _pendingSetup = null;
    if (role != Role.member) {
      if (u?.role == Role.member) _fail('registered-as-member');
      if (u == null) {
        if (_familyName != null) _fail('not-admin-of-family', {'familyName': _familyName});
        final f = familyName?.trim() ?? '', n = name?.trim() ?? '';
        if (f.isEmpty || n.isEmpty) _fail('setup-needed');
        _pendingSetup = (familyName: f, name: n);
      }
    } else {
      if (u != null && u.role != Role.member) _fail('registered-as-admin');
      if (u == null) _fail('not-invited');
    }
    final c = _codes[email];
    if (!resend && c != null && _now.difference(c.at).inMinutes < 30) return false;
    _sendCode(email, 'كود الدخول إلى أسرتي',
        resend ? 'كود تحقق جديد لتسجيل الدخول إلى تطبيق أسرتي.' : 'هذا كود التحقق لتسجيل الدخول إلى تطبيق أسرتي.');
    _publish();
    return true;
  }

  @override
  Future<VerifyResult> verifyCode({required String email, required String code}) async {
    final c = _codes[email];
    if (c == null) _fail('bad-code');
    if (_now.difference(c.at).inMinutes >= 30) _fail('code-expired');
    if (c.attempts >= 5) _fail('too-many-attempts');
    if (c.code != code) {
      c.attempts++;
      _fail('bad-code');
    }
    _codes.remove(email);
    var u = _people.where((p) => p.email == email).firstOrNull;
    if (u == null) {
      final s = _pendingSetup ?? _fail('bad-code');
      _familyName = s.familyName;
      u = Person(id: _uid(), name: s.name, email: email, role: Role.owner, avatar: 'dad', active: true);
      _people.add(u);
    }
    final first = !u.active;
    u.active = true;
    _me = u.id;
    _publish();
    return VerifyResult(first: first, familyName: _familyName!, name: u.name);
  }

  @override
  Future<void> signOut() async {
    _me = null;
    _publish();
  }

  // ---------------------------------------------------------------- people
  ({String subject, String intro}) _invite(Role role, String inviter, {bool reminder = false}) {
    final where = role == Role.member ? '«أحد أفراد الأسرة»' : '«مسؤول الأسرة»';
    if (reminder) {
      return (subject: 'تذكير: دعوة للانضمام إلى $_familyName', intro: 'للربط: افتح تطبيق أسرتي، اختر $where، أدخل بريدك ثم هذا الكود.');
    }
    final how = 'للربط: افتح التطبيق، اختر $where، أدخل بريدك ثم هذا الكود.';
    return role == Role.member
        ? (subject: 'دعوة للانضمام إلى $_familyName', intro: 'أضافك $inviter إلى $_familyName في تطبيق أسرتي.\n$how')
        : (subject: 'تمت إضافتك مسؤولاً في $_familyName', intro: 'أضافك $inviter مسؤولاً في $_familyName على تطبيق أسرتي.\n$how');
  }

  @override
  Future<void> addPerson({required Role role, required String name, required String email, required String avatar, Map<Perm, bool>? perms}) async {
    final me = role == Role.admin ? _need(null, true) : _need(Perm.addMembers);
    if (_people.any((p) => p.email == email)) _fail('email-taken');
    _people.add(Person(id: _uid(), name: name, email: email, role: role, avatar: avatar, active: false, perms: role == Role.admin ? perms : {}));
    final m = _invite(role, me.name);
    _sendCode(email, m.subject, m.intro);
    _publish();
  }

  @override
  Future<void> resendInvite(String personId) async {
    final p = _person(personId);
    final me = p.role == Role.member ? _need(Perm.addMembers) : _need(null, true);
    final m = _invite(p.role, me.name, reminder: true);
    _sendCode(p.email, m.subject, m.intro);
    _publish();
  }

  @override
  Future<void> updatePerms(String personId, Map<Perm, bool> perms) async {
    _need(null, true);
    _person(personId).perms = Map.of(perms);
    _publish();
  }

  @override
  Future<void> removePerson(String personId) async {
    final p = _person(personId);
    if (p.role == Role.owner) _fail('cannot-remove-owner');
    p.role == Role.member ? _need(Perm.addMembers) : _need(null, true);
    _people.remove(p);
    _tasks.removeWhere((t) => t.personId == personId);
    _publish();
  }

  @override
  Future<void> setAvatar(String personId, String avatar) async {
    final me = _need();
    final p = _person(personId);
    if (!(p.id == me.id || me.role == Role.owner || (p.role == Role.member && can(me, Perm.addMembers)))) _fail('no-permission');
    p.avatar = avatar;
    _publish();
  }

  // ---------------------------------------------------------------- tasks
  @override
  Future<void> addTask({required String title, required String personId, required int points, required Period repeat}) async {
    _need(Perm.tasks);
    final members = _people.where((p) => p.role == Role.member);
    for (final m in personId == 'all' ? members : members.where((m) => m.id == personId)) {
      _tasks.add(TaskItem(id: _uid(), title: title, personId: m.id, points: points, repeat: repeat));
    }
    _publish();
  }

  @override
  Future<void> updateTask({required String taskId, required String title, required String personId, required int points, required Period repeat}) async {
    _need(Perm.tasks);
    final t = _tasks.where((t) => t.id == taskId).firstOrNull ?? _fail('task-not-found');
    t
      ..title = title.isEmpty ? t.title : title
      ..personId = personId
      ..points = points
      ..repeat = repeat;
    _publish();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _need(Perm.tasks);
    _tasks.removeWhere((t) => t.id == taskId);
    _publish();
  }

  @override
  Future<void> completeTask(String taskId, {Uint8List? photo}) async {
    final me = _need();
    final t = _tasks.where((t) => t.id == taskId && t.personId == me.id).firstOrNull ?? _fail('task-not-found');
    final key = periodKey(t.repeat, _now);
    if (_completions.any((c) => c.taskId == t.id && c.periodKey == key && c.status != Status.rejected)) _fail('already-done');
    final id = _uid();
    if (photo != null) _photos[id] = photo;
    _completions.add(Completion(
        id: id, taskId: t.id, personId: me.id, title: t.title, points: t.points, periodKey: key,
        status: Status.pending, createdAt: _now, photoPath: photo != null ? id : null));
    _publish();
  }

  @override
  Future<void> decideCompletion(String completionId, bool approve) async {
    _need(Perm.approve);
    final c = _completions.where((c) => c.id == completionId).firstOrNull ?? _fail('not-found');
    if (c.status != Status.pending) _fail('already-decided');
    c.status = approve ? Status.approved : Status.rejected;
    _photos.remove(c.photoPath);
    c.photoPath = null;
    if (approve) _addLog(c.personId, c.points);
    _publish();
  }

  @override
  Future<ImageProvider?> proofImage(Completion c) async {
    final b = _photos[c.photoPath];
    return b == null ? null : MemoryImage(b);
  }

  // ---------------------------------------------------------------- competitions
  @override
  Future<void> addCompetition({required String title, required int startPoints, required int minutes}) async {
    _need(Perm.comps);
    _comps.insert(0, Competition(
        id: _uid(), title: title, startPoints: startPoints, createdAt: _now,
        deadline: minutes > 0 ? _now.add(Duration(minutes: minutes)) : null));
    _note('all', '🏁 مسابقة جديدة',
        '$title\nأول من ينجز يحصل على $startPoints نقطة، والتالي أقل بنقطة.${minutes > 0 ? '\nالوقت المتاح: $minutes دقيقة.' : ''}');
    _publish();
  }

  @override
  Future<void> endCompetition(String compId) async {
    _need(Perm.comps);
    _comps.where((c) => c.id == compId).firstOrNull?.ended = true;
    _publish();
  }

  @override
  Future<({int rank, int points})> enterCompetition(String compId) async {
    final me = _need();
    final c = _comps.where((c) => c.id == compId).firstOrNull ?? _fail('not-found');
    if (!c.activeAt(_now)) _fail('comp-over');
    if (c.entries.containsKey(me.id)) _fail('already-entered');
    final rank = c.entries.length + 1, pts = competitionPoints(c.startPoints, rank);
    c.entries[me.id] = Entry(personId: me.id, rank: rank, points: pts, status: Status.pending);
    _publish();
    return (rank: rank, points: pts);
  }

  @override
  Future<void> decideEntry(String compId, String personId, bool approve) async {
    _need(Perm.approve);
    final c = _comps.where((c) => c.id == compId).firstOrNull ?? _fail('not-found');
    final e = c.entries[personId] ?? _fail('not-found');
    if (e.status != Status.pending) _fail('already-decided');
    e.status = approve ? Status.approved : Status.rejected;
    if (approve) _addLog(personId, e.points);
    _publish();
  }

  // ---------------------------------------------------------------- rewards
  @override
  Future<void> addTier({required String name, required String emoji, required int threshold, required Period period, required Scope scope}) async {
    _need(null, true);
    _tiers.add(Tier(id: _uid(), name: name, emoji: emoji, threshold: threshold, period: period, scope: scope));
    _publish();
  }

  @override
  Future<void> deleteTier(String tierId) async {
    _need(null, true);
    _tiers.removeWhere((t) => t.id == tierId);
    _publish();
  }

  @override
  Future<void> deliver(String tierId, String who, String periodKey) async {
    _need(null, true);
    _delivered.add('${tierId}_${who}_$periodKey');
    _publish();
  }

  // ---------------------------------------------------------------- notices
  @override
  Future<void> sendAlert(String to, String body) async {
    final me = _need(null, true);
    _note(to, '🔔 تنبيه من ${me.name}', body);
    _publish();
  }

  @override
  Future<void> sendReport() async {
    _need(Perm.report);
    final s = current.data!;
    final r = s.ranking(Period.daily);
    final lines = [for (var i = 0; i < r.length; i++) '${medal(i)} ${r[i].person.name}: ${r[i].points} نقطة (${r[i].count} إنجاز)'];
    _note('all', '🏆 ترتيب إنجاز اليوم', 'ترتيب إنجاز اليوم\n\n${lines.join('\n')}\n\nمجموع الأسرة: ${s.familyEarned(Period.daily)} نقطة');
    _publish();
  }

  @override
  Future<void> markRead() async {
    final me = _need();
    for (final n in _notices) {
      if ((n.to == 'all' || n.to == me.id) && !n.readBy.contains(me.id)) n.readBy.add(me.id);
    }
    _publish();
  }

  // ---------------------------------------------------------------- account
  @override
  Future<void> deleteAccount() async {
    final me = _need();
    if (me.role == Role.owner) _fail('owner-must-delete-family');
    _people.remove(me);
    _tasks.removeWhere((t) => t.personId == me.id);
    _me = null;
    _publish();
  }

  @override
  Future<void> deleteFamily() async {
    _need(null, true);
    _familyName = null;
    for (final l in [_people, _tasks, _completions, _comps, _tiers, _notices, _log]) {
      l.clear();
    }
    _delivered.clear();
    _codes.clear();
    _photos.clear();
    _me = null;
    _publish();
  }

  @override
  Future<void> sendFeedback({required String type, required String text, String? email, required String platform}) async {
    const labels = {'suggestion': 'اقتراح', 'complaint': 'شكوى', 'bug': 'مشكلة تقنية'};
    final me = _meP;
    _mail.insert(0, DemoMail('asraty200@gmail.com', '[${labels[type]}] من ${me?.name ?? 'زائر'}',
        '$text\n\n— البريد: ${me?.email ?? (email?.isNotEmpty == true ? email : 'لم يُذكر')}\n— الجهاز: $platform', _now));
    _publish();
  }
}
