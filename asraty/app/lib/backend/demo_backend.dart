import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'backend.dart';

final _rnd = Random();
String _uid() => List.generate(8, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rnd.nextInt(36)]).join();

class _Log {
  _Log(this.personId, this.delta, this.at, [this.task = true]);
  final String personId;
  final int delta;
  final DateTime at;

  /// A done task (not a prayer or a competition), for the done / not-done report.
  final bool task;
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
  final _prizes = <Prize>[];
  final _passwords = <String, String>{};
  final _pendingPassword = <String, String>{};
  PrayerSettings? _prayer;
  final _notices = <Notice>[];
  final _goals = <Goal>[];
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
    _sweep();
    final me = _meP;
    if (me == null || _familyName == null) {
      emit(const AppState());
      return;
    }
    final now = _now;
    Map<String, PeriodSum> sums(String Function(DateTime) keyOf) {
      final key = keyOf(now);
      final m = <String, PeriodSum>{};
      for (final l in _log) {
        if (l.delta <= 0 || keyOf(l.at) != key) continue;
        final s = m[l.personId];
        m[l.personId] = PeriodSum((s?.points ?? 0) + l.delta, (s?.count ?? 0) + 1, (s?.tasks ?? 0) + (l.task ? 1 : 0));
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
        prizes: List.of(_prizes),
        prayer: _prayer,
        goals: _goals.where((g) => g.periodKey == honorKey(g.period, now)).toList(),
        notices: me.role == Role.member ? _notices.where((n) => n.to == 'all' || n.to == me.id).toList() : List.of(_notices),
        daily: sums(dayKey),
        weekly: sums(weekKey),
        monthly: sums(monthKey),
        yearly: sums(yearKey),
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

  void _note(String to, String title, String body, {DateTime? expiresAt}) {
    _notices.insert(0, Notice(id: _uid(), to: to, title: title, body: body, from: _meP?.name ?? '', createdAt: _now, expiresAt: expiresAt));
  }

  /// What the server's removePersonData deletes along with the person.
  void _dropPerson(Person p) {
    _people.remove(p);
    _tasks.removeWhere((t) => t.personId == p.id);
    _notices.removeWhere((n) => n.to == p.id);
    _goals.removeWhere((g) => g.personId == p.id);
  }

  void _addLog(String personId, int delta, {bool task = true}) => _log.insert(0, _Log(personId, delta, _now, task));

  static const _spanWord = {Span.daily: 'اليوم', Span.weekly: 'الأسبوع', Span.monthly: 'الشهر', Span.yearly: 'السنة'};
  final _reminded = <String>{};

  /// Mirrors the server's sweepPrizes: a reminder an hour before, then the top member wins.
  void _sweep() {
    final now = _now;
    for (final p in _prizes.where((p) => !p.awarded)) {
      if (p.awardAt.isAfter(now)) {
        if (p.awardAt.difference(now) <= const Duration(hours: 1) && _reminded.add(p.id)) {
          _notices.insert(0, Notice(id: _uid(), to: 'all', title: '⏰ باقي ساعة على الجائزة',
              body: '${p.emoji} ${p.name}: تُسلَّم بعد ساعة لصاحب أعلى نقاط ${_spanWord[p.period]}.', from: 'أسرتي', createdAt: now));
        }
        continue;
      }
      final key = spanKey(p.period, p.awardAt.subtract(const Duration(seconds: 1)));
      final pts = <String, int>{};
      for (final l in _log) {
        if (l.delta > 0 && spanKey(p.period, l.at) == key) pts[l.personId] = (pts[l.personId] ?? 0) + l.delta;
      }
      final members = _people.where((x) => x.role == Role.member && (pts[x.id] ?? 0) > 0).toList()
        ..sort((a, b) => (pts[b.id] ?? 0).compareTo(pts[a.id] ?? 0));
      p.awarded = true;
      final w = members.firstOrNull;
      p.winnerId = w?.id;
      p.winnerPoints = w == null ? 0 : pts[w.id]!;
      _notices.insert(0, w == null
          ? Notice(id: _uid(), to: 'all', title: '${p.emoji} ${p.name}', body: 'حان موعد الجائزة ولم يجمع أحد نقاطاً ${_spanWord[p.period]}.', from: 'أسرتي', createdAt: now, kind: 'prize')
          : Notice(id: _uid(), to: 'all', title: '🎉 مبروك يا ${w.name}!',
              body: 'فاز ${w.name} بجائزة ${p.emoji} ${p.name}\nبأعلى نقاط ${_spanWord[p.period]}: ${p.winnerPoints} نقطة. ألف مبروك!', from: 'أسرتي', createdAt: now, kind: 'prize'));
    }
  }

  // ---------------------------------------------------------------- seed
  void _seed() {
    final now = _now;
    _familyName = 'أسرة آل محمد';
    Person p(String name, String email, String avatar, Role role, bool active, [Map<Perm, bool>? perms]) =>
        Person(id: _uid(), name: name, email: email, role: role, avatar: avatar, active: active, perms: perms);
    final o = p('أبو أصيل', 'abu@demo.sa', 'dad_shemagh', Role.owner, true);
    final a = p('أم أصيل', 'um@demo.sa', 'mom_purple', Role.admin, true, {Perm.approve: true, Perm.tasks: true, Perm.viewReports: true});
    final k1 = p('أصيل', 'aseel@demo.sa', 'boy_shemagh', Role.member, true);
    final k2 = p('لمى', 'lama@demo.sa', 'girl_pink', Role.member, true);
    final k3 = p('سلمان', 'salman@demo.sa', 'boy_ghutra', Role.member, false);
    _people.addAll([o, a, k1, k2, k3]);
    TaskItem t(String title, Person m, int pts, Period rep) => TaskItem(id: _uid(), title: title, personId: m.id, points: pts, repeat: rep);
    final t1 = t('ترتيب السرير', k1, 5, Period.daily), t2 = t('مراجعة الرياضيات', k1, 10, Period.daily);
    final t3 = t('قراءة صفحة قرآن', k2, 10, Period.daily), t4 = t('المساعدة في ترتيب المجلس', k2, 15, Period.weekly);
    final t5 = t('ترتيب الألعاب', k3, 5, Period.daily), t6 = t('تنظيف الدرج', k1, 30, Period.monthly);
    _tasks.addAll([t1, t2, t3, t4, t5, t6]);
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
    // Today's prize, handed over at 9 pm Riyadh time (tomorrow's if that has passed).
    final r = now.toUtc().add(const Duration(hours: 3));
    var at = DateTime.utc(r.year, r.month, r.day, 21 - 3);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    _prizes.add(Prize(id: _uid(), name: 'آيسكريم من اختيارك', emoji: '🍦', period: Span.daily, awardAt: at));
    _prayer = const PrayerSettings(enabled: true, lat: 24.7136, lng: 46.6753, points: 5);
    _goals.addAll([
      Goal(id: _uid(), title: 'قراءة 12 كتاباً', target: 12, progress: 3, personId: 'family', period: Honor.yearly, periodKey: yearKey(now)),
      Goal(id: _uid(), title: 'حفظ سورة الملك', target: 30, progress: 18, personId: k1.id, period: Honor.monthly, periodKey: monthKey(now)),
    ]);
    _codes[k3.email] = _Code('482915', now);
    _passwords['abu@demo.sa'] = '123456';
    _mail.add(DemoMail(k3.email, 'دعوة للانضمام إلى أسرة آل محمد',
        'أضافك أبو أصيل إلى أسرة آل محمد في تطبيق أسرتي.\nللربط: افتح التطبيق، اختر «أحد أفراد الأسرة»، أدخل بريدك ثم هذا الكود.\n\nكود التحقق: 482915\nصالح لمدة 30 دقيقة.', now));
    _me = o.id;
  }

  // ---------------------------------------------------------------- auth
  @override
  Future<bool> requestCode({required String email, required Role role, String? familyName, String? name, String? password, bool resend = false}) async {
    if (password != null && password.length < 6) _fail('weak-password');
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
    if (password != null) {
      _pendingPassword[email] = password;
    } else if (!resend && c != null && _now.difference(c.at).inMinutes < 30) {
      return false;
    }
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
    final pw = _pendingPassword.remove(email);
    if (pw != null) _passwords[email] = pw;
    var u = _people.where((p) => p.email == email).firstOrNull;
    if (u == null) {
      final s = _pendingSetup ?? _fail('bad-code');
      _familyName = s.familyName;
      u = Person(id: _uid(), name: s.name, email: email, role: Role.owner, avatar: 'dad_shemagh', active: true);
      _people.add(u);
    }
    final first = !u.active;
    u.active = true;
    _me = u.id;
    _publish();
    return VerifyResult(first: first, familyName: _familyName!, name: u.name);
  }

  @override
  Future<VerifyResult> login({required String email, required String password}) async {
    final u = _people.where((p) => p.email == email).firstOrNull ?? _fail('bad-login');
    final pw = _passwords[email] ?? _fail('no-password');
    if (pw != password) _fail('bad-login');
    u.active = true;
    _me = u.id;
    _publish();
    return VerifyResult(first: false, familyName: _familyName!, name: u.name);
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
    _dropPerson(p);
    _publish();
  }

  @override
  Future<void> setAvatar(String personId, String avatar, {Uint8List? photo}) async {
    final me = _need();
    final p = _person(personId);
    final manager = me.role == Role.owner || (p.role == Role.member && can(me, Perm.addMembers));
    if (!(manager || (p.id == me.id && !(p.role == Role.member && p.avatarLocked)))) _fail('avatar-locked');
    p
      ..avatar = avatar
      ..photo = photo == null ? null : base64Encode(photo);
    _publish();
  }

  @override
  Future<void> setAvatarLock(String personId, bool locked) async {
    _need(Perm.addMembers);
    _person(personId).avatarLocked = locked;
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
    final t = current.data?.tasksOf(me.id, _now).where((t) => t.id == taskId).firstOrNull ??
        (taskId.startsWith('prayer-') ? _fail('prayer-over') : _fail('task-not-found'));
    final key = t.prayer?.dayKey ?? periodKey(t.repeat, _now);
    if (_completions.any((c) => c.taskId == t.id && c.periodKey == key && c.status != Status.rejected)) _fail('already-done');
    final id = _uid();
    if (photo != null) _photos[id] = photo;
    _completions.add(Completion(
        id: id, taskId: t.id, personId: me.id, title: t.title, points: t.points, periodKey: key,
        status: Status.pending, createdAt: _now, photoPath: photo != null ? id : null, prayer: t.prayer != null));
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
    if (approve) _addLog(c.personId, c.points, task: !c.prayer);
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
    if (approve) _addLog(personId, e.points, task: false);
    _publish();
  }

  // ---------------------------------------------------------------- prizes
  @override
  Future<void> addPrize({required String name, required String emoji, required Span period, required DateTime awardAt}) async {
    _need(null, true);
    if (!awardAt.isAfter(_now)) _fail('bad-time');
    _prizes
      ..add(Prize(id: _uid(), name: name, emoji: emoji, period: period, awardAt: awardAt))
      ..sort((a, b) => a.awardAt.compareTo(b.awardAt));
    _note('all', '$emoji جائزة جديدة', '$name\nلصاحب أعلى نقاط ${_spanWord[period]}.');
    _publish();
  }

  @override
  Future<void> deletePrize(String prizeId) async {
    _need(null, true);
    _prizes.removeWhere((p) => p.id == prizeId);
    _publish();
  }

  @override
  Future<void> tick() async => _publish();

  @override
  Future<void> setPrayer({required double lat, required double lng, required int points, required bool enabled}) async {
    _need(null, true);
    _prayer = PrayerSettings(enabled: enabled, lat: lat, lng: lng, points: points);
    _publish();
  }

  // ---------------------------------------------------------------- notices
  @override
  Future<void> sendAlert(String to, String body, {int minutes = 0}) async {
    final me = _need(null, true);
    _note(to, '🔔 تنبيه من ${me.name}', body, expiresAt: minutes > 0 ? _now.add(Duration(minutes: minutes)) : null);
    _publish();
  }

  @override
  Future<void> deleteAlert(String noticeId) async {
    _need(null, true);
    _notices.removeWhere((n) => n.id == noticeId);
    _publish();
  }

  // ---------------------------------------------------------------- goals
  @override
  Future<void> addGoal({required String title, required int target, required String personId, required Honor period}) async {
    _need(Perm.tasks);
    if (personId != 'family' && _person(personId).role != Role.member) _fail('person-not-found');
    _goals.add(Goal(id: _uid(), title: title, target: target, progress: 0, personId: personId, period: period, periodKey: honorKey(period, _now)));
    final who = personId == 'family' ? 'للأسرة' : 'لـ${_person(personId).name}';
    _note(personId == 'family' ? 'all' : personId, '🎯 هدف جديد', '$title ($target) $who ${period == Honor.yearly ? 'هذه السنة' : 'هذا الشهر'}');
    _publish();
  }

  @override
  Future<void> goalProgress(String goalId, int delta) async {
    _need(Perm.tasks);
    final g = _goals.where((g) => g.id == goalId).firstOrNull ?? _fail('not-found');
    final was = g.reached;
    g.progress = (g.progress + delta).clamp(0, g.target);
    if (g.reached && !was) _note(g.personId == 'family' ? 'all' : g.personId, '🎉 تحقق الهدف', '${g.title} (${g.target})');
    _publish();
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    _need(Perm.tasks);
    _goals.removeWhere((g) => g.id == goalId);
    _publish();
  }

  @override
  Future<void> sendReport({Span span = Span.daily}) async {
    _need(Perm.report);
    final s = current.data!;
    final r = s.rankingFor(span);
    final title = const {
      Span.daily: 'ترتيب إنجاز اليوم', Span.weekly: 'ترتيب إنجاز الأسبوع', Span.monthly: 'ترتيب إنجاز الشهر', Span.yearly: 'ترتيب إنجاز السنة',
    }[span]!;
    final lines = [for (var i = 0; i < r.length; i++) '${medal(i)} ${r[i].person.name}: ${r[i].points} نقطة (${r[i].count} إنجاز)'];
    _note('all', '🏆 $title', '$title\n\n${lines.join('\n')}\n\nمجموع الأسرة: ${s.familyEarnedFor(span)} نقطة');
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
    _dropPerson(me);
    _me = null;
    _publish();
  }

  @override
  Future<void> deleteFamily() async {
    _need(null, true);
    _familyName = null;
    for (final l in [_people, _tasks, _completions, _comps, _prizes, _notices, _goals, _log]) {
      l.clear();
    }
    _prayer = null;
    _passwords.clear();
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
