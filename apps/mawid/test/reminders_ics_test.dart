import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/ics.dart';
import 'package:mawid/core/reminders.dart';
import 'package:mawid/model/programs.dart';

void main() {
  final citizen = programs.firstWhere((p) => p.id == 'citizen');

  test('تنبيهات حساب المواطن: 11 أكتوبر 2026 (قبل 3 أيام وقبل يوم)', () {
    final r = planReminders(DateTime(2026, 10, 9, 8), [citizen], d3: true, d1: true, d0: false);
    expect(r.first.when, DateTime(2026, 10, 10, 9)); // 8 أكتوبر ماضٍ، فأولها «قبل يوم»
    expect(r.map((x) => x.when).contains(DateTime(2026, 10, 10, 9)), isTrue); // قبل يوم من 11
    expect(r.first.body, contains('غداً'));
    expect(r.every((x) => x.when.hour == 9), isTrue);
    expect(r.map((x) => x.id).toSet().length, r.length); // معرفات فريدة
  });

  test('لا تنبيهات ماضية، ولا يتجاوز الحد، والخيارات المطفأة لا تُجدول', () {
    final all = planReminders(DateTime(2026, 10, 9, 8), programs, d3: true, d1: true, d0: true);
    expect(all.length <= 60, isTrue);
    expect(all.every((x) => x.when.isAfter(DateTime(2026, 10, 9, 8))), isTrue);
    expect(planReminders(DateTime(2026, 10, 9), programs, d3: false, d1: false, d0: false), isEmpty);
    expect(all.map((x) => x.id).toSet().length, all.length);
  });

  test('ملف ICS صالح البنية', () {
    final s = buildIcs([IcsEvent('a1', 'حساب المواطن, الأحد; ٢', DateTime(2026, 10, 11))], stamp: DateTime.utc(2026, 10, 9, 1, 2, 3));
    expect(s, startsWith('BEGIN:VCALENDAR'));
    expect(s, contains('DTSTART;VALUE=DATE:20261011'));
    expect(s, contains('DTEND;VALUE=DATE:20261012'));
    expect(s, contains('SUMMARY:حساب المواطن\\, الأحد\\; ٢'));
    expect(s, contains('DTSTAMP:20261009T010203Z'));
    expect(s.trimRight(), endsWith('END:VCALENDAR'));
  });
}
