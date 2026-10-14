import 'package:flutter/widgets.dart';

import '../core/formatters.dart';
import '../l10n/app_localizations.dart';

/// نصوص مركّبة مشتركة بين بطاقة الكتاب وصفحته (كلها من ARB).
extension LibraryText on AppLocalizations {
  String _lang(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  String size(BuildContext context, int bytes) {
    final s = formatSize(bytes, _lang(context));
    return s.unit == SizeUnit.mb ? sizeMb(s.value) : sizeKb(s.value);
  }

  String sizeSpoken(BuildContext context, int bytes) {
    final s = formatSize(bytes, _lang(context));
    return s.unit == SizeUnit.mb
        ? sizeMbSpoken(s.value)
        : sizeKbSpoken(s.value);
  }

  String authorLine(BuildContext context, String author, int? deathYear) =>
      deathYear == null
      ? author
      : authorWithDeath(
          author,
          deathHijri(formatInt(deathYear, _lang(context))),
        );

  String? deathSpoken(BuildContext context, int? year) =>
      year == null ? null : deathHijriSpoken(formatInt(year, _lang(context)));

  String percent(BuildContext context, double fraction) =>
      downloadingPercent(formatInt(percentOf(fraction), _lang(context)));

  String licenseName(String license) =>
      license == 'public-domain' ? licensePublicDomain : license;

  String number(BuildContext context, int n) => formatInt(n, _lang(context));
}
