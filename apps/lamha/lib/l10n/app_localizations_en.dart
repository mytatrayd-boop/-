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
  String get visibleSection => 'Shown on the widget';

  @override
  String elementName(String element) {
    String _temp0 = intl.Intl.selectLogic(element, {
      'hijri': 'Hijri date',
      'gregorian': 'Gregorian date',
      'weather': 'Weather',
      'prayer': 'Prayer',
      'qibla': 'Qibla',
      'deposit': 'Deposit',
      'season': 'Season',
      'tradSeason': 'Traditional season',
      'other': '$element',
    });
    return '$_temp0';
  }

  @override
  String get lastDepositMessage =>
      'At least one deposit is required. To hide the tile, turn off \"Deposit\".';

  @override
  String get tilePrayer => 'Next prayer';

  @override
  String get tileQibla => 'Qibla';

  @override
  String get tileDeposit => 'Next deposit';

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
  String cityWeather(String city) {
    return '📍 $city · ⛅ --°';
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
  String get compassWaiting => 'Reading the compass…';

  @override
  String get compassCalibrate =>
      'Compass accuracy is low. Move the phone in a figure-8 to calibrate it, away from metal and magnets.';

  @override
  String get compassUnavailable =>
      'This device has no compass sensor, so the arrow can\'t be shown. Use the angle above with another compass.';
}
