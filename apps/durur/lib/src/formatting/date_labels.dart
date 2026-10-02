import '../../l10n/app_localizations.dart';
import '../hijri/hijri_date.dart';
import 'digits.dart';

/// نص التاريخ الهجري (أم القرى) من ملف الترجمة، مثل: ٢١ ربيع الآخر ١٤٤٨هـ.
String hijriDateLabel(AppLocalizations l10n, HijriDate date) => l10n.hijriDate(
      formatInteger(date.day),
      'm${date.month}',
      formatInteger(date.year),
    );

/// نص التاريخ الميلادي من ملف الترجمة، مثل: ٢ أكتوبر ٢٠٢٦م.
/// يُؤخذ التاريخ فقط بلا الوقت.
String gregorianDateLabel(AppLocalizations l10n, DateTime date) =>
    l10n.gregorianDate(
      formatInteger(date.day),
      'g${date.month}',
      formatInteger(date.year),
    );
