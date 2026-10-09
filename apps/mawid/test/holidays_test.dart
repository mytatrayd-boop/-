import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/model/holidays.dart';

void main() {
  test('اليوم الوطني ويوم التأسيس ثابتان', () {
    final hs = holidaysFor(2026);
    expect(holidayOn(hs, DateTime(2026, 9, 23))?.kind, HKind.national);
    expect(holidayOn(hs, DateTime(2026, 2, 22))?.kind, HKind.founding);
    expect(holidayOn(hs, DateTime(2026, 9, 24)), isNull);
  });

  test('العيدان يقعان في السنة الصحيحة (تقريبي)', () {
    final hs = holidaysFor(2026);
    final fitr = hs.where((h) => h.kind == HKind.eidFitr).toList();
    final adha = hs.where((h) => h.kind == HKind.eidAdha).toList();
    expect(fitr.length, 1);
    expect(adha.length, 1);
    expect(fitr.first.start.month, anyOf(3, 4)); // مارس 2026
    expect(adha.first.start.month, anyOf(5, 6)); // مايو 2026
    expect(fitr.first.approx, isTrue);
  });

  test('نهاية أسبوع مطولة: إجازة تنتهي الخميس أو تبدأ الأحد', () {
    // 23 سبتمبر 2026 الأربعاء: لا تمديد. 22 فبراير 2026 الأحد ← الجمعة والسبت قبلها.
    final f = holidaysFor(2026).where((h) => h.kind == HKind.longWeekend).toList();
    expect(f.any((h) => h.start == DateTime(2026, 2, 20) && h.end == DateTime(2026, 2, 21)), isTrue);
    // 23 سبتمبر 2027 الخميس ← الجمعة والسبت بعدها.
    final g = holidaysFor(2027).where((h) => h.kind == HKind.longWeekend).toList();
    expect(g.any((h) => h.start == DateTime(2027, 9, 24)), isTrue);
  });

  test('ملف التعليم الإضافي يُقرأ ويرفض الأنواع المجهولة', () {
    final e = parseExtra('[{"kind":"midTerm","start":"2026-11-01","end":"2026-11-05"},{"kind":"x","start":"2026-01-01","end":"2026-01-02"}]');
    expect(e.length, 1);
    final hs = holidaysFor(2026, extra: e);
    expect(holidayOn(hs, DateTime(2026, 11, 3))?.kind, HKind.midTerm);
  });
}
