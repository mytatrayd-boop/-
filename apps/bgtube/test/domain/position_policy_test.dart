import 'package:bgtube/domain/position_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const total = Duration(minutes: 10);
  PositionAction d(Duration p, [Duration? t = total]) =>
      PositionPolicy.decide(p, t);

  test('under 10 seconds is skipped', () {
    expect(d(Duration.zero), PositionAction.skip);
    expect(
      d(const Duration(seconds: 9, milliseconds: 999)),
      PositionAction.skip,
    );
  });

  test('exactly 10 seconds is saved', () {
    expect(d(const Duration(seconds: 10)), PositionAction.save);
  });

  test('5:00 of 10:00 is saved', () {
    expect(d(const Duration(minutes: 5)), PositionAction.save);
  });

  test('within 10 seconds of the end deletes', () {
    expect(d(const Duration(minutes: 9, seconds: 49)), PositionAction.save);
    expect(d(const Duration(minutes: 9, seconds: 50)), PositionAction.delete);
    expect(d(total), PositionAction.delete);
  });

  test('unknown duration saves once past 10 seconds', () {
    expect(d(const Duration(minutes: 30), null), PositionAction.save);
    expect(d(const Duration(minutes: 30), Duration.zero), PositionAction.save);
  });

  test('short video shorter than the minimum is never saved', () {
    expect(
      d(const Duration(seconds: 5), const Duration(seconds: 8)),
      PositionAction.skip,
    );
  });
}
