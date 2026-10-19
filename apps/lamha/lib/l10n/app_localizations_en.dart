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
      'Location access was not allowed. Pick a city from the list.';

  @override
  String get locationFailed =>
      'Could not get your location. Pick a city from the list.';

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
}
