import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/widget_sync.dart';
import 'package:mawid/model/programs.dart';

void main() {
  test('حمولة الودجت: المختار فقط، وتواريخ فعلية قادمة مرتبة', () {
    final p = buildWidgetPayload(DateTime(2026, 10, 9, 15), programs, {'citizen', 'gov'}, 0xFF1C2B4B);
    final items = p['items'] as List;
    expect(items.length, 2);
    final citizen = items.firstWhere((i) => i['name'] == 'حساب المواطن');
    final dates = (citizen['dates'] as List).cast<String>();
    expect(dates.first, '2026-10-11'); // 10 سبت ← الأحد
    expect(dates.length, 14);
    expect(dates, [...dates]..sort());
    expect(p['color'], 0xFF1C2B4B);
    // موعد مرّ هذا الشهر لا يظهر في قائمة التواريخ
    final ss = buildWidgetPayload(DateTime(2026, 10, 9), programs, {'ss'}, 0)['items'][0]['dates'] as List;
    expect(ss.first, '2026-11-01'); // 1 نوفمبر 2026 الأحد
  });
}
