import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/backend/reminders.dart';
import 'package:asraty/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_backend_test.dart' show login;

void main() {
  final clock = DateTime.parse('2026-09-29T12:00:00+03:00');
  bool prayer(Iterable<(int, String, String, DateTime)> xs) => xs.any((x) => x.$1 >= 7000 && x.$1 < 8000);

  test('prayer reminders only for a member of a family that turned them on', () async {
    final b = DemoBackend(clock: () => clock);
    // The owner (an admin) never gets prayer reminders.
    var s = b.current;
    expect(Reminders.plan(s.data, s.me, clock).where((x) => x.$1 < 8000), isEmpty);

    await login(b, 'aseel@demo.sa', Role.member);
    s = b.current;
    expect(s.data!.prayer?.enabled, isTrue);
    final mine = Reminders.plan(s.data, s.me, clock);
    expect(prayer(mine), isTrue);
    expect(mine.where((x) => x.$1 < 8000).every((x) => x.$4.isAfter(clock)), isTrue, reason: 'only future prayers');

    // Signed out: nothing at all, so everything scheduled before is cancelled.
    expect(Reminders.plan(null, null, clock), isEmpty);

    // The owner turns the reminders off: the member's plan becomes empty of prayers.
    await login(b, 'abu@demo.sa', Role.owner);
    await b.setPrayer(lat: 24.7136, lng: 46.6753, points: 5, enabled: false);
    await login(b, 'aseel@demo.sa', Role.member);
    s = b.current;
    expect(prayer(Reminders.plan(s.data, s.me, clock)), isFalse);
  });
}
