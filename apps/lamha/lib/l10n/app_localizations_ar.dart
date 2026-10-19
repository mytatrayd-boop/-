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
  String get retry => 'إعادة المحاولة';

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
  String get backgroundError =>
      'تعذّر حفظ لقطة الخلفية. تأكد من إذن الصور وحاول مرة أخرى.';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get myLocation => 'موقعي';

  @override
  String get locationDenied =>
      'لم يُسمح بالوصول إلى الموقع، أو خدمة الموقع مغلقة. ابحث عن مدينتك أو اخترها من القائمة.';

  @override
  String get locationFailed =>
      'تعذّر تحديد الموقع. ابحث عن مدينتك أو اخترها من القائمة.';

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
      'إحداثيات المدن من GeoNames (geonames.org) برخصة CC BY 4.0. الخط Tajawal برخصة SIL OFL 1.1.';

  @override
  String nearCity(String city) {
    return 'قرب $city';
  }

  @override
  String get locationNearest =>
      'تعذّر جلب اسم المكان، فظهر اسم أقرب مدينة. الحساب بموقعك الفعلي.';

  @override
  String get searchHint => 'ابحث عن مدينة أو محافظة';

  @override
  String get searchNoResults => 'لا توجد نتائج. جرّب اسماً آخر.';

  @override
  String get searchFailed =>
      'تعذّر البحث. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.';

  @override
  String get quickPick => 'اختيار سريع';

  @override
  String get qiblaTitle => 'اتجاه القبلة';

  @override
  String qiblaFromNorth(String degrees) {
    return '$degrees من الشمال';
  }

  @override
  String get compassHint =>
      'ضع الجوال مستوياً، ثم استدر حتى يشير السهم إلى الأعلى.';

  @override
  String get compassWaiting => 'جارٍ قراءة البوصلة…';

  @override
  String get compassCalibrate =>
      'دقة البوصلة منخفضة. حرّك الجوال في الهواء على شكل الرقم ٨ لمعايرتها، وابتعد عن المعادن والمغناطيس.';

  @override
  String get compassUnavailable =>
      'لا يتوفر حساس بوصلة في هذا الجهاز، فلا يمكن عرض السهم. استعن بالزاوية أعلاه وبوصلة أخرى.';

  @override
  String get weatherUnknown => '‎--°';

  @override
  String get themeLabel => 'لون الودجت';

  @override
  String themeName(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'gold': 'ذهبي',
      'green': 'أخضر',
      'blue': 'أزرق',
      'purple': 'بنفسجي',
      'pink': 'وردي',
      'gray': 'رمادي',
      'system': 'ألوان النظام',
      'other': '$theme',
    });
    return '$_temp0';
  }

  @override
  String get lockNotificationLabel => 'إظهار في شاشة القفل (إشعار)';

  @override
  String get lockNotificationHint =>
      'أغلب جوالات أندرويد لا تسمح بودجت على شاشة القفل، فيظهر إشعار هادئ بالصلاة القادمة والقبلة.';

  @override
  String get notificationPermissionTitle => 'إذن الإشعارات';

  @override
  String get notificationPermissionBody =>
      'لعرض الصلاة القادمة والعد التنازلي والقبلة في شاشة القفل، تحتاج لمحة إذن الإشعارات. الإشعار ثابت وهادئ: بلا صوت ولا اهتزاز، ويمكنك إطفاؤه من هنا في أي وقت.';

  @override
  String get continueAction => 'متابعة';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get notificationDenied =>
      'لم يُسمح بالإشعارات، فلن يظهر شيء في شاشة القفل. يمكنك السماح بها من إعدادات الجوال.';
}
