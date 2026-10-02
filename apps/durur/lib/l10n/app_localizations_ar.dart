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

  @override
  String wheelA11yDateValueNoHijri(String weekday, String gregorian) {
    return '$weekday، $gregorian.';
  }

  @override
  String get commonBack => 'رجوع';

  @override
  String detailDuration(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$days يوماً',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String detailStatusNow(String day, String total) {
    return 'جارٍ الآن — اليوم $day من $total';
  }

  @override
  String detailStatusUpcoming(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يبدأ بعد $days يوماً',
      few: 'يبدأ بعد $days أيام',
      two: 'يبدأ بعد يومين',
      one: 'يبدأ بعد يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String detailStatusPast(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'انتهى قبل $days يوماً',
      few: 'انتهى قبل $days أيام',
      two: 'انتهى قبل يومين',
      one: 'انتهى قبل يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String detailStarRisesOn(String gender, String city, String date) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'f': 'تطلع في $city يوم $date',
      'other': 'يطلع في $city يوم $date',
    });
    return '$_temp0';
  }

  @override
  String detailStarRisenAgo(
    String gender,
    int count,
    String city,
    String days,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'طلعت في $city قبل $days يوماً',
      few: 'طلعت في $city قبل $days أيام',
      two: 'طلعت في $city قبل يومين',
      one: 'طلعت في $city قبل يوم واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'طلع في $city قبل $days يوماً',
      few: 'طلع في $city قبل $days أيام',
      two: 'طلع في $city قبل يومين',
      one: 'طلع في $city قبل يوم واحد',
    );
    String _temp2 = intl.Intl.selectLogic(gender, {
      'f': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String detailStarRisesToday(String gender, String city) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'f': 'تطلع في $city اليوم',
      'other': 'يطلع في $city اليوم',
    });
    return '$_temp0';
  }

  @override
  String get detailAstroNote => 'محسوب فلكياً لموقع مدينتك.';

  @override
  String get detailAstroFallback => 'تاريخ تقريبي من جدول المنطقة.';

  @override
  String get detailProverb => 'مثل شعبي';

  @override
  String get detailGoToStart => 'انتقل إلى بدايته';

  @override
  String detailDarHundred(String season) {
    return 'من $season';
  }

  @override
  String detailContentSource(String source) {
    return 'مصدر التعريف والمثل: $source';
  }

  @override
  String detailDatesSource(String source) {
    return 'مصدر التواريخ: $source';
  }

  @override
  String get approvalPending => 'بانتظار الاعتماد';

  @override
  String get originTitle => 'أصل التقويم';

  @override
  String get originTawaliTitle => 'الطوالع والمواسم';

  @override
  String get originTawaliBody =>
      'ميراث أهل نجد والجزيرة، يبدأ بسهيل. المصادر: المسند والزعاق وغيرهما.';

  @override
  String get originDururTitle => 'الدرور';

  @override
  String get originDururBody =>
      'حساب عشري (٣٦ دَرّاً × ١٠ أيام) لأهل الساحل الخليجي.';

  @override
  String get originDururComparison => 'معروض هنا للمقارنة.';

  @override
  String get settingsSectionHelp => 'البيانات والمساعدة';

  @override
  String get settingsSources => 'المصادر';

  @override
  String get sourcesTablesTitle => 'مصادر الجداول';

  @override
  String sourcesApprovedBy(String reviewers) {
    return 'اعتمده: $reviewers';
  }

  @override
  String get sourcesLicensesTitle => 'رخص البيانات';

  @override
  String get sourcesGeoNames =>
      'إحداثيات المدن من GeoNames (geonames.org)، برخصة المشاع الإبداعي نَسب المُصنَّف 4.0 (CC BY 4.0). عُدّلت: اختيار المدن وربطها بالمناطق.';

  @override
  String get sourcesGeoNamesLink => 'موقع GeoNames';

  @override
  String get sourcesLicenseLink => 'نص رخصة CC BY 4.0';

  @override
  String get sourcesHijriTitle => 'التقويم الهجري';

  @override
  String get sourcesHijri =>
      'تقويم أم القرى: بدايات الأشهر من جداول R. H. van Gent.';

  @override
  String get linkOpenError => 'تعذّر فتح الرابط.';

  @override
  String get commonNotNow => 'ليس الآن';

  @override
  String get onboardingNotificationsTitle => 'لا يفوتك الوسم';

  @override
  String get onboardingNotificationsBody =>
      'نذكّرك الساعة ٨ صباحاً عند دخول المواسم المهمة: سهيل، والوسم، والمربعانية، وبرد العجايز، والثريا، وجمرة القيظ.';

  @override
  String get onboardingNotificationsAllow => 'فعّل التنبيهات';

  @override
  String get settingsSectionNotifications => 'التنبيهات';

  @override
  String get settingsNotifImportant => 'المواسم المهمة';

  @override
  String get settingsNotifImportantDesc =>
      'سهيل، الوسم، المربعانية، برد العجايز، الثريا، جمرة القيظ.';

  @override
  String get settingsNotifDar => 'بداية كل دَرّ';

  @override
  String get settingsNotifDarDesc =>
      'تنبيه كل عشرة أيام تقريباً عند بداية دَرّ جديد.';

  @override
  String get settingsNotifTimeNote =>
      'تصل التنبيهات الساعة ٨:٠٠ صباحاً بتوقيت جهازك.';

  @override
  String get settingsNotifDenied => 'التنبيهات متوقفة من إعدادات جهازك.';

  @override
  String get settingsNotifOpenDeviceSettings => 'فتح إعدادات الجهاز';

  @override
  String get settingsNotifScheduleError =>
      'تعذّر ضبط التنبيهات. أعد فتح التطبيق وحاول مرة أخرى.';

  @override
  String get settingsSectionAppearance => 'المظهر';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get settingsThemeSystem => 'تلقائي (حسب الجهاز)';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsDigits => 'الأرقام';

  @override
  String get settingsDigitsArabic => '١٢٣';

  @override
  String get settingsDigitsLatin => '123';

  @override
  String notifSeasonTitle(String season, String region) {
    return 'دخل $season اليوم في $region';
  }

  @override
  String notifSeasonBody(String season) {
    return 'اضغط لتعرف عن $season ومثله الشعبي.';
  }

  @override
  String notifStarTitle(String gender, String star, String city) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'f': 'طلعت $star اليوم في $city',
      'other': 'طلع $star اليوم في $city',
    });
    return '$_temp0';
  }

  @override
  String notifStarBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'f': 'أول ظهورها قبل الفجر. اضغط لتعرف عنها.',
      'other': 'أول ظهوره قبل الفجر. اضغط لتعرف عنه.',
    });
    return '$_temp0';
  }

  @override
  String notifDarTitle(String dar, String season) {
    return 'بدأ دَرّ $dar من $season';
  }

  @override
  String notifDarTitleBorrowed(String dar, String season, String region) {
    return 'بدأ دَرّ $dar من $season حسب حساب $region';
  }

  @override
  String notifDarBody(String weather) {
    return 'الجو المعتاد: $weather';
  }

  @override
  String get notifChannelImportant => 'المواسم المهمة';

  @override
  String get notifChannelDar => 'بداية كل دَرّ';

  @override
  String get detailReport => 'أبلغ عن خطأ';

  @override
  String get settingsReport => 'أبلغ عن خطأ';

  @override
  String get reportTitle => 'أبلغ عن خطأ';

  @override
  String get reportIntroForm =>
      'سنفتح لك النموذج وفيه هذه المعلومات. أكمل وصف الخطأ ثم اضغط إرسال بنفسك.';

  @override
  String get reportIntroFormPaste =>
      'سننسخ لك هذه المعلومات ونفتح النموذج. الصقها فيه وأكمل وصف الخطأ ثم اضغط إرسال بنفسك.';

  @override
  String get reportIntroCopy =>
      'انسخ هذه المعلومات وأرفقها بوصف الخطأ في بلاغك.';

  @override
  String reportItem(String item) {
    return 'العنصر: $item';
  }

  @override
  String reportRegion(String region) {
    return 'المنطقة: $region';
  }

  @override
  String reportDate(String date) {
    return 'التاريخ المعروض: $date';
  }

  @override
  String reportVersion(String version) {
    return 'نسخة التطبيق: $version';
  }

  @override
  String reportDataVersion(String version, String seq) {
    return 'نسخة البيانات: $version ($seq)';
  }

  @override
  String get reportOpenForm => 'متابعة إلى النموذج';

  @override
  String get reportNothingSent => 'لن يُرسل شيء حتى تضغط إرسال بنفسك.';

  @override
  String get reportCopyDetails => 'نسخ تفاصيل البلاغ';

  @override
  String get reportDetailsCopied => 'تم نسخ تفاصيل البلاغ';

  @override
  String get reportPasteHint =>
      'نسخنا تفاصيل البلاغ. الصقها في النموذج ثم أكمل وصف الخطأ.';

  @override
  String get reportFormOpenError =>
      'تعذّر فتح النموذج. انسخ تفاصيل البلاغ وأرسلها لاحقاً.';

  @override
  String get reportCopyError => 'تعذّر نسخ تفاصيل البلاغ. حاول مرة أخرى.';

  @override
  String get settingsSectionUpdate => 'تحديث البيانات';

  @override
  String get settingsUpdateAuto => 'تحديث البيانات تلقائياً';

  @override
  String get settingsUpdateAutoDesc =>
      'نتحقق مرة في الأسبوع عند فتح التطبيق، بلا أي معلومة عنك.';

  @override
  String settingsUpdateStatus(String version, String date) {
    return 'نسخة البيانات: $version — آخر تحقق: $date';
  }

  @override
  String settingsUpdateStatusNever(String version) {
    return 'نسخة البيانات: $version — لم نتحقق بعد';
  }

  @override
  String get settingsUpdateDateToday => 'اليوم';

  @override
  String get settingsUpdateDateYesterday => 'أمس';

  @override
  String get settingsUpdateCheckNow => 'تحقق الآن';

  @override
  String get settingsUpdateChecking => 'جارٍ التحقق…';

  @override
  String get settingsUpdateUpToDate => 'بياناتك محدّثة.';

  @override
  String get settingsUpdateNetworkError =>
      'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة أخرى.';

  @override
  String get settingsUpdateVerifyError =>
      'تعذّر التحقق من التحديث. بياناتك الحالية تعمل كما هي.';

  @override
  String get settingsUpdateUpdated => 'حُدّثت البيانات';

  @override
  String sourcesDataUpdated(String date) {
    return 'آخر تحديث للبيانات: $date';
  }

  @override
  String sourcesDataBundled(String appVersion) {
    return 'البيانات المرفقة مع نسخة التطبيق $appVersion';
  }

  @override
  String sourcesDataVersion(String version, String seq) {
    return 'نسخة البيانات: $version ($seq)';
  }
}
