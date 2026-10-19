import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/traditional_seasons.dart';

import '../helpers.dart';

void main() {
  final table = TradSeasonsTable.fromJsonString(readAsset('assets/seasons.json'));

  test('ثمانية مواسم مسودة بأوصاف', () {
    expect(table.seasons, hasLength(8));
    expect(table.approval, 'draft');
    for (final s in table.seasons) {
      expect(s.description, isNotEmpty);
    }
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
    expect(table.on(DateTime(2026, 8, 23)).season.name, 'الجوزاء');
    expect(table.on(DateTime(2026, 8, 23)).end, DateTime(2026, 8, 23));
    expect(table.on(DateTime(2026, 8, 24)).season.name, 'سهيل');
    expect(table.on(DateTime(2027, 3, 20)).season.name, 'العقارب');
    expect(table.on(DateTime(2027, 3, 21)).season.name, 'الذراعان');
  });

  test('الالتفاف عبر السنة: المربعانية من ٧ ديسمبر إلى ١٥ يناير', () {
    final c = table.on(DateTime(2027, 1, 10));
    expect(c.season.name, 'المربعانية');
    expect(c.start, DateTime(2026, 12, 7));
    expect(c.end, DateTime(2027, 1, 15));
    expect(c.next.name, 'الشبط');
    expect(c.daysRemaining, 6);
    expect(table.on(DateTime(2026, 12, 31)).season.name, 'المربعانية');
    expect(table.on(DateTime(2027, 1, 16)).season.name, 'الشبط');
  });

  test('آخر موسم في الترتيب يلتف لبداية السنة التالية', () {
    final c = table.on(DateTime(2026, 12, 7));
    expect(c.next.name, 'الشبط');
    expect(c.daysRemaining, 40);
  });

  test('٢٩ فبراير في سنة كبيسة', () {
    expect(table.on(DateTime(2028, 2, 29)).season.name, 'العقارب');
  });
}
