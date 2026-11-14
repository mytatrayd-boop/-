// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Rihla';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeEmpty =>
      'Your trip will start here. The home screen is under construction.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsEmpty => 'Settings are under construction.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get backToHome => 'Back to home';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody =>
      'We could not find this page. Go back to the home screen and try again.';
}
