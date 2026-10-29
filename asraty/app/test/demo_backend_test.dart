import 'dart:typed_data';

import 'package:asraty/backend/backend.dart';
import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/core/logic.dart';
import 'package:asraty/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signs into the demo as [email]; codes are read from the demo mailbox.
Future<void> login(DemoBackend b, String email, Role role) async {
  await b.signOut();
  await b.requestCode(email: email, role: role, resend: true);
  final code = RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!;
  await b.verifyCode(email: email, code: code);
}

void main() {
  // Midday in Riyadh, so seeded "hours ago" data stays in today's period.
  final clock = DateTime.parse('2026-09-29T12:00:00+03:00');

  test('seeded demo matches the prototype', () {
    final b = DemoBackend(clock: () => clock);
    final s = b.current;
    expect(s.signedIn, isTrue);
    expect(s.me!.role, Role.owner);
    expect(s.data!.members.length, 3);
    expect(s.data!.familyEarnedFor(Span.daily), 30);
    expect(s.data!.pendingCount(), 1);
  });

  test('task completion → approval adds points to the member', () async {
    final b = DemoBackend(clock: () => clock);
    await login(b, 'aseel@demo.sa', Role.member);
    final aseel = b.current.me!;
    await expectLater(b.addTask(title: 'x', personId: aseel.id, points: 7, repeat: Period.daily),
        throwsA(isA<AppError>().having((e) => e.code, 'code', 'no-permission')));
    final mine = b.current.data!.tasks.where((t) => t.personId == aseel.id && t.title == 'ترتيب السرير').single;
    // Already approved today in the seed → cannot submit again this period.
    expect(() => b.completeTask(mine.id), throwsA(isA<AppError>()));

    await login(b, 'abu@demo.sa', Role.admin);
    await b.addTask(title: 'سقي النباتات', personId: aseel.id, points: 7, repeat: Period.daily);
    final newTask = b.current.data!.tasks.singleWhere((t) => t.title == 'سقي النباتات');

    await login(b, 'aseel@demo.sa', Role.member);
    final before = b.current.data!.earned(aseel.id, Span.daily);
    await b.completeTask(newTask.id);
    final pending = b.current.data!.completions.singleWhere((c) => c.taskId == newTask.id);
    expect(pending.status, Status.pending);

    await login(b, 'um@demo.sa', Role.admin);
    await b.decideCompletion(pending.id, true); // um has `approve`
    expect(b.current.data!.earned(aseel.id, Span.daily), before + 7);
    expect(() => b.decideCompletion(pending.id, true), throwsA(isA<AppError>()));
  });

  test('competition ranks: 20, 19, … and rejection keeps ranks', () async {
    final b = DemoBackend(clock: () => clock);
    await b.addCompetition(title: 'أسرع من يرتّب غرفته', startPoints: 20, minutes: 0);
    final comp = b.current.data!.competitions.first;

    await login(b, 'lama@demo.sa', Role.member);
    expect((await b.enterCompetition(comp.id)).points, 20);
    expect(() => b.enterCompetition(comp.id), throwsA(isA<AppError>()));
    await login(b, 'aseel@demo.sa', Role.member);
    final r = await b.enterCompetition(comp.id);
    expect((r.rank, r.points), (2, 19));

    await login(b, 'abu@demo.sa', Role.admin);
    final lama = b.current.data!.people.singleWhere((p) => p.name == 'لمى');
    await b.decideEntry(comp.id, lama.id, false);
    await b.endCompetition(comp.id);
    await login(b, 'salman@demo.sa', Role.member);
    expect(() => b.enterCompetition(comp.id), throwsA(isA<AppError>()));
  });

  test('login errors guide to the right role', () async {
    final b = DemoBackend(clock: () => clock);
    await b.signOut();
    Future<String> code(Future<void> f) => f.then((_) => 'ok', onError: (Object e) => (e as AppError).code);
    expect(await code(b.requestCode(email: 'aseel@demo.sa', role: Role.admin)), 'registered-as-member');
    expect(await code(b.requestCode(email: 'um@demo.sa', role: Role.member)), 'registered-as-admin');
    expect(await code(b.requestCode(email: 'nobody@demo.sa', role: Role.member)), 'not-invited');
    await b.requestCode(email: 'aseel@demo.sa', role: Role.member, resend: true);
    for (var i = 0; i < 5; i++) {
      expect(await code(b.verifyCode(email: 'aseel@demo.sa', code: '000000')), 'bad-code');
    }
    expect(await code(b.verifyCode(email: 'aseel@demo.sa', code: '000000')), 'too-many-attempts');
  });

  test('new family setup from an empty demo', () async {
    final b = DemoBackend(seeded: false, clock: () => clock);
    await b.requestCode(email: 'new@x.sa', role: Role.admin, familyName: 'أسرة آل سعد', name: 'أبو سعد');
    final c = RegExp(r'(\d{6})').firstMatch(b.outbox.first.body)!.group(1)!;
    final r = await b.verifyCode(email: 'new@x.sa', code: c);
    expect(r.familyName, 'أسرة آل سعد');
    expect(b.current.me!.role, Role.owner);
    expect(periodKey(Period.weekly, clock), 'w2026-09-27');
  });

  test('honor board: month/year points and family goals', () async {
    final b = DemoBackend(clock: () => clock);
    final d = b.current.data!;
    expect(d.honorRanking(Honor.monthly).first.points, 15);
    expect(d.honorRanking(Honor.yearly).fold(0, (a, r) => a + r.points), 30);
    final goal = d.goals.firstWhere((g) => g.personId == 'family');
    for (var i = 0; i < 20; i++) {
      await b.goalProgress(goal.id, 1);
    }
    final after = b.current.data!.goals.firstWhere((g) => g.id == goal.id);
    expect(after.progress, after.target, reason: 'capped at the target');
    expect(b.current.data!.notices.where((n) => n.title == '🎉 تحقق الهدف').length, 1);

    await login(b, 'aseel@demo.sa', Role.member);
    await expectLater(b.addGoal(title: 'x', target: 3, personId: 'family', period: Honor.monthly),
        throwsA(isA<AppError>().having((e) => e.code, 'code', 'no-permission')));
  });

  test('timed alerts end, and removing a member removes their alerts', () async {
    var now = clock;
    final b = DemoBackend(clock: () => now);
    final lama = b.current.data!.members.firstWhere((m) => m.name == 'لمى');
    await b.sendAlert(lama.id, 'العشاء جاهز', minutes: 30);
    final alert = b.current.data!.notices.first;
    expect(alert.activeAt(now), isTrue);
    now = now.add(const Duration(minutes: 31));
    expect(alert.activeAt(now), isFalse);

    await b.removePerson(lama.id);
    final d = b.current.data!;
    expect(d.notices.where((n) => n.to == lama.id), isEmpty);
  });

  test('one-time tasks, for one member or everyone, stay done once approved', () async {
    var now = clock;
    final b = DemoBackend(clock: () => now);
    final aseel = b.current.data!.members.firstWhere((m) => m.name == 'أصيل');
    await b.addTask(title: 'تنظيف السيارة', personId: 'all', points: 20, repeat: Period.once);
    final mine = b.current.data!.tasks.where((t) => t.title == 'تنظيف السيارة').toList();
    expect(mine.length, b.current.data!.members.length, reason: 'one copy per member');
    final task = mine.firstWhere((t) => t.personId == aseel.id);

    await login(b, 'aseel@demo.sa', Role.member);
    await b.completeTask(task.id);
    await login(b, 'abu@demo.sa', Role.admin);
    final c = b.current.data!.completions.firstWhere((c) => c.taskId == task.id);
    expect(c.periodKey, 'once');
    await b.decideCompletion(c.id, true);

    now = now.add(const Duration(days: 9)); // a later day and week
    await login(b, 'aseel@demo.sa', Role.member);
    await expectLater(b.completeTask(task.id), throwsA(isA<AppError>().having((e) => e.code, 'code', 'already-done')));
  });

  test('password: set with a code, then sign in; wrong password refused', () async {
    final b = DemoBackend(clock: () => clock);
    await b.signOut();
    Future<String> code(Future<void> f) => f.then((_) => 'ok', onError: (Object e) => (e as AppError).code);
    expect(await code(b.login(email: 'aseel@demo.sa', password: 'abcdef')), 'no-password');
    expect(await code(b.requestCode(email: 'aseel@demo.sa', role: Role.member, password: '123')), 'weak-password');
    await b.requestCode(email: 'aseel@demo.sa', role: Role.member, password: 'abcdef');
    final c = RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!;
    await b.verifyCode(email: 'aseel@demo.sa', code: c);
    await b.signOut();
    expect(await code(b.login(email: 'aseel@demo.sa', password: 'wrong1')), 'bad-login');
    await b.login(email: 'aseel@demo.sa', password: 'abcdef');
    expect(b.current.me!.name, 'أصيل');
    await b.signOut();
    await b.login(email: 'abu@demo.sa', password: '123456');
    expect(b.current.me!.role, Role.owner);
  });

  test('prizes: reminder an hour before, then the top member wins with a card for everyone', () async {
    var now = clock;
    final b = DemoBackend(clock: () => now);
    await b.addPrize(name: 'رحلة', emoji: '🏆', period: Span.daily, awardAt: now.add(const Duration(hours: 2)));
    await expectLater(b.addPrize(name: 'x', emoji: '🎁', period: Span.daily, awardAt: now.subtract(const Duration(minutes: 1))),
        throwsA(isA<AppError>().having((e) => e.code, 'code', 'bad-time')));
    now = now.add(const Duration(minutes: 70));
    await b.tick();
    expect(b.current.data!.notices.where((n) => n.title == '⏰ باقي ساعة على الجائزة').length, 1);
    now = now.add(const Duration(hours: 1));
    await b.tick();
    await b.tick();
    final prize = b.current.data!.prizes.firstWhere((p) => p.name == 'رحلة');
    expect(prize.awarded, isTrue);
    final aseel = b.current.data!.members.firstWhere((m) => m.name == 'أصيل');
    expect(prize.winnerId, aseel.id, reason: 'most points today in the seed (15)');
    final cards = b.current.data!.notices.where((n) => n.kind == 'prize' && n.title.contains('أصيل'));
    expect(cards.length, 1);
    expect(cards.single.to, 'all');
  });

  test('avatar: portraits, own photo, and a parent lock', () async {
    final b = DemoBackend(clock: () => clock);
    final lama = b.current.data!.members.firstWhere((m) => m.name == 'لمى');
    await login(b, 'lama@demo.sa', Role.member);
    await b.setAvatar(lama.id, 'photo', photo: Uint8List.fromList([0xff, 0xd8, 1, 2]));
    expect(b.current.me!.photo, isNotNull);
    await b.setAvatar(lama.id, 'girl_rose');
    expect(b.current.me!.photo, isNull);
    await expectLater(b.setAvatarLock(lama.id, true), throwsA(isA<AppError>().having((e) => e.code, 'code', 'no-permission')));
    await login(b, 'abu@demo.sa', Role.admin);
    await b.setAvatarLock(lama.id, true);
    await login(b, 'lama@demo.sa', Role.member);
    await expectLater(b.setAvatar(lama.id, 'girl_pink'), throwsA(isA<AppError>().having((e) => e.code, 'code', 'avatar-locked')));
  });

  test('prayer: the running prayer is a task worth its points; reports count done and not-done tasks', () async {
    final b = DemoBackend(clock: () => clock);
    final aseel = b.current.data!.members.firstWhere((m) => m.name == 'أصيل');
    await login(b, 'aseel@demo.sa', Role.member);
    final ts = b.current.data!.tasksOf(aseel.id, clock);
    final prayer = ts.first;
    expect(prayer.prayer, isNotNull);
    expect(prayer.title, startsWith('صلاة '));
    await b.completeTask(prayer.id);
    await login(b, 'abu@demo.sa', Role.admin);
    final c = b.current.data!.completions.firstWhere((c) => c.taskId == prayer.id);
    await b.decideCompletion(c.id, true);
    final row = b.current.data!.rankingFor(Span.daily, clock).firstWhere((r) => r.person.id == aseel.id);
    expect(row.points, 15 + 5);
    expect(row.done, 2, reason: 'the prayer is not counted as a task');
    expect(row.notDone, 0, reason: 'both daily tasks are done (the monthly task is not due in a daily report)');
  });

  test('prayer: half an hour after its adhan it stays as a task but is worth no points', () async {
    final b = DemoBackend(clock: () => clock);
    final aseel = b.current.data!.members.firstWhere((m) => m.name == 'أصيل');
    final d = b.current.data!;
    final slot = d.tasksOf(aseel.id, clock).first.prayer!;
    final early = d.tasksOf(aseel.id, slot.start.add(const Duration(minutes: 10))).first;
    final late = d.tasksOf(aseel.id, slot.start.add(const Duration(minutes: 31))).first;
    expect(early.points, 5);
    expect(late.prayer, isNotNull, reason: 'still listed until the next prayer');
    expect(late.points, 0);
  });

  test('violation takes points from one member or everyone; deleting it gives them back', () async {
    final b = DemoBackend(clock: () => clock);
    final d0 = b.current.data!;
    final aseel = d0.members.firstWhere((m) => m.name == 'أصيل');
    final before = {for (final m in d0.members) m.id: d0.daily[m.id]?.points ?? 0};
    final countBefore = d0.daily[aseel.id]?.count ?? 0;
    await b.addViolation(personId: aseel.id, points: 4, reason: 'رفع الصوت');
    var d = b.current.data!;
    expect(d.daily[aseel.id]!.points, before[aseel.id]! - 4);
    expect(d.daily[aseel.id]!.count, countBefore, reason: 'a violation is not an achievement');
    expect(d.violations.single.points, 4);
    await b.addViolation(personId: 'all', points: 2);
    d = b.current.data!;
    for (final m in d.members) {
      expect(d.daily[m.id]?.points ?? 0, before[m.id]! - 2 - (m.id == aseel.id ? 4 : 0));
    }
    // The member sees a violation notice with the points taken.
    await login(b, 'aseel@demo.sa', Role.member);
    final notes = b.current.data!.noticesFor(b.current.me!).where((n) => n.kind == 'violation').toList();
    expect(notes.map((n) => n.points), containsAll([4, 2]));
    await expectLater(b.addViolation(personId: 'all', points: 1), throwsA(isA<AppError>()));
    await login(b, 'abu@demo.sa', Role.admin);
    await b.deleteViolation(b.current.data!.violations.firstWhere((v) => v.points == 4).id);
    d = b.current.data!;
    expect(d.daily[aseel.id]!.points, before[aseel.id]! - 2);
    expect(d.notices.where((n) => n.kind == 'violation' && n.points == 4), isEmpty);
  });

  test('a new evaluation cycle wipes every point', () async {
    final b = DemoBackend(clock: () => clock);
    expect(b.current.data!.familyEarnedFor(Span.daily), greaterThan(0));
    await b.newCycle();
    final d = b.current.data!;
    expect(d.familyEarnedFor(Span.daily), 0);
    expect(d.familyEarnedFor(Span.yearly), 0);
    expect(d.cycleStartedAt, clock);
    expect(d.notices.first.title, contains('دورة تقييم جديدة'));
    await login(b, 'aseel@demo.sa', Role.member);
    await expectLater(b.newCycle(), throwsA(isA<AppError>()));
  });

  test('an activation code works on one device only', () async {
    final b = DemoBackend(seeded: false, clock: () => clock);
    await b.redeemCode('asr-ab12-cd34', 'device-one');
    await b.redeemCode('ASR-AB12-CD34', 'device-one');
    await expectLater(b.redeemCode('ASR-AB12-CD34', 'device-two'), throwsA(isA<AppError>().having((e) => e.code, 'code', 'code-used')));
    await expectLater(b.redeemCode('nope', 'device-one'), throwsA(isA<AppError>().having((e) => e.code, 'code', 'code-invalid')));
  });
}
