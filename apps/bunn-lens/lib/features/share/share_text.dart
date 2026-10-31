import '../../domain/scan.dart';
import '../../l10n/gen/app_localizations.dart';

String scoreLabelFor(AppLocalizations l10n, int score) {
  if (score >= 85) return l10n.scoreLabelExcellent;
  if (score >= 70) return l10n.scoreLabelGood;
  if (score >= 50) return l10n.scoreLabelAverage;
  return l10n.scoreLabelWeak;
}

/// النص المرافق: «قيّمت [المحمصة/المقهى] بعدسة البن: 82/100 (تقديري)» + اسم المقهى + رابط الخرائط إن وُجد.
String buildShareText(AppLocalizations l10n, Scan scan) {
  final roaster = scan.roasterName?.trim();
  final cafe = scan.cafe;
  final String subject;
  if (roaster != null && roaster.isNotEmpty) {
    subject = l10n.shareSubjectRoaster(roaster);
  } else if (cafe != null) {
    subject = l10n.shareSubjectCafe(cafe.name);
  } else {
    subject = l10n.shareSubjectType(scan.type == ScanType.bean ? l10n.scanTypeBean : l10n.scanTypeCoffee);
  }
  final lines = <String>[l10n.shareTextRated(subject, scan.score)];
  if (cafe != null && !subject.contains(cafe.name)) lines.add(l10n.shareTextCafe(cafe.name));
  final maps = cafe?.mapsUri;
  if (maps != null) lines.add(maps.toString());
  return lines.join('\n');
}
