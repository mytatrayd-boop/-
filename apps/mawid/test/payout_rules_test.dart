import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/payout_rules.dart';

void main() {
  test('جمعة ← الخميس، سبت ← الأحد، غير ذلك كما هو', () {
    // 10 أكتوبر 2026 سبت ← 11 الأحد
    expect(effectiveDate(2026, 10, 10), DateTime(2026, 10, 11));
    // 24 أكتوبر 2026 سبت ← 25
    expect(effectiveDate(2026, 10, 24), DateTime(2026, 10, 25));
    // 1 مايو 2026 جمعة ← 30 أبريل (الخميس)
    expect(effectiveDate(2026, 5, 1), DateTime(2026, 4, 30));
    // 27 أكتوبر 2026 الثلاثاء
    expect(effectiveDate(2026, 10, 27), DateTime(2026, 10, 27));
  });

  test('كل الأيام الاسمية في 6 سنوات لا تقع جمعة أو سبت', () {
    for (var y = 2024; y <= 2030; y++) {
      for (var m = 1; m <= 12; m++) {
        for (final d in [1, 5, 10, 24, 26, 27]) {
          final e = effectiveDate(y, m, d);
          expect(e.weekday, isNot(DateTime.friday));
          expect(e.weekday, isNot(DateTime.saturday));
          expect((e.difference(DateTime(y, m, d)).inDays).abs() <= 1, isTrue);
        }
      }
    }
  });

  test('nextPayout يعبر الشهر والسنة', () {
    expect(nextPayout(DateTime(2026, 10, 9), 10), DateTime(2026, 10, 11));
    expect(nextPayout(DateTime(2026, 10, 12), 10), DateTime(2026, 11, 10));
    expect(nextPayout(DateTime(2026, 12, 28), 1), DateTime(2026, 12, 31)); // 1 يناير 2027 جمعة
  });

  test('المناسبات السنوية', () {
    expect(nextAnnual(DateTime(2026, 10, 9), 2, 22), DateTime(2027, 2, 22));
    expect(nextAnnual(DateTime(2026, 9, 23), 9, 23), DateTime(2026, 9, 23));
    expect(daysUntil(DateTime(2026, 10, 9), DateTime(2026, 10, 11)), 2);
  });
}
