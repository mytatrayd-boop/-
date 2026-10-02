import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/formatting/date_labels.dart';
import 'package:durur/src/formatting/digits.dart';
import 'package:durur/src/hijri/hijri_date.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  group('الأرقام العربية الهندية', () {
    test('تحوّل كل الأرقام وتبقي غيرها', () {
      expect(toArabicIndicDigits('0123456789'), '٠١٢٣٤٥٦٧٨٩');
      expect(toArabicIndicDigits('2 أكتوبر 2026'), '٢ أكتوبر ٢٠٢٦');
      expect(formatInteger(1448), '١٤٤٨');
    });
  });

  group('المعيار 1: الهجري باسم الشهر العربي', () {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    test('مثال SPEC: 10 ربيع الآخر 1448', () {
      expect(hijriDateLabel(l10n, const HijriDate(1448, 4, 10)),
          '١٠ ربيع الآخر ١٤٤٨هـ');
    });

    for (var m = 1; m <= 12; m++) {
      test('الشهر $m: ${months[m - 1]}', () {
        expect(hijriDateLabel(l10n, HijriDate(1447, m, 1)),
            '١ ${months[m - 1]} ١٤٤٧هـ');
      });
    }

    test('اليوم الميلادي 2026-10-02 يُعرض 21 ربيع الآخر 1448', () {
      expect(
        hijriDateLabel(l10n, HijriDate.fromGregorian(DateTime(2026, 10, 2))),
        '٢١ ربيع الآخر ١٤٤٨هـ',
      );
    });
  });

  group('المعيار 2: الميلادي باسم الشهر', () {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    test('مثال SPEC: 2 أكتوبر 2026', () {
      expect(gregorianDateLabel(l10n, DateTime(2026, 10, 2)), '٢ أكتوبر ٢٠٢٦م');
    });

    for (var m = 1; m <= 12; m++) {
      test('الشهر $m: ${months[m - 1]}', () {
        expect(gregorianDateLabel(l10n, DateTime(2027, m, 15)),
            '١٥ ${months[m - 1]} ٢٠٢٧م');
      });
    }

    test('يتجاهل الوقت', () {
      expect(gregorianDateLabel(l10n, DateTime(2026, 12, 31, 23, 59)),
          '٣١ ديسمبر ٢٠٢٦م');
    });
  });

  test('المعيار 5: لا أرقام لاتينية في النصين', () {
    final latin = RegExp('[0-9A-Za-z]');
    for (var d = DateTime.utc(2025, 1, 1);
        !d.isAfter(DateTime.utc(2035, 12, 31));
        d = d.add(const Duration(days: 17))) {
      expect(gregorianDateLabel(l10n, d), isNot(contains(latin)));
      expect(hijriDateLabel(l10n, HijriDate.fromGregorian(d)),
          isNot(contains(latin)));
    }
  });
}
