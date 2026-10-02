// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ديرة الدرور';

  @override
  String get todayLabel => 'اليوم';

  @override
  String get traditionDisclaimer =>
      'الجو المعتاد حسب التراث، وليس توقعاً للطقس';

  @override
  String hijriDate(String day, String month, String year) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'm1': 'محرم',
      'm2': 'صفر',
      'm3': 'ربيع الأول',
      'm4': 'ربيع الآخر',
      'm5': 'جمادى الأولى',
      'm6': 'جمادى الآخرة',
      'm7': 'رجب',
      'm8': 'شعبان',
      'm9': 'رمضان',
      'm10': 'شوال',
      'm11': 'ذو القعدة',
      'm12': 'ذو الحجة',
      'other': '',
    });
    return '$day $_temp0 $yearهـ';
  }

  @override
  String gregorianDate(String day, String month, String year) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'g1': 'يناير',
      'g2': 'فبراير',
      'g3': 'مارس',
      'g4': 'أبريل',
      'g5': 'مايو',
      'g6': 'يونيو',
      'g7': 'يوليو',
      'g8': 'أغسطس',
      'g9': 'سبتمبر',
      'g10': 'أكتوبر',
      'g11': 'نوفمبر',
      'g12': 'ديسمبر',
      'other': '',
    });
    return '$day $_temp0 $yearم';
  }

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get cityPickerTitle => 'اختر مدينتك';

  @override
  String get citySearchHint => 'ابحث باسم المدينة';

  @override
  String get cityFilterAll => 'الكل';

  @override
  String countryName(String country) {
    String _temp0 = intl.Intl.selectLogic(country, {
      'SA': 'السعودية',
      'KW': 'الكويت',
      'AE': 'الإمارات',
      'OM': 'عُمان',
      'QA': 'قطر',
      'BH': 'البحرين',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String cityRegionLabel(String region) {
    return 'جدول: $region';
  }

  @override
  String citySelected(String city, String region) {
    return 'تم اختيار $city — جدول $region';
  }

  @override
  String get cityEmptyTitle => 'لا توجد مدينة بهذا الاسم.';

  @override
  String get cityEmptyBody => 'جرّب اسماً آخر أو اختر أقرب مدينة لك.';

  @override
  String get cityEmptyClear => 'مسح البحث';

  @override
  String get citySaveError => 'تعذّر حفظ اختيارك. حاول مرة أخرى.';

  @override
  String cityChipLabel(String city, String region) {
    return '$city · $region';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSectionRegion => 'المنطقة';

  @override
  String get settingsCity => 'المدينة';

  @override
  String settingsCityValue(String city, String region) {
    return '$city — جدول $region';
  }

  @override
  String get dataLoadErrorTitle => 'تعذّر فتح بيانات الدرور';

  @override
  String get dataLoadErrorBody =>
      'أعد تشغيل التطبيق. إذا تكرر ذلك، حدّث التطبيق من المتجر.';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get onboardingWelcomeTitle => 'أهلاً بك في ديرة الدرور';

  @override
  String get onboardingWelcomeBody =>
      'تعرف الدَّرّ والموسم والنجم اليوم في منطقتك، وما الجو المعتاد فيه. يعمل بلا إنترنت.';

  @override
  String get onboardingWelcomeStart => 'ابدأ';

  @override
  String get onboardingLocationTitle => 'في أي منطقة أنت؟';

  @override
  String get onboardingLocationBody =>
      'نستخدم موقعك التقريبي مرة واحدة لنعرف جدول درور منطقتك. لا نتتبعك ولا نرسل موقعك لأي جهة.';

  @override
  String get onboardingLocationAllow => 'حدّد موقعي';

  @override
  String get onboardingLocationManual => 'اختر مدينتك يدوياً';

  @override
  String get onboardingLocationManualShort => 'اختر يدوياً';

  @override
  String get onboardingLocationLoading => 'نحدد مدينتك…';

  @override
  String onboardingLocationFound(String city) {
    return 'وجدنا أقرب مدينة لك: $city';
  }

  @override
  String onboardingLocationRegion(String region) {
    return 'جدول المنطقة: $region';
  }

  @override
  String get onboardingLocationNotMyCity => 'ليست مدينتي';

  @override
  String get locationDenied => 'لا بأس، اختر مدينتك من القائمة.';

  @override
  String get locationUnavailable =>
      'خدمة الموقع غير متاحة. اختر مدينتك من القائمة.';

  @override
  String get locationTimeout => 'تأخر تحديد الموقع. اختر مدينتك من القائمة.';

  @override
  String get locationOutOfRange =>
      'منطقتك خارج نطاق الجداول المتاحة. اختر أقرب مدينة خليجية إليك.';

  @override
  String get locationFailedSettings =>
      'لم نتمكن من الوصول لموقعك. يمكنك اختيار مدينتك يدوياً.';

  @override
  String locationUpdated(String city, String region) {
    return 'تم تحديث مدينتك إلى $city — جدول $region';
  }

  @override
  String locationUnchanged(String city) {
    return 'مدينتك كما هي: $city';
  }

  @override
  String get locationChooseCity => 'اختيار المدينة';

  @override
  String get settingsRelocate => 'تحديد موقعي مرة أخرى';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonClose => 'إغلاق';

  @override
  String commonSource(String source) {
    return 'المصدر: $source';
  }

  @override
  String get draftDataBanner => 'بيانات تجريبية — غير معتمدة';

  @override
  String get listSeparator => '، ';

  @override
  String weekdayName(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'w1': 'الاثنين',
      'w2': 'الثلاثاء',
      'w3': 'الأربعاء',
      'w4': 'الخميس',
      'w5': 'الجمعة',
      'w6': 'السبت',
      'w7': 'الأحد',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gregorianMonthName(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'g1': 'يناير',
      'g2': 'فبراير',
      'g3': 'مارس',
      'g4': 'أبريل',
      'g5': 'مايو',
      'g6': 'يونيو',
      'g7': 'يوليو',
      'g8': 'أغسطس',
      'g9': 'سبتمبر',
      'g10': 'أكتوبر',
      'g11': 'نوفمبر',
      'g12': 'ديسمبر',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String homeDatesLine(String weekday, String gregorian, String hijri) {
    return '$weekday $gregorian — $hijri';
  }

  @override
  String homeViewingDate(String date) {
    return 'تعرض: $date';
  }

  @override
  String get homePrevDay => 'اليوم السابق';

  @override
  String get homeNextDay => 'اليوم التالي';

  @override
  String get homePickDate => 'اختر تاريخاً';

  @override
  String homeDayOfDar(String day, String total) {
    return 'اليوم $day من $total';
  }

  @override
  String get homeStar => 'النجم';

  @override
  String get homeWeatherSeason => 'موسم الجو';

  @override
  String get homeNoWeatherSeason => 'لا يوجد موسم جو مسمّى في هذه الأيام';

  @override
  String get homeUsualWeather => 'الجو المعتاد';

  @override
  String homeDarDetails(String dar) {
    return 'تفاصيل دَرّ $dar';
  }

  @override
  String get homeCalcError => 'تعذّر حساب هذا اليوم.';

  @override
  String homeDururBorrowed(String region) {
    return 'الدَّرّ حسب حساب $region';
  }

  @override
  String dialDururLegend(String region) {
    return 'حلقة الدرور: حساب $region';
  }

  @override
  String get wheelResetZoom => 'إعادة الحجم';

  @override
  String get wheelA11yPrefixToday => 'اليوم';

  @override
  String get wheelA11yPrefixViewing => 'التاريخ المعروض';

  @override
  String wheelA11yDate(
    String prefix,
    String weekday,
    String gregorian,
    String hijri,
  ) {
    return '$prefix: $weekday، $gregorian، $hijri هجري.';
  }

  @override
  String wheelA11yDar(String dar, String season, String day, String total) {
    return 'دَرّ $dar من $season، اليوم $day من $total.';
  }

  @override
  String wheelA11yDarBorrowed(
    String dar,
    String season,
    String region,
    String day,
    String total,
  ) {
    return 'دَرّ $dar من $season حسب حساب $region، اليوم $day من $total.';
  }

  @override
  String wheelA11yMajorSeason(String season) {
    return 'الموسم: $season.';
  }

  @override
  String wheelA11yStar(String star) {
    return 'النجم: $star.';
  }

  @override
  String wheelA11yWeatherSeason(String name) {
    return 'موسم الجو: $name.';
  }

  @override
  String wheelA11yWeather(String weather) {
    return 'الجو المعتاد: $weather.';
  }

  @override
  String get wheelA11yNone => 'لا يوجد';

  @override
  String get wheelA11yHint =>
      'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الدَّرّ.';

  @override
  String get wheelA11yOpenStar => 'افتح صفحة النجم';

  @override
  String get wheelA11yOpenSeason => 'افتح صفحة الموسم';

  @override
  String get wheelA11yOpenWeatherSeason => 'افتح صفحة موسم الجو';

  @override
  String get wheelA11yNextDar => 'انتقل دَرّاً للأمام';

  @override
  String get wheelA11yPrevDar => 'انتقل دَرّاً للخلف';

  @override
  String get wheelA11yBackToToday => 'العودة إلى اليوم';

  @override
  String get detailTypeStar => 'نجم';

  @override
  String get detailTypeSeason => 'موسم';

  @override
  String get detailTypeWeatherSeason => 'موسم جو';

  @override
  String get detailTypeDar => 'دَرّ';

  @override
  String detailRange(String start, String end, String region) {
    return 'من $start إلى $end في جدول $region';
  }

  @override
  String weatherSymbolName(String symbol) {
    String _temp0 = intl.Intl.selectLogic(symbol, {
      'hot': 'حر',
      'very_hot': 'حر شديد',
      'mild': 'معتدل',
      'cool': 'بارد خفيف',
      'cold': 'برد',
      'very_cold': 'برد شديد',
      'wind': 'رياح',
      'wind_strong': 'رياح شديدة',
      'rain': 'مطر',
      'heavy_rain': 'أمطار غزيرة',
      'thunder': 'رعد وبرق',
      'cloud': 'غيوم',
      'dust': 'غبار',
      'humidity': 'رطوبة',
      'fog': 'ضباب',
      'sea_calm': 'بحر هادئ',
      'sea_rough': 'بحر هائج',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String wheelA11yDateValue(String weekday, String gregorian, String hijri) {
    return '$weekday، $gregorian، $hijri هجري.';
  }

  @override
  String gregorianDateSpoken(String day, String month, String year) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'g1': 'يناير',
      'g2': 'فبراير',
      'g3': 'مارس',
      'g4': 'أبريل',
      'g5': 'مايو',
      'g6': 'يونيو',
      'g7': 'يوليو',
      'g8': 'أغسطس',
      'g9': 'سبتمبر',
      'g10': 'أكتوبر',
      'g11': 'نوفمبر',
      'g12': 'ديسمبر',
      'other': '',
    });
    return '$day $_temp0 $year';
  }

  @override
  String hijriDateSpoken(String day, String month, String year) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'm1': 'محرم',
      'm2': 'صفر',
      'm3': 'ربيع الأول',
      'm4': 'ربيع الآخر',
      'm5': 'جمادى الأولى',
      'm6': 'جمادى الآخرة',
      'm7': 'رجب',
      'm8': 'شعبان',
      'm9': 'رمضان',
      'm10': 'شوال',
      'm11': 'ذو القعدة',
      'm12': 'ذو الحجة',
      'other': '',
    });
    return '$day $_temp0 $year';
  }

  @override
  String wheelHubStar(String star) {
    return 'طالع $star';
  }

  @override
  String get homeOriginLink => 'أصل التقويم';

  @override
  String get wheelA11yHintSeason =>
      'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الموسم.';
}
