// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BGTube';

  @override
  String get emptyTitle => 'Paste a YouTube link to play it';

  @override
  String get linkHint => 'YouTube link';

  @override
  String get pasteAndPlay => 'Paste and play';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get speed => 'Playback speed';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepMinutes(String minutes) {
    return '$minutes minutes';
  }

  @override
  String get sleepCancel => 'Cancel timer';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get retry => 'Retry';

  @override
  String get resolving => 'Preparing…';

  @override
  String get clipboardEmpty => 'No YouTube link in the clipboard';

  @override
  String get errorInvalidLink =>
      'The link is not valid. Make sure it is a YouTube video link.';

  @override
  String get errorPlaylistNotSupported =>
      'Playlist links are not supported yet. Paste a single video link.';

  @override
  String get errorExtraction =>
      'Could not extract audio from this video. Try again.';

  @override
  String get errorNetwork =>
      'Could not connect to the internet. Check your network and retry.';

  @override
  String get errorRateLimited =>
      'YouTube is rate-limiting requests from your network. Wait a while and retry.';

  @override
  String get errorPlayback => 'Could not play the audio. Please retry.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'Applied immediately and remembered.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsPersonalUse =>
      'For personal use only; not for distribution.';
}
