import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../astronomy/seasons.dart';
import '../../domain/day_info.dart';
import '../../domain/tables.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../theme/app_theme.dart';

/// أوراق الحساب الفلكي (DESIGN R3.2 وR3.1-10): ورقة الفصل وورقة البرج.
/// حساب لا تراث: لا مصدر تراثي ولا زر بلاغ، بل «حساب فلكي» فقط.

abstract final class AstroSheetKeys {
  static const season = Key('astroSeasonSheet');
  static const zodiac = Key('zodiacSheet');
}

/// «الأربعاء ٢٣ سبتمبر ٢٠٢٦، ٣:٠٥ ص» بتوقيت الجهاز.
String astroDateTimeLabel(
  AppLocalizations l10n,
  DateTime utc,
  DigitStyle digits,
) {
  final t = utc.toLocal();
  final day = DateTime(t.year, t.month, t.day);
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final time = l10n.astroTime(
    formatInteger(hour12, digits),
    localizeDigits(t.minute.toString().padLeft(2, '0'), digits),
    t.hour < 12 ? 'am' : 'pm',
  );
  return l10n.astroDateTime(
    weekdayLabel(l10n, day),
    gregorianDateLabel(l10n, day, digits: digits),
    time,
  );
}

/// اسم حدث بداية الفصل.
String astroEventName(AppLocalizations l10n, SolarEvent e) =>
    l10n.astroEventName(
      e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}'),
    );

/// ورقة الفصل (R3.2): البداية والنهاية بالساعة، والمدة، وما مضى وما بقي
/// (للفصل الحالي فقط)، والمقابل التراثي بتواريخه من الجدول، والسطر الثابت.
Future<void> showAstroSeasonSheet(
  BuildContext context, {
  required AstroPeriod<AstroSeason> period,
  required DateTime selected,
  required DateTime today,
  required DayInfo? Function(DateTime day) resolve,
  required Tables tables,
  required DigitStyle digits,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final colors = DururColors.of(context);
      final season = period.value;
      final name = l10n.astroSeasonName(season.name);
      final endEvent = season.next.startEvent;
      final isCurrent = period.containsDay(today);
      final elapsed = DateTime.utc(today.year, today.month, today.day)
          .difference(
            DateTime.utc(
              period.start.day.year,
              period.start.day.month,
              period.start.day.day,
            ),
          )
          .inDays;
      final remaining = period.days - elapsed;
      // المقابل التراثي: الموسم الكبير الذي يحتوي منتصف الفصل.
      final mid = DateTime(
        period.start.day.year,
        period.start.day.month,
        period.start.day.day + period.days ~/ 2,
      );
      final heritage = resolve(mid)?.majorSeason;
      final heritageName = heritage == null
          ? null
          : tables.items[heritage.itemId]?.name.ar;
      String dm(DateTime d) =>
          l10n.dayMonthDate(formatInteger(d.day, digits), 'g${d.month}');
      Widget line(String text, {Color? color, double size = 15}) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color,
            fontSize: size,
          ),
        ),
      );
      return SingleChildScrollView(
        key: AstroSheetKeys.season,
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: DururFonts.display,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            line(
              '${l10n.astroSeasonStarts(astroDateTimeLabel(l10n, period.start.instant, digits))}'
              '${l10n.listSeparator}${astroEventName(l10n, season.startEvent)}',
            ),
            line(
              '${l10n.astroSeasonEnds(astroDateTimeLabel(l10n, period.end.instant, digits))}'
              '${l10n.listSeparator}${astroEventName(l10n, endEvent)}',
            ),
            line(
              l10n.astroSeasonLength(
                period.days,
                formatInteger(period.days, digits),
              ),
            ),
            if (isCurrent)
              line(
                l10n.astroSeasonElapsed(
                  l10n.astroDaysElapsed(elapsed, formatInteger(elapsed, digits)),
                  l10n.astroDaysRemaining(
                    remaining,
                    formatInteger(remaining, digits),
                  ),
                ),
              ),
            if (heritage != null && heritageName != null)
              line(
                l10n.astroSeasonHeritage(
                  heritageName,
                  l10n.astroPeriodRange(dm(heritage.start), dm(heritage.end)),
                ),
              ),
            line(l10n.astroSeasonNote, color: colors.inkSoft, size: 13),
            line(l10n.astroComputed, color: colors.inkSoft, size: 13),
          ],
        ),
      );
    },
  );
}

/// ورقة البرج (R3.1-10): «الشمس في برج الميزان»، والتاريخان هذه السنة،
/// والسطر الثابت. بلا أي معنى تنجيمي.
Future<void> showZodiacSheet(
  BuildContext context, {
  required AstroPeriod<ZodiacSign> period,
  required DigitStyle digits,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final colors = DururColors.of(context);
      String dm(DateTime d) =>
          l10n.dayMonthDate(formatInteger(d.day, digits), 'g${d.month}');
      return SingleChildScrollView(
        key: AstroSheetKeys.zodiac,
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.zodiacSunIn(l10n.zodiacName(period.value.name)),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: DururFonts.display,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.astroPeriodRange(dm(period.start.day), dm(period.lastDay)),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.zodiacNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkSoft,
              ),
            ),
          ],
        ),
      );
    },
  );
}
