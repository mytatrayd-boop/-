import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/cafe.dart';
import '../../domain/scan.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../app/score_label.dart';

/// كل ما تحتاجه البطاقة جاهزاً (نصوص مترجمة وصور مفكوكة) فلا تعتمد على Localizations أو ملفات.
class ShareCardData {
  const ShareCardData({
    required this.photo,
    required this.logo,
    required this.score,
    required this.scoreLabel,
    required this.scoreColor,
    required this.typeLine,
    required this.notes,
    required this.disclaimer,
    required this.appName,
    required this.userName,
    required this.textDirection,
    this.cafeName,
    this.mapsDisplay,
  });

  final ui.Image photo;
  final ui.Image logo;
  final int score;
  final String scoreLabel;
  final Color scoreColor;
  final String typeLine;
  final List<String> notes;
  final String disclaimer;
  final String appName;
  final String userName;
  final TextDirection textDirection;
  final String? cafeName;

  /// رابط الخرائط مختصراً للعرض (بلا https)؛ null إن لم يوجد موقع.
  final String? mapsDisplay;

  bool get hasLocation => cafeName != null && mapsDisplay != null;
  bool get hasCafe => cafeName != null;

  factory ShareCardData.fromScan({
    required AppLocalizations l10n,
    required Scan scan,
    required String userName,
    required ui.Image photo,
    required ui.Image logo,
    required TextDirection textDirection,
  }) {
    final type = scan.type == ScanType.bean ? l10n.scanTypeBean : l10n.scanTypeCoffee;
    final roaster = scan.roasterName?.trim();
    final colors = AppColors.light;
    final s = scan.score;
    return ShareCardData(
      photo: photo,
      logo: logo,
      score: s,
      scoreLabel: scoreLabelFor(l10n, s),
      scoreColor: s >= 70 ? colors.success : (s >= 50 ? colors.warning : colors.error),
      typeLine: roaster == null || roaster.isEmpty ? type : l10n.shareCardTypeLine(type, roaster),
      notes: scan.notes,
      disclaimer: l10n.scanDisclaimer,
      appName: l10n.appName,
      userName: userName,
      textDirection: textDirection,
      cafeName: scan.cafe?.name,
      mapsDisplay: _mapsDisplay(scan.cafe),
    );
  }
}

/// رابط الخرائط مختصراً للعرض على البطاقة (الرابط الكامل في نص المشاركة).
String? _mapsDisplay(Cafe? cafe) =>
    cafe != null && cafe.hasLocation ? 'google.com/maps?q=${cafe.lat},${cafe.lng}' : null;
