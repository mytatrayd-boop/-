import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa_app/quran.dart';
import 'package:tilawa_app/sync.dart';

void main() {
  final q = Quran.fromJson(File('assets/quran.json').readAsStringSync());

  test('المصحف كامل', () {
    expect(q.ayat.length, 114);
    expect(q.ayat.fold(0, (s, a) => s + a.length), 6236);
  });

  test('تحويل ترميز التنوين والصفر المستدير لخط المجمع', () {
    expect(forHafs('ٱدْخُلُوا۟', ''), 'ٱدْخُلُواْ'.replaceFirst('ْ', 'ۡ').replaceFirst('اْ', 'اْ'));
    expect(forHafs('سَآئِلٌۢ', 'بِعَذَابٍ'), contains('ۢ'));
    expect(textsForFont(['يَوْمٍۢ كَانَ']).first, isNot(contains('ۭ')));
  });

  test('تحديد الآيات والمقاطع من نص تعرّف فيه أخطاء وتكرار', () {
    // كتلة واحدة فيها وحدتان، ونص تعرّف بلا تشكيل
    final units = [
      [0.0, 6.0],
      [6.5, 10.0],
    ];
    final r = finishSync(q, units, packBlocks(units), [
      'سأل سائل بعذاب واقع للكافرين ليس له دافع',
    ])!;
    expect(r.surah, 70);
    expect(r.from, 1);
    expect(r.to, 2);
  });
}
