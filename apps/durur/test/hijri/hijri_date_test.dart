import 'package:durur/src/hijri/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // عيّنة أولية. معيار القبول (SPEC الميزة 2) يتطلب 20 تاريخاً
  // من تقويم أم القرى الرسمي للأعوام 2025–2035، تُضاف عند بناء الميزة.
  final cases = <DateTime, HijriDate>{
    DateTime(2025, 6, 26): const HijriDate(1447, 1, 1), // 1 محرم 1447
    DateTime(2026, 2, 18): const HijriDate(1447, 9, 1), // 1 رمضان 1447
  };

  cases.forEach((gregorian, expected) {
    test('أم القرى: $gregorian → $expected', () {
      expect(HijriDate.fromGregorian(gregorian), expected);
    });
  });

  test('يتجاهل الوقت داخل اليوم', () {
    expect(
      HijriDate.fromGregorian(DateTime(2026, 2, 18, 23, 59)),
      const HijriDate(1447, 9, 1),
    );
  });
}
