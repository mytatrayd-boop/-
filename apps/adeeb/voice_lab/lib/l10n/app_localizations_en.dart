// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LabLocalizationsEn extends LabLocalizations {
  LabLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get labTitle => 'Built-in voice test (T0)';

  @override
  String get labPreparing => 'Preparing the model…';

  @override
  String get labLoading => 'Loading the model into memory…';

  @override
  String get labMissingModel =>
      'The model isn\'t bundled in this build. Build it with the \"Adeeb — voice lab APK\" workflow.';

  @override
  String labError(String message) {
    return 'Error: $message';
  }

  @override
  String get labPlayAll => 'Listen to all paragraphs';

  @override
  String get labStop => 'Stop';

  @override
  String get labRtf => 'Real-time factor (RTF)';

  @override
  String labRtfValue(String last, String all) {
    return 'Last paragraph $last — overall $all (target ≤ 0.5)';
  }

  @override
  String get labFirstAudio => 'Time to first audio';

  @override
  String labFirstAudioValue(String last, String worst) {
    return 'Last paragraph $last s — worst $worst s (target ≤ 1.5)';
  }

  @override
  String get labPeakMemory => 'Peak memory';

  @override
  String labPeakMemoryValue(String peak, String base) {
    return '$peak MB (before model $base MB, target ≤ 300)';
  }

  @override
  String get labModelLoad => 'Model load';

  @override
  String labModelLoadValue(String seconds, int threads) {
    return '$seconds s — $threads threads';
  }

  @override
  String get labNotMeasured => '—';

  @override
  String get labProse => 'Prose';

  @override
  String get labVerse => 'Verse';

  @override
  String labParagraphNumber(String book, int number, String kind) {
    return '$book — paragraph $number ($kind)';
  }
}
