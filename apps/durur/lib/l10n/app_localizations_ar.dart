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
}
