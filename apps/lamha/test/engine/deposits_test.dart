import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/deposits.dart';

import '../helpers.dart';

String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// المتوقع لـ ٢٠٢٦–٢٠٢٧ (الجمعة ← الخميس قبله، السبت ← الأحد بعده)،
/// محسوب مستقلاً بأداة أخرى (Python datetime). مايو ٢٠٢٦ استثناء رسمي (٢٤)
/// من جدول وزارة المالية لعام ٢٠٢٦.
const expected = {
  'salary': [
    '2026-01-27', '2026-02-26', '2026-03-26', '2026-04-27', '2026-05-24',
    '2026-06-28', '2026-07-27', '2026-08-27', '2026-09-27', '2026-10-27',
    '2026-11-26', '2026-12-27', '2027-01-27', '2027-02-28', '2027-03-28',
    '2027-04-27', '2027-05-27', '2027-06-27', '2027-07-27', '2027-08-26',
    '2027-09-27', '2027-10-27', '2027-11-28', '2027-12-27',
  ],
  'citizen_account': [
    '2026-01-11', '2026-02-10', '2026-03-10', '2026-04-09', '2026-05-10',
    '2026-06-10', '2026-07-09', '2026-08-10', '2026-09-10', '2026-10-11',
    '2026-11-10', '2026-12-10', '2027-01-10', '2027-02-10', '2027-03-10',
    '2027-04-11', '2027-05-10', '2027-06-10', '2027-07-11', '2027-08-10',
    '2027-09-09', '2027-10-10', '2027-11-10', '2027-12-09',
  ],
  'social_security': [
    '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01', '2026-04-30',
    '2026-06-01', '2026-07-01', '2026-08-02', '2026-09-01', '2026-10-01',
    '2026-11-01', '2026-12-01', '2026-12-31', '2027-02-01', '2027-03-01',
    '2027-04-01', '2027-05-02', '2027-06-01', '2027-07-01', '2027-08-01',
    '2027-09-01', '2027-09-30', '2027-11-01', '2027-12-01',
  ],
  'housing_support': [
    '2026-01-25', '2026-02-24', '2026-03-24', '2026-04-23', '2026-05-24',
    '2026-06-24', '2026-07-23', '2026-08-24', '2026-09-24', '2026-10-25',
    '2026-11-24', '2026-12-24', '2027-01-24', '2027-02-24', '2027-03-24',
    '2027-04-25', '2027-05-24', '2027-06-24', '2027-07-25', '2027-08-24',
    '2027-09-23', '2027-10-24', '2027-11-24', '2027-12-23',
  ],
  'comprehensive_rehab': [
    '2026-01-26', '2026-02-26', '2026-03-26', '2026-04-26', '2026-05-26',
    '2026-06-25', '2026-07-26', '2026-08-26', '2026-09-27', '2026-10-26',
    '2026-11-26', '2026-12-27', '2027-01-26', '2027-02-25', '2027-03-25',
    '2027-04-26', '2027-05-26', '2027-06-27', '2027-07-26', '2027-08-26',
    '2027-09-26', '2027-10-26', '2027-11-25', '2027-12-26',
  ],
};

void main() {
  final config = loadDeposits();

  test('الملف فيه الإيداعات الستة بأسمائها وأيامها', () {
    expect(config.ids, {
      'salary', 'citizen_account', 'social_security', 'housing_support',
      'comprehensive_rehab', 'retirement',
    });
    // الستة كلها مفعّلة افتراضياً (طلب المالك).
    expect(config.defaultIds, config.ids);
    expect(config.rule('comprehensive_rehab').name, 'التأهيل الشامل');
    expect(config.rule('comprehensive_rehab').day, 26);
    expect(config.rule('retirement').name, 'معاشات المتقاعدين');
    expect(config.rule('retirement').day, 1);
    expect(config.rule('retirement').weekendShift,
        config.rule('social_security').weekendShift);
    expect(config.rule('salary').name, 'الرواتب');
    expect(config.rule('salary').day, 27);
    expect(config.rule('citizen_account').name, 'حساب المواطن');
    expect(config.rule('citizen_account').day, 10);
    expect(config.rule('social_security').name, 'الضمان الاجتماعي');
    expect(config.rule('social_security').day, 1);
    expect(config.rule('housing_support').name, 'الدعم السكني');
    expect(config.rule('housing_support').day, 24);
  });

  group('جدول ٢٠٢٦–٢٠٢٧', () {
    expected.forEach((id, dates) {
      test(id, () {
        var i = 0;
        for (final y in [2026, 2027]) {
          for (var m = 1; m <= 12; m++) {
            expect(iso(config.dateFor(id, y, m)), dates[i++], reason: '$y-$m');
          }
        }
      });
    });

    test('٢٧ يونيو ٢٠٢٦ سبت ← ٢٨ يونيو الأحد', () {
      expect(DateTime(2026, 6, 27).weekday, DateTime.saturday);
      expect(config.dateFor('salary', 2026, 6), DateTime(2026, 6, 28));
    });

    test('٢٧ نوفمبر ٢٠٢٦ جمعة ← ٢٦ نوفمبر الخميس', () {
      expect(DateTime(2026, 11, 27).weekday, DateTime.friday);
      expect(config.dateFor('salary', 2026, 11), DateTime(2026, 11, 26));
    });

    test('موعد يوم عمل لا يتغير', () {
      expect(config.dateFor('salary', 2026, 10), DateTime(2026, 10, 27));
    });
  });

  group('nextDeposits', () {
    test('الراتب وحده: الاسم مع شهر الاستحقاق والمتبقي', () {
      final r = config.nextDeposits(DateTime(2026, 10, 19), {'salary'});
      expect(r, hasLength(1));
      expect(r.single.date, DateTime(2026, 10, 27));
      expect(r.single.daysRemaining, 8);
      expect(r.single.label, 'راتب أكتوبر');
      expect(r.single.name, 'الرواتب');
      expect(r.single.remainingText, 'باقي ٨ أيام');
    });

    test('يوم الإيداع نفسه: المتبقي صفر و«اليوم»', () {
      final r = config.nextDeposits(DateTime(2026, 10, 27, 23, 59), {'salary'});
      expect(r.single.daysRemaining, 0);
      expect(r.single.remainingText, 'اليوم');
    });

    test('بعد الإيداع ينتقل للشهر التالي (المُقدَّم للخميس)', () {
      final r = config.nextDeposits(DateTime(2026, 10, 28), {'salary'});
      expect(r.single.date, DateTime(2026, 11, 26));
      expect(r.single.label, 'راتب نوفمبر');
      expect(r.single.daysRemaining, 29);
      expect(r.single.remainingText, 'باقي ٢٩ يوماً');
    });

    test('غير الراتب: الاسم وحده', () {
      final r = config.nextDeposits(DateTime(2026, 10, 19), {'housing_support'});
      expect(r.single.label, 'الدعم السكني');
      expect(r.single.date, DateTime(2026, 10, 25));
    });

    test('إزاحة لشهر سابق: ضمان يناير ٢٠٢٧ يُصرف ٣١ ديسمبر ٢٠٢٦', () {
      final r = config.nextDeposits(DateTime(2026, 12, 31), {'social_security'});
      expect(r.single.date, DateTime(2026, 12, 31));
      expect(r.single.dueMonth, 1);
      expect(r.single.dueYear, 2027);
      expect(r.single.daysRemaining, 0);
      final after = config.nextDeposits(DateTime(2027, 1, 1), {'social_security'});
      expect(after.single.date, DateTime(2027, 2, 1));
    });

    test('أكثر من إيداع: الأقرب فالأقرب، بحد اثنين', () {
      final all = {'salary', 'citizen_account', 'social_security', 'housing_support'};
      final r = config.nextDeposits(DateTime(2026, 10, 19), all);
      expect(r.map((o) => o.id), ['housing_support', 'salary']);
      expect(r.map((o) => o.daysRemaining), [6, 8]);
      final r4 = config.nextDeposits(DateTime(2026, 10, 19), all, count: 4);
      expect(r4.map((o) => o.id),
          ['housing_support', 'salary', 'social_security', 'citizen_account']);
      expect(r4.map((o) => iso(o.date)),
          ['2026-10-25', '2026-10-27', '2026-11-01', '2026-11-10']);
    });

    test('اختيار اثنين', () {
      final r = config.nextDeposits(
          DateTime(2026, 10, 2), {'social_security', 'citizen_account'});
      expect(r.map((o) => o.id), ['citizen_account', 'social_security']);
      expect(r.first.date, DateTime(2026, 10, 11));
    });

    test('مجموعة فارغة أو معرّف مجهول مرفوض', () {
      expect(() => config.nextDeposits(DateTime(2026, 10, 19), {}),
          throwsArgumentError);
      expect(() => config.nextDeposits(DateTime(2026, 10, 19), {'x'}),
          throwsArgumentError);
    });
  });

  group('الاستثناءات', () {
    final json = jsonDecode(readAsset('assets/deposits.json'))
        as Map<String, dynamic>;
    json['exceptions'] = [
      {'id': 'salary', 'month': '2027-03', 'date': '2027-03-04'},
    ];
    final withEx = DepositsConfig.fromJson(json);

    test('الاستثناء يتجاوز الحساب لشهره فقط', () {
      expect(withEx.dateFor('salary', 2027, 3), DateTime(2027, 3, 4));
      expect(withEx.dateFor('salary', 2027, 4), DateTime(2027, 4, 27));
      expect(withEx.dateFor('housing_support', 2027, 3), DateTime(2027, 3, 24));
    });

    test('nextDeposits يعرض موعد الاستثناء باسم شهر الاستحقاق', () {
      final r = withEx.nextDeposits(DateTime(2027, 3, 1), {'salary'});
      expect(r.single.date, DateTime(2027, 3, 4));
      expect(r.single.label, 'راتب مارس');
      expect(r.single.daysRemaining, 3);
      final after = withEx.nextDeposits(DateTime(2027, 3, 5), {'salary'});
      expect(after.single.date, DateTime(2027, 4, 27));
    });

    test('استثناء لإيداع مجهول مرفوض', () {
      final bad = Map<String, dynamic>.of(json)
        ..['exceptions'] = [
          {'id': 'x', 'month': '2027-03', 'date': '2027-03-04'},
        ];
      expect(() => DepositsConfig.fromJson(bad), throwsFormatException);
    });
  });

  test('معاشات المتقاعدين: يوم ١ بقاعدة الضمان نفسها', () {
    String iso2(DateTime d) => d.toIso8601String().substring(0, 10);
    for (final (y, m) in [(2026, 2), (2026, 8), (2026, 11), (2027, 5)]) {
      expect(iso2(config.dateFor('retirement', y, m)),
          iso2(config.dateFor('social_security', y, m)));
    }
    // ١ أغسطس ٢٠٢٦ سبت ← الأحد ٢.
    expect(config.dateFor('retirement', 2026, 8), DateTime(2026, 8, 2));
    final r = config.nextDeposits(DateTime(2026, 10, 19), {'retirement'});
    expect(r.single.date, DateTime(2026, 11, 1));
  });
}
