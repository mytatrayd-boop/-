// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lamha';

  @override
  String get loadError => 'Could not load settings';

  @override
  String get retry => 'Retry';

  @override
  String get opacityLabel => 'Transparency';

  @override
  String percent(String value) {
    return '$value%';
  }

  @override
  String get backgroundButton => 'Wallpaper screenshot';

  @override
  String get backgroundSaved => 'Wallpaper screenshot saved';

  @override
  String get backgroundError =>
      'Could not save the wallpaper screenshot. Check photo access and try again.';

  @override
  String get cityLabel => 'City';

  @override
  String get myLocation => 'My location';

  @override
  String get locationDenied =>
      'Location access was not allowed or location is off. Search for your city or pick it from the list.';

  @override
  String get locationFailed =>
      'Could not get your location. Search for your city or pick it from the list.';

  @override
  String get prayerMethodLabel => 'Prayer calculation method';

  @override
  String prayerMethodName(String method) {
    String _temp0 = intl.Intl.selectLogic(method, {
      'ummAlQura': 'Umm al-Qura',
      'muslimWorldLeague': 'Muslim World League',
      'egyptian': 'Egyptian General Authority of Survey',
      'karachi': 'University of Islamic Sciences, Karachi',
      'dubai': 'Dubai',
      'kuwait': 'Kuwait',
      'qatar': 'Qatar',
      'gulfRegion': 'Gulf Region',
      'northAmerica': 'North America',
      'turkiye': 'Türkiye',
      'other': '$method',
    });
    return '$_temp0';
  }

  @override
  String elementName(String element) {
    String _temp0 = intl.Intl.selectLogic(element, {
      'clock': 'Clock and day',
      'dates': 'Hijri and Gregorian dates',
      'weather': 'City and weather',
      'prayer': 'Next prayer',
      'qibla': 'Qibla',
      'deposit': 'Deposits',
      'season': 'Season',
      'tradSeason': 'Traditional season',
      'dayWeather': 'Day and weather',
      'hijri': 'Hijri date',
      'gregorian': 'Gregorian date',
      'prayerTimes': 'Prayer times',
      'tradPoints': 'Season notes',
      'other': '$element',
    });
    return '$_temp0';
  }

  @override
  String get lastDepositMessage =>
      'At least one deposit is required. To hide the tile, use \"Customize widget\".';

  @override
  String get tilePrayer => 'Next prayer';

  @override
  String get tileQibla => 'Qibla';

  @override
  String get tileDeposit => 'Next deposit';

  @override
  String get tileDepositShort => 'Deposit';

  @override
  String get tileSeason => 'Season';

  @override
  String get tileTradSeason => 'Traditional season';

  @override
  String hijriDateText(String date) {
    return '$date AH';
  }

  @override
  String gregorianDateText(String date) {
    return '$date';
  }

  @override
  String cityWeather(String city, String weather) {
    return '📍 $city · $weather';
  }

  @override
  String remainingToNext(String remaining, String next) {
    return '$remaining $next';
  }

  @override
  String degrees(String value) {
    return '$value°';
  }

  @override
  String get dataLicense =>
      'City coordinates from GeoNames (geonames.org), CC BY 4.0. Tajawal font, SIL OFL 1.1.';

  @override
  String nearCity(String city) {
    return 'Near $city';
  }

  @override
  String get locationNearest =>
      'Could not get the place name, so the nearest city is shown. Times use your actual location.';

  @override
  String get searchHint => 'Search for a city or governorate';

  @override
  String get searchNoResults => 'No results. Try another name.';

  @override
  String get searchFailed =>
      'Search failed. Check your internet connection and try again.';

  @override
  String get quickPick => 'Quick pick';

  @override
  String get qiblaTitle => 'Qibla direction';

  @override
  String qiblaFromNorth(String degrees) {
    return '$degrees from north';
  }

  @override
  String get compassHint =>
      'Hold the phone flat, then turn until the arrow points up.';

  @override
  String get qiblaAligned => 'You\'re facing the Qibla';

  @override
  String get compassWaiting => 'Reading the compass…';

  @override
  String get compassCalibrate =>
      'Compass accuracy is low. Move the phone in a figure-8 to calibrate it, away from metal and magnets.';

  @override
  String get compassUnavailable =>
      'This device has no compass sensor, so the arrow can\'t be shown. Use the angle above with another compass.';

  @override
  String get weatherUnknown => '--°';

  @override
  String get themeLabel => 'Widget color';

  @override
  String themeName(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'black': 'Black',
      'gold': 'Gold',
      'green': 'Green',
      'blue': 'Blue',
      'purple': 'Purple',
      'pink': 'Pink',
      'gray': 'Gray',
      'system': 'System colors',
      'other': '$theme',
    });
    return '$_temp0';
  }

  @override
  String get lockNotificationLabel => 'Show on lock screen (notification)';

  @override
  String get lockNotificationHint =>
      'Most Android phones don\'t allow lock screen widgets, so a quiet notification shows the next prayer and qibla.';

  @override
  String get notificationPermissionTitle => 'Notification permission';

  @override
  String get notificationPermissionBody =>
      'To show the next prayer, countdown and qibla on the lock screen, Lamha needs notification permission. The notification is silent and can be turned off here at any time.';

  @override
  String get continueAction => 'Continue';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get notificationDenied =>
      'Notifications were not allowed, so nothing will show on the lock screen. You can allow them in phone settings.';

  @override
  String get fontScaleLabel => 'Text size';

  @override
  String fontScaleName(String scale) {
    String _temp0 = intl.Intl.selectLogic(scale, {
      'small': 'Small',
      'medium': 'Medium',
      'large': 'Large',
      'xlarge': 'Extra large',
      'other': '$scale',
    });
    return '$_temp0';
  }

  @override
  String countdownText(String time) {
    return '$time left';
  }

  @override
  String get depositsSection => 'Shown deposits';

  @override
  String get customizeTitle => 'Customize widget';

  @override
  String get resetLayout => 'Restore defaults';

  @override
  String get tileVisible => 'Show';

  @override
  String get tileSpanLabel => 'Width';

  @override
  String get tileFontLabel => 'Text size';

  @override
  String get primaryColorLabel => 'Main text color';

  @override
  String get secondaryColorLabel => 'Secondary text color';

  @override
  String get tileOverflow => 'Does not fit on the widget (more than 5 rows)';

  @override
  String get dragHandle => 'Long-press and drag to reorder';

  @override
  String get tileHint =>
      'Tap a tile in the preview or the strip to edit it. Long-press an item in the strip and drag it to reorder.';

  @override
  String tileSpanName(String span) {
    String _temp0 = intl.Intl.selectLogic(span, {
      'small': 'Small',
      'medium': 'Medium',
      'wide': 'Wide',
      'other': '$span',
    });
    return '$_temp0';
  }

  @override
  String tileColorName(String color) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'auto': 'Automatic',
      'white': 'White',
      'black': 'Black',
      'gold': 'Gold',
      'green': 'Green',
      'blue': 'Blue',
      'purple': 'Purple',
      'pink': 'Pink',
      'lightGray': 'Light gray',
      'other': '$color',
    });
    return '$_temp0';
  }

  @override
  String get tileShowTitle => 'Show title';

  @override
  String get tileShowSub => 'Show secondary line';

  @override
  String get digitsLabel => 'Digits';

  @override
  String digitsName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'arabic': 'Arabic (١٢٣)',
      'latin': 'English (123)',
      'other': '$style',
    });
    return '$_temp0';
  }

  @override
  String get depositsTitle => 'Remaining until:';

  @override
  String tradPointsTitle(String season) {
    return 'In $season:';
  }

  @override
  String pointText(String point) {
    return '- $point';
  }

  @override
  String nextAfter(String next, String after) {
    return '$next $after';
  }

  @override
  String cityIcon(String city, String icon) {
    return '📍 $city $icon';
  }
}
