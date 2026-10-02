import 'package:durur/src/domain/day_info.dart';
import 'package:flutter_test/flutter_test.dart';

bool isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

void _expectPeriod(ActivePeriod p, DateTime date) {
  expect(p.dayNumber, greaterThanOrEqualTo(1));
  expect(p.dayNumber, lessThanOrEqualTo(p.length));
  expect(p.start.add(Duration(days: p.dayNumber - 1)), date);
  expect(p.end.isBefore(date), isFalse);
}

void expectConsistent(DayInfo info) {
  _expectPeriod(info.dar, info.date);
  _expectPeriod(info.majorSeason, info.date);
  _expectPeriod(info.star, info.date);
  if (info.weatherSeason != null) _expectPeriod(info.weatherSeason!, info.date);
}

/// يوم تالٍ: إما الفترة نفسها واليوم +1، أو فترة جديدة يومها 1 بعد آخر يوم.
void _expectContinuousPeriod(ActivePeriod prev, ActivePeriod next) {
  if (next.dayNumber == 1) {
    expect(prev.dayNumber, prev.length, reason: 'فجوة أو تداخل');
    expect(prev.end.add(const Duration(days: 1)), next.start);
  } else {
    expect(next.start, prev.start);
    expect(next.dayNumber, prev.dayNumber + 1);
  }
}

void expectContinuous(DayInfo prev, DayInfo next) {
  expect(next.date.difference(prev.date).inDays, 1);
  _expectContinuousPeriod(prev.dar, next.dar);
  _expectContinuousPeriod(prev.majorSeason, next.majorSeason);
  _expectContinuousPeriod(prev.star, next.star);
}
