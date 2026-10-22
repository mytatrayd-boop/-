import 'package:asraty/core/logic.dart';
import 'package:asraty/core/models.dart';
import 'package:asraty/core/prayer.dart';
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

  test('month and year keys match the server', () {
    expect(monthKey(riyadh('2026-10-31T23:59:00')), 'm2026-10');
    expect(monthKey(DateTime.parse('2026-10-31T22:00:00Z')), 'm2026-11');
    expect(yearKey(DateTime.parse('2026-12-31T21:30:00Z')), 'y2027');
  });

  test('tasks repeat monthly and yearly; due counts per report period', () {
    final t = riyadh('2026-10-20T12:00:00'); // a Tuesday, day 20 of the month
    expect(periodKey(Period.monthly, t), 'm2026-10');
    expect(periodKey(Period.yearly, t), 'y2026');
    expect(dueCount(Period.daily, Span.daily, t), 1);
    expect(dueCount(Period.daily, Span.weekly, t), 3, reason: 'Sunday to Tuesday');
    expect(dueCount(Period.daily, Span.monthly, t), 20);
    expect(dueCount(Period.weekly, Span.daily, t), 0);
    expect(dueCount(Period.weekly, Span.weekly, t), 1);
    expect(dueCount(Period.weekly, Span.monthly, t), 4, reason: 'Oct 1 (Thu) to Oct 20 touches 4 weeks');
    expect(dueCount(Period.monthly, Span.yearly, t), 10);
    expect(dueCount(Period.yearly, Span.monthly, t), 0);
    expect(dueCount(Period.once, Span.yearly, t), 0);
  });

  test('prayer window runs from its adhan until the next prayer (matches the server)', () {
    const s = PrayerSettings(enabled: true, lat: 24.7136, lng: 46.6753, points: 5);
    final day = prayerTimesOn(s, riyadh('2026-10-20T12:00:00'));
    expect(dayKey(day['fajr']!), '2026-10-20');
    expect(day['dhuhr']!.isBefore(day['asr']!), isTrue);
    final noon = currentPrayer(s, day['dhuhr']!.add(const Duration(minutes: 1)));
    expect(noon.key, 'dhuhr');
    expect(noon.end, day['asr']);
    expect(noon.lateAt(day['dhuhr']!.add(const Duration(minutes: 10))), isFalse);
    expect(noon.lateAt(day['dhuhr']!.add(const Duration(minutes: 45))), isTrue);
    final night = currentPrayer(s, riyadh('2026-10-21T01:00:00'));
    expect(night.key, 'isha');
    expect(night.dayKey, '2026-10-20');
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
