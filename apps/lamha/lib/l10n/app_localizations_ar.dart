// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'لمحة';

  @override
  String get loadError => 'تعذّر تحميل الإعدادات';

  @override
  String get opacityLabel => 'الشفافية';

  @override
  String percent(String value) {
    return '$value٪';
  }

  @override
  String get backgroundButton => 'لقطة الخلفية';

  @override
  String get backgroundSaved => 'حُفظت لقطة الخلفية';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get myLocation => 'موقعي';

  @override
  String get locationDenied =>
      'لم يُسمح بالوصول إلى الموقع. اختر المدينة من القائمة.';

  @override
  String get locationFailed => 'تعذّر تحديد الموقع. اختر المدينة من القائمة.';

  @override
  String get prayerMethodLabel => 'طريقة حساب الصلاة';

  @override
  String prayerMethodName(String method) {
    String _temp0 = intl.Intl.selectLogic(method, {
      'ummAlQura': 'أم القرى',
      'muslimWorldLeague': 'رابطة العالم الإسلامي',
      'egyptian': 'الهيئة المصرية العامة للمساحة',
      'karachi': 'جامعة العلوم الإسلامية بكراتشي',
      'dubai': 'دبي',
      'kuwait': 'الكويت',
      'qatar': 'قطر',
      'gulfRegion': 'منطقة الخليج',
      'northAmerica': 'أمريكا الشمالية',
      'turkiye': 'تركيا',
      'other': '$method',
    });
    return '$_temp0';
  }

  @override
  String get visibleSection => 'ما يظهر على الودجت';

  @override
  String elementName(String element) {
    String _temp0 = intl.Intl.selectLogic(element, {
      'hijri': 'التاريخ الهجري',
      'gregorian': 'التاريخ الميلادي',
      'weather': 'الطقس',
      'prayer': 'الصلاة',
      'qibla': 'القبلة',
      'deposit': 'الإيداع',
      'season': 'الفصل',
      'tradSeason': 'الموسم',
      'other': '$element',
    });
    return '$_temp0';
  }

  @override
  String get lastDepositMessage =>
      'يلزم إيداع واحد على الأقل. لإخفاء المربع أطفئ «الإيداع».';

  @override
  String get tilePrayer => 'الصلاة القادمة';

  @override
  String get tileQibla => 'القبلة';

  @override
  String get tileDeposit => 'الإيداع القادم';

  @override
  String get tileSeason => 'الفصل';

  @override
  String get tileTradSeason => 'الموسم';

  @override
  String hijriDateText(String date) {
    return '$date هـ';
  }

  @override
  String gregorianDateText(String date) {
    return '$date م';
  }

  @override
  String cityWeather(String city) {
    return '📍 $city · ⛅ ‎--°';
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
      'إحداثيات المدن من GeoNames (geonames.org) برخصة CC BY 4.0. الخط Tajawal برخصة SIL OFL 1.1.';
}
