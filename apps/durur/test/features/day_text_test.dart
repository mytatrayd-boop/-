import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/main.dart' show fontLicenses;
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/features/home/day_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import '../helpers/app_harness.dart';

/// نصوص الرئيسية حسب DESIGN (تحديث المصمم): الفاصل «—»، والسطران،
/// وقيمة قارئ الشاشة وترتيبها.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final l10n = lookupAppLocalizations(const Locale('ar'));

  test('سطر التاريخين: «—» بعد مسافة لا تنكسر، وصيغة السطرين بلا فاصل', () {
    final lines = datesLines(
      l10n,
      DateTime(2026, 10, 2),
      tables.hijri,
      isToday: true,
    );
    expect(lines.single, 'الجمعة ٢ أكتوبر ٢٠٢٦م — ٢١ ربيع الآخر ١٤٤٨هـ');
    expect(lines.single, isNot(contains('·')));
    expect(lines.first, 'الجمعة ٢ أكتوبر ٢٠٢٦م');
    expect(lines.second, '٢١ ربيع الآخر ١٤٤٨هـ');
    final viewing = datesLines(
      l10n,
      DateTime(2026, 10, 3),
      tables.hijri,
      isToday: false,
    );
    expect(viewing.first, startsWith('تعرض: '));
  });

  test('منطقة بدرورها: جملة الموسم فقط إن اختلف عن مئة الدَّرّ (D25)', () {
    final engine = CalendarEngine.fromTables(tables, 'kuwait');
    var sawSame = false;
    var sawDiff = false;
    for (
      var d = DateTime(2026, 1, 1);
      d.year == 2026;
      d = d.add(const Duration(days: 1))
    ) {
      final info = engine.resolve(d);
      final value = dialSemanticsValue(l10n, info, tables);
      final differs = info.majorSeason.itemId != info.dar.record.seasonId;
      expect(value.contains('الموسم:'), differs, reason: '$d');
      if (differs) {
        sawDiff = true;
        expect(value.indexOf('دَرّ '), lessThan(value.indexOf('الموسم:')));
        expect(value.indexOf('الموسم:'), lessThan(value.indexOf('النجم:')));
      } else {
        sawSame = true;
      }
    }
    expect(sawSame, isTrue);
    // البيانات التجريبية لا تفصل المئة عن الموسم؛ الحالة المختلفة بجدول صغير.
    final fixture = fixtureTables(
      edit: (t, _, _) => (t['a']! as Map<String, Object?>)['majorSeasons'] = [
        layer('s1', '01-10'),
        layer('s2', '07-05'),
      ],
    );
    final info = CalendarEngine.fromTables(
      fixture,
      'a',
    ).resolve(DateTime(2026, 1, 7));
    // 7 يناير: الدَّرّ «أ» (مئة s1) والموسم الكبير ما زال s2 حتى 10 يناير.
    expect(info.dar.record.seasonId, 's1');
    expect(info.majorSeason.itemId, 's2');
    final value = dialSemanticsValue(l10n, info, fixture);
    expect(value, contains('الموسم: s2.'));
    expect(value.indexOf('دَرّ '), lessThan(value.indexOf('الموسم:')));
    expect(value.indexOf('الموسم:'), lessThan(value.indexOf('النجم:')));
    expect(sawDiff, isFalse);
  });

  test('النص الكامل = البادئة ثم القيمة، كقالب wheel.a11y', () {
    final info = CalendarEngine.fromTables(
      tables,
      'kuwait',
    ).resolve(DateTime(2026, 10, 2));
    final full = dialSemanticsLabel(l10n, info, tables, isToday: true);
    expect(
      full,
      startsWith('اليوم: الجمعة، ٢ أكتوبر ٢٠٢٦، ٢١ ربيع الآخر ١٤٤٨ هجري. '),
    );
    expect(
      l10n.wheelA11yDate(
        'اليوم',
        'الجمعة',
        '٢ أكتوبر ٢٠٢٦',
        '٢١ ربيع الآخر ١٤٤٨',
      ),
      'اليوم: الجمعة، ٢ أكتوبر ٢٠٢٦، ٢١ ربيع الآخر ١٤٤٨ هجري.',
    );
  });

  test('رخص الخطوط OFL مسجّلة', () async {
    final entries = await fontLicenses().toList();
    expect(
      entries.expand((e) => e.packages),
      containsAll(['Reem Kufi', 'IBM Plex Sans Arabic']),
    );
    for (final e in entries) {
      expect(
        e.paragraphs.map((p) => p.text).join(),
        contains('Open Font License'),
      );
    }
  });
}
