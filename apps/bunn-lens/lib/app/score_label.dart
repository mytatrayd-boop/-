import '../domain/score_tier.dart';
import '../l10n/gen/app_localizations.dart';

String tierLabel(AppLocalizations l10n, ScoreTier t) => switch (t) {
      ScoreTier.excellent => l10n.scoreLabelExcellent,
      ScoreTier.good => l10n.scoreLabelGood,
      ScoreTier.average => l10n.scoreLabelAverage,
      ScoreTier.weak => l10n.scoreLabelWeak,
    };

/// تسمية فئة الدرجة (ممتاز/جيد/متوسط/ضعيف).
String scoreLabelFor(AppLocalizations l10n, int score) => tierLabel(l10n, tierOf(score));
