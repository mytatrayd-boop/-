import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/hijri/hijri_date.dart';
import 'package:lamha/src/hijri/umm_al_qura_calendar.dart';
import 'package:lamha/src/engine/schedule.dart';

import '../helpers.dart';

void main() {
  const path = 'assets/tables/hijri_umm_al_qura.json';
  final calendar = UmmAlQuraCalendar.fromJson(jsonDecode(readAsset(path)));

  test('١٩ أكتوبر ٢٠٢٦ = ٨ جمادى الأولى ١٤٤٨', () {
    expect(calendar.convert(DateTime(2026, 10, 19)), const HijriDate(1448, 5, 8));
    final j = hijriJson(calendar, DateTime(2026, 10, 19));
    expect(j['monthName'], 'جمادى الأولى');
    expect(j['text'], '٨ جمادى الأولى ١٤٤٨');
  });

  test('قيم اختبارات durur: بداية ١٤٤٨ ورمضان ١٤٤٧', () {
    expect(calendar.convert(DateTime(2026, 6, 15)), const HijriDate(1447, 12, 29));
    expect(calendar.convert(DateTime(2026, 6, 16)), const HijriDate(1448, 1, 1));
    expect(calendar.convert(DateTime(2026, 2, 18)), const HijriDate(1447, 9, 1));
  });

  test('الجدول مطابق لجدول durur حرفياً', () {
    final durur = File('../durur/$path');
    if (!durur.existsSync()) {
      markTestSkipped('مجلد durur غير موجود');
      return;
    }
    expect(readAsset(path), durur.readAsStringSync());
  });
}
