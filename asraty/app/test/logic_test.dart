import 'package:asraty/core/logic.dart';
import 'package:asraty/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime riyadh(String iso) => DateTime.parse('$iso+03:00');

void main() {
  test('dayKey uses Riyadh time', () {
    expect(dayKey(riyadh('2026-09-29T23:30:00')), '2026-09-29');
    expect(dayKey(DateTime.parse('2026-09-29T22:00:00Z')), '2026-09-30');
  });

  test('weekKey starts on Sunday (matches the server)', () {
    expect(weekKey(riyadh('2026-09-27T00:00:00')), 'w2026-09-27');
    expect(weekKey(riyadh('2026-10-03T23:59:00')), 'w2026-09-27');
    expect(weekKey(riyadh('2026-10-04T00:00:00')), 'w2026-10-04');
    expect(weekKey(riyadh('2027-01-01T10:00:00')), 'w2026-12-27');
  });

  test('tierOf picks the highest reached tier only within period and scope', () {
    Tier tier(String id, int thr, Period p) => Tier(id: id, name: id, emoji: '🎁', threshold: thr, period: p, scope: Scope.each);
    final tiers = [tier('trip', 66, Period.weekly), tier('meal', 30, Period.weekly), tier('games', 15, Period.daily)];
    expect(tierOf(tiers, 66, Period.weekly, Scope.each)?.id, 'trip');
    expect(tierOf(tiers, 30, Period.weekly, Scope.each)?.id, 'meal');
    expect(tierOf(tiers, 29, Period.weekly, Scope.each), isNull);
    expect(nextTier(tiers, 40, Period.weekly, Scope.each)?.id, 'trip');
    expect(tierOf(tiers, 100, Period.weekly, Scope.family), isNull);
  });

  test('permissions', () {
    Person p(Role r, [Map<Perm, bool>? perms]) => Person(id: 'x', name: 'x', email: 'x', role: r, avatar: 'boy', active: true, perms: perms);
    expect(can(p(Role.owner), Perm.approve), isTrue);
    expect(can(p(Role.admin, {Perm.approve: true}), Perm.approve), isTrue);
    expect(can(p(Role.admin, {Perm.tasks: true}), Perm.approve), isFalse);
    expect(can(p(Role.member, {Perm.approve: true}), Perm.approve), isFalse);
  });

  test('competition points', () {
    expect([1, 2, 3].map((r) => competitionPoints(20, r)), [20, 19, 18]);
    expect(competitionPoints(3, 9), 1);
  });
}
