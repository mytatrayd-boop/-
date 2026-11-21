import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/deposits.dart';
import 'package:lamha/src/hijri/hijri_date.dart';
import 'package:lamha/src/hijri/umm_al_qura_calendar.dart';

import '../helpers.dart';

/// جدول وزارة المالية الرسمي «مواعيد صرف الرواتب لعام 2026» (mof.gov.sa)،
/// أرسله المالك صورةً. لكل شهر: [الشهر, اليوم الميلادي, السنة الهجرية, الشهر, اليوم].
const _official = [
  [1, 27, 1447, 8, 8],
  [2, 26, 1447, 9, 9],
  [3, 26, 1447, 10, 7],
  [4, 27, 1447, 11, 10],
  [5, 24, 1447, 12, 7],
  [6, 28, 1448, 1, 13],
  [7, 27, 1448, 2, 13],
  [8, 27, 1448, 3, 14],
  [9, 27, 1448, 4, 16],
  [10, 27, 1448, 5, 16],
  [11, 26, 1448, 6, 16],
  [12, 27, 1448, 7, 18],
];

void main() {
  final deposits = DepositsConfig.fromJson(
      jsonDecode(readAsset('assets/deposits.json')) as Map<String, dynamic>);
  final calendar = UmmAlQuraCalendar.fromJson(
      jsonDecode(readAsset('assets/tables/hijri_umm_al_qura.json')));

  for (final r in _official) {
    final date = DateTime(2026, r[0], r[1]);
    test('راتب ${r[0]}/2026 = ${r[1]} حسب وزارة المالية', () {
      expect(deposits.dateFor('salary', 2026, r[0]), date);
    });
    test('الهجري لـ ${r[1]}/${r[0]}/2026 يطابق جدول الوزارة', () {
      expect(calendar.convert(date), HijriDate(r[2], r[3], r[4]));
    });
  }
}
