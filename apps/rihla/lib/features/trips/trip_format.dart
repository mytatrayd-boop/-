import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../home/widgets/controls.dart';

String formatTripDuration(int seconds) =>
    TopBar.formatElapsed(Duration(seconds: seconds));

String formatTripDistance(AppLocalizations l, double meters) =>
    l.hudDistanceKm((meters / 1000).toStringAsFixed(2));

/// التاريخ والوقت المحلي بلغة الواجهة (ميلادي).
String formatTripDate(String locale, DateTime utc) =>
    DateFormat.yMMMd(locale).add_Hm().format(utc.toLocal());
