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
    expect(s.data!.familyEarned(Period.daily), 30);
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
    final before = b.current.data!.earned(aseel.id, Period.daily);
    await b.completeTask(newTask.id);
    final pending = b.current.data!.completions.singleWhere((c) => c.taskId == newTask.id);
    expect(pending.status, Status.pending);

    await login(b, 'um@demo.sa', Role.admin);
    await b.decideCompletion(pending.id, true); // um has `approve`
    expect(b.current.data!.earned(aseel.id, Period.daily), before + 7);
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

  test('timed alerts end, and removing a member removes their alerts and private rewards', () async {
    var now = clock;
    final b = DemoBackend(clock: () => now);
    final lama = b.current.data!.members.firstWhere((m) => m.name == 'لمى');
    await b.sendAlert(lama.id, 'العشاء جاهز', minutes: 30);
    final alert = b.current.data!.notices.first;
    expect(alert.activeAt(now), isTrue);
    now = now.add(const Duration(minutes: 31));
    expect(alert.activeAt(now), isFalse);
    expect(b.current.data!.tiers.where((t) => t.personId == lama.id), isNotEmpty);

    await b.removePerson(lama.id);
    final d = b.current.data!;
    expect(d.notices.where((n) => n.to == lama.id), isEmpty);
    expect(d.tiers.where((t) => t.personId == lama.id), isEmpty);
  });
}
