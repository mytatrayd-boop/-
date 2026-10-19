import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/traditional_seasons.dart';

import '../helpers.dart';

void main() {
  final table = TradSeasonsTable.fromJsonString(readAsset('assets/seasons.json'));

  /// طول الموسم [id] بالأيام في الدورة التي تبدأ في [year].
  int length(String id, int year) {
    final s = table.seasons.firstWhere((s) => s.id == id);
    final c = table.on(DateTime(year, s.startMonth, s.startDay));
    expect(c.season.id, id);
    return c.end.difference(c.start).inDays + 1;
  }

  test('اثنا عشر موسماً من مصدر المالك بأوصاف', () {
    expect(table.seasons, hasLength(12));
    expect(table.approval, 'owner_provided');
    for (final s in table.seasons) {
      expect(s.description, isNotEmpty);
    }
  });

  test('عدد أيام كل موسم (دليل الطوالع والنجوم)', () {
    const expected = {
      'suhail': 53,
      'wasm': 52,
      'murabbaniya': 39,
      'shabat': 26,
      'humaimain': 26,
      'dhiraan': 26,
      'thurayya': 39,
      'tuwaibi': 13,
      'jawza': 26,
      'mirzam': 13,
      'kulaibain': 13,
    };
    // ٢٠٢٦ (غير كبيسة) و٢٠٢٧ (والمربعانية تمتد إلى ٢٠٢٨ الكبيسة بلا أثر).
    for (final year in [2026, 2027]) {
      expected.forEach((id, days) {
        expect(length(id, year), days, reason: '$id $year');
      });
    }
    final total = table.seasons.map((s) => length(s.id, 2026)).reduce((a, b) => a + b);
    expect(total, 365);
  });

  test('العقارب ٣٩ يوماً، و٤٠ في السنة الكبيسة', () {
    expect(length('aqarib', 2026), 39);
    expect(length('aqarib', 2027), 39);
    expect(length('aqarib', 2028), 40);
    expect(table.on(DateTime(2028, 2, 29)).season.name, 'العقارب');
  });

  test('١٩ أكتوبر ٢٠٢٦: الوسم، والمربعانية بعد ٤٩ يوماً', () {
    final c = table.on(DateTime(2026, 10, 19));
    expect(c.season.name, 'الوسم');
    expect(c.season.description,
        'يُترقّب فيه المطر واعتدال الأجواء ونمو النباتات الموسمية');
    expect(c.next.name, 'المربعانية');
    expect(c.start, DateTime(2026, 10, 16));
    expect(c.end, DateTime(2026, 12, 6));
    expect(c.daysRemaining, 49);
  });

  test('حدود البداية والنهاية', () {
    expect(table.on(DateTime(2026, 10, 15)).season.name, 'سهيل');
    expect(table.on(DateTime(2026, 10, 15)).daysRemaining, 1);
    expect(table.on(DateTime(2026, 10, 16)).season.name, 'الوسم');
    expect(table.on(DateTime(2026, 8, 23)).season.name, 'الكليبين');
    expect(table.on(DateTime(2026, 8, 23)).end, DateTime(2026, 8, 23));
    expect(table.on(DateTime(2026, 8, 24)).season.name, 'سهيل');
    expect(table.on(DateTime(2027, 3, 20)).season.name, 'العقارب');
    expect(table.on(DateTime(2027, 3, 21)).season.name, 'الحميمين');
    expect(table.on(DateTime(2027, 4, 16)).season.name, 'الذراعين');
    expect(table.on(DateTime(2027, 6, 20)).season.name, 'التويبع');
    expect(table.on(DateTime(2027, 7, 29)).season.name, 'المرزم');
  });

  test('الالتفاف عبر السنة: المربعانية من ٧ ديسمبر إلى ١٤ يناير', () {
    final c = table.on(DateTime(2027, 1, 10));
    expect(c.season.name, 'المربعانية');
    expect(c.start, DateTime(2026, 12, 7));
    expect(c.end, DateTime(2027, 1, 14));
    expect(c.next.name, 'الشبط');
    expect(c.daysRemaining, 5);
    expect(table.on(DateTime(2026, 12, 31)).season.name, 'المربعانية');
    expect(table.on(DateTime(2027, 1, 15)).season.name, 'الشبط');
  });

  test('آخر موسم في الترتيب يلتف لبداية السنة التالية', () {
    final c = table.on(DateTime(2026, 12, 7));
    expect(c.next.name, 'الشبط');
    expect(c.daysRemaining, 39);
  });
}
