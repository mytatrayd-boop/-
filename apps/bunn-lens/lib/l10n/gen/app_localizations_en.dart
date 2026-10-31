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

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get undo => 'Undo';

  @override
  String get favoriteFailed => 'Couldn\'t update favorites';

  @override
  String get favoritesEmptyTitle =>
      'You haven\'t saved anything yet. Tap the star on any result';

  @override
  String get favoritesErrorTitle => 'Couldn\'t load favorites';

  @override
  String get favoritesLoading => 'Loading favorites';

  @override
  String get cafeSave => 'Save cafe location';

  @override
  String get cafeLocating => 'Finding your location…';

  @override
  String get cafeLocationFailedTitle => 'Couldn\'t get your location';

  @override
  String get cafeLocDenied =>
      'Location permission wasn\'t granted. You can save the cafe name only, without a maps link.';

  @override
  String get cafeLocDeniedForever =>
      'Location permission is denied. Enable it in phone settings, or save the name only without a maps link.';

  @override
  String get cafeLocServiceOff =>
      'Location services are off. Turn them on, or save the name only without a maps link.';

  @override
  String get cafeLocTimeout =>
      'Finding your location took too long. Try later, or save the name only without a maps link.';

  @override
  String get cafeLocError =>
      'Couldn\'t get your location. You can save the name only without a maps link.';

  @override
  String get cafeSaveNameOnly => 'Save name only';

  @override
  String get cafeNameTitle => 'Cafe name';

  @override
  String get cafeNameLabel => 'Cafe name';

  @override
  String get cafeNameRequired => 'Enter the cafe name';

  @override
  String get cafeSaveAction => 'Save';

  @override
  String get cafeSaved => 'Cafe saved';

  @override
  String get cafeSaveFailed => 'Couldn\'t save the cafe';

  @override
  String get cafeOpenInMaps => 'Open in Google Maps';

  @override
  String get cafeOpenFailed => 'Couldn\'t open maps';

  @override
  String get cafesTitle => 'My saved cafes';

  @override
  String get cafesEmptyTitle => 'No cafe saved yet';

  @override
  String get cafesEmptyBody =>
      'Open any scan\'s details and tap \"Save cafe location\" while you\'re at the cafe.';

  @override
  String get cafesErrorTitle => 'Couldn\'t load cafes';

  @override
  String get cafesLoading => 'Loading cafes';

  @override
  String cafeScanCount(int count) {
    return 'Scans: $count';
  }

  @override
  String cafeLastScore(int score) {
    return 'Last score: $score/100';
  }

  @override
  String get cafeNoLocation => 'No location';

  @override
  String get cafeMenu => 'Cafe options';

  @override
  String get cafeEdit => 'Edit name';

  @override
  String get cafeEditTitle => 'Edit cafe name';

  @override
  String get cafeDelete => 'Delete cafe';

  @override
  String get cafeDeleteTitle => 'Delete this cafe?';

  @override
  String get cafeDeleteBody =>
      'Your scans stay, but the cafe name is removed from them. This can\'t be undone.';

  @override
  String get cafeDeleted => 'Cafe deleted';

  @override
  String get cafeDeleteFailed => 'Couldn\'t delete the cafe';

  @override
  String get cafeRenameFailed => 'Couldn\'t rename the cafe';

  @override
  String get scanCafe => 'Cafe';

  @override
  String get settingsCafesSubtitle => 'Cafe places you saved';

  @override
  String get shareAction => 'Share';

  @override
  String get shareGenerating => 'Preparing the image…';

  @override
  String get shareFailed => 'Couldn\'t prepare the image, try again';

  @override
  String get shareImageMissing =>
      'The scan image is missing, so it can\'t be shared';

  @override
  String get shareNameDialogTitle => 'Write your name to sign';

  @override
  String get shareNameDialogBody =>
      'Your name appears in handwriting under the logo on the shared image.';

  @override
  String get shareNameLabel => 'Name';

  @override
  String get shareNameRequired => 'Write your name first';

  @override
  String get shareNameSave => 'Save';

  @override
  String get settingsUserNameTitle => 'Signature name';

  @override
  String get settingsUserNameEmpty => 'Write your name to sign shared images';

  @override
  String get shareScoreOutOf => 'out of 100';

  @override
  String get scoreLabelExcellent => 'Excellent';

  @override
  String get scoreLabelGood => 'Good';

  @override
  String get scoreLabelAverage => 'Average';

  @override
  String get scoreLabelWeak => 'Weak';

  @override
  String shareCardTypeLine(String type, String roaster) {
    return '$type · $roaster roastery';
  }

  @override
  String shareTextRated(String subject, int score) {
    return 'I rated $subject with Bunn Lens: $score/100 (estimate)';
  }

  @override
  String shareTextCafe(String cafe) {
    return 'Cafe: $cafe';
  }

  @override
  String shareSubjectRoaster(String name) {
    return 'the roaster $name';
  }

  @override
  String shareSubjectCafe(String name) {
    return 'the cafe $name';
  }

  @override
  String shareSubjectType(String type) {
    return 'a $type scan';
  }
}
