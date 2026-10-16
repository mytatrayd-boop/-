// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LabLocalizationsAr extends LabLocalizations {
  LabLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get labTitle => 'تجربة الصوت المدمج (T0)';

  @override
  String get labPreparing => 'تجهيز النموذج…';

  @override
  String get labLoading => 'تحميل النموذج في الذاكرة…';

  @override
  String get labMissingModel =>
      'النموذج غير مضمَّن في هذه النسخة. ابنِها من سير «Adeeb — voice lab APK».';

  @override
  String labError(String message) {
    return 'خطأ: $message';
  }

  @override
  String get labPlayAll => 'استمع للفقرات كلها';

  @override
  String get labStop => 'إيقاف';

  @override
  String get labRtf => 'عامل الزمن الحقيقي (RTF)';

  @override
  String labRtfValue(String last, String all) {
    return 'آخر فقرة $last — الكل $all (الهدف ≤ 0.5)';
  }

  @override
  String get labFirstAudio => 'زمن أول صوت';

  @override
  String labFirstAudioValue(String last, String worst) {
    return 'آخر فقرة $last ث — الأسوأ $worst ث (الهدف ≤ 1.5)';
  }

  @override
  String get labPeakMemory => 'ذروة الذاكرة';

  @override
  String labPeakMemoryValue(String peak, String base) {
    return '$peak م.ب (قبل النموذج $base م.ب، الهدف ≤ 300)';
  }

  @override
  String get labModelLoad => 'تحميل النموذج';

  @override
  String labModelLoadValue(String seconds, int threads) {
    return '$seconds ث — $threads خيوط';
  }

  @override
  String get labNotMeasured => '—';

  @override
  String get labProse => 'نثر';

  @override
  String get labVerse => 'شعر';

  @override
  String labParagraphNumber(String book, int number, String kind) {
    return '$book — فقرة $number ($kind)';
  }
}
