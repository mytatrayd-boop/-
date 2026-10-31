// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Bunn Lens';

  @override
  String get tabScan => 'Scan';

  @override
  String get tabHistory => 'History';

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get tabSettings => 'Settings';

  @override
  String get scanTitle => 'Scan';

  @override
  String get historyTitle => 'History';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get logoLabel => 'Bunn Lens logo';

  @override
  String get placeholderSoon => 'Coming soon';

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyFilterBean => 'Beans';

  @override
  String get historyFilterCoffee => 'Coffee';

  @override
  String get scanTypeBean => 'Beans';

  @override
  String get scanTypeCoffee => 'Coffee';

  @override
  String get historyEmptyTitle => 'No scans yet';

  @override
  String get historyEmptyAction => 'Scan now';

  @override
  String get historyErrorTitle => 'Couldn\'t load history';

  @override
  String get retry => 'Try again';

  @override
  String get historyLoading => 'Loading history';

  @override
  String scoreOutOf(int score) {
    return '$score/100';
  }

  @override
  String scanCardLabel(String type, int score) {
    return '$type scan, score $score out of 100';
  }

  @override
  String get scanMenu => 'Scan options';

  @override
  String get scanDelete => 'Delete';

  @override
  String get deleteScanTitle => 'Delete this scan?';

  @override
  String get deleteScanBody => 'This can\'t be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get scanDeleted => 'Scan deleted';

  @override
  String get scanDeleteFailed => 'Couldn\'t delete the scan';

  @override
  String get scanDetailTitle => 'Scan details';

  @override
  String get scanNotFound => 'This scan doesn\'t exist';

  @override
  String get scanNotesTitle => 'Notes';

  @override
  String get scanDisclaimer => 'A rough visual estimate, not a final verdict';

  @override
  String get scanRoaster => 'Roaster';

  @override
  String get scanPrice => 'Price';

  @override
  String get scanDate => 'Date';

  @override
  String get scanImageUnavailable => 'Image unavailable';

  @override
  String get scanTypeField => 'Type';
}
