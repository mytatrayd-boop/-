import 'package:intl/intl.dart';

import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';

String scanTypeLabel(AppLocalizations l10n, ScanType t) =>
    t == ScanType.bean ? l10n.scanTypeBean : l10n.scanTypeCoffee;

String formatScanDate(String locale, DateTime d) => DateFormat.yMMMd(locale).add_jm().format(d);
