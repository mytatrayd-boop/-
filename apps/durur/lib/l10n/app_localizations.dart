import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// اسم التطبيق
  ///
  /// In ar, this message translates to:
  /// **'ديرة الدرور'**
  String get appTitle;

  /// عنوان قسم تاريخ اليوم في الشاشة الرئيسية
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get todayLabel;

  /// عبارة ثابتة في الشاشة الرئيسية (SPEC الميزة 6)
  ///
  /// In ar, this message translates to:
  /// **'الجو المعتاد حسب التراث، وليس توقعاً للطقس'**
  String get traditionDisclaimer;

  /// التاريخ الهجري حسب أم القرى، مثل: ٢١ ربيع الآخر ١٤٤٨هـ. day وyear أرقام منسقة مسبقاً، وmonth بالصيغة m1..m12 (SPEC الميزة 2)
  ///
  /// In ar, this message translates to:
  /// **'{day} {month, select, m1{محرم} m2{صفر} m3{ربيع الأول} m4{ربيع الآخر} m5{جمادى الأولى} m6{جمادى الآخرة} m7{رجب} m8{شعبان} m9{رمضان} m10{شوال} m11{ذو القعدة} m12{ذو الحجة} other{}} {year}هـ'**
  String hijriDate(String day, String month, String year);

  /// التاريخ الميلادي، مثل: ٢ أكتوبر ٢٠٢٦م. day وyear أرقام منسقة مسبقاً، وmonth بالصيغة g1..g12 (SPEC الميزة 2)
  ///
  /// In ar, this message translates to:
  /// **'{day} {month, select, g1{يناير} g2{فبراير} g3{مارس} g4{أبريل} g5{مايو} g6{يونيو} g7{يوليو} g8{أغسطس} g9{سبتمبر} g10{أكتوبر} g11{نوفمبر} g12{ديسمبر} other{}} {year}م'**
  String gregorianDate(String day, String month, String year);

  /// زر إعادة المحاولة بعد خطأ (DESIGN common.retry)
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get commonRetry;

  /// عنوان شاشة اختيار المدينة، ونص شريحة/صف المدينة قبل الاختيار (DESIGN city.title)
  ///
  /// In ar, this message translates to:
  /// **'اختر مدينتك'**
  String get cityPickerTitle;

  /// تلميح حقل البحث في قائمة المدن (DESIGN city.search_hint)
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم المدينة'**
  String get citySearchHint;

  /// شريحة تصفية: كل الدول (DESIGN city.filter_all)
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get cityFilterAll;

  /// اسم الدولة لشرائح التصفية وعناوين المجموعات. country رمز ISO مثل SA
  ///
  /// In ar, this message translates to:
  /// **'{country, select, SA{السعودية} KW{الكويت} AE{الإمارات} OM{عُمان} QA{قطر} BH{البحرين} other{}}'**
  String countryName(String country);

  /// سطر تحت اسم المدينة في القائمة (DESIGN city.region_label)
  ///
  /// In ar, this message translates to:
  /// **'جدول: {region}'**
  String cityRegionLabel(String region);

  /// رسالة قصيرة بعد اختيار مدينة (DESIGN city.selected)
  ///
  /// In ar, this message translates to:
  /// **'تم اختيار {city} — جدول {region}'**
  String citySelected(String city, String region);

  /// عنوان حالة لا نتائج للبحث (DESIGN city.empty.title)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدينة بهذا الاسم.'**
  String get cityEmptyTitle;

  /// نص حالة لا نتائج للبحث (DESIGN city.empty.body)
  ///
  /// In ar, this message translates to:
  /// **'جرّب اسماً آخر أو اختر أقرب مدينة لك.'**
  String get cityEmptyBody;

  /// زر مسح البحث في حالة لا نتائج (DESIGN city.empty.clear)
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get cityEmptyClear;

  /// فشل حفظ المدينة (DESIGN city.save_error)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ اختيارك. حاول مرة أخرى.'**
  String get citySaveError;

  /// شريحة المدينة أعلى الرئيسية، مثل: الرياض · نجد (DESIGN 5.3)
  ///
  /// In ar, this message translates to:
  /// **'{city} · {region}'**
  String cityChipLabel(String city, String region);

  /// عنوان شاشة الإعدادات وتلميح زرها (DESIGN settings.title)
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// عنوان قسم المنطقة في الإعدادات (DESIGN settings.section.region)
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get settingsSectionRegion;

  /// صف المدينة في الإعدادات (DESIGN settings.city)
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get settingsCity;

  /// قيمة صف المدينة في الإعدادات (DESIGN settings.city_value)
  ///
  /// In ar, this message translates to:
  /// **'{city} — جدول {region}'**
  String settingsCityValue(String city, String region);

  /// خطأ قراءة البيانات المضمّنة (DESIGN error.data_load.title)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح بيانات الدرور'**
  String get dataLoadErrorTitle;

  /// نص خطأ قراءة البيانات (DESIGN error.data_load.body)
  ///
  /// In ar, this message translates to:
  /// **'أعد تشغيل التطبيق. إذا تكرر ذلك، حدّث التطبيق من المتجر.'**
  String get dataLoadErrorBody;

  /// زر المتابعة (DESIGN common.continue)
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get commonContinue;

  /// عنوان شاشة الترحيب (DESIGN onboarding.welcome.title)
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في ديرة الدرور'**
  String get onboardingWelcomeTitle;

  /// نص شاشة الترحيب (DESIGN onboarding.welcome.body)
  ///
  /// In ar, this message translates to:
  /// **'تعرف الدَّرّ والموسم والنجم اليوم في منطقتك، وما الجو المعتاد فيه. يعمل بلا إنترنت.'**
  String get onboardingWelcomeBody;

  /// زر شاشة الترحيب (DESIGN onboarding.welcome.start)
  ///
  /// In ar, this message translates to:
  /// **'ابدأ'**
  String get onboardingWelcomeStart;

  /// عنوان شرح الموقع (DESIGN onboarding.location.title)
  ///
  /// In ar, this message translates to:
  /// **'في أي منطقة أنت؟'**
  String get onboardingLocationTitle;

  /// سطر شرح سبب طلب الموقع (SPEC الميزة 4 بند 1، DESIGN onboarding.location.body)
  ///
  /// In ar, this message translates to:
  /// **'نستخدم موقعك التقريبي مرة واحدة لنعرف جدول درور منطقتك. لا نتتبعك ولا نرسل موقعك لأي جهة.'**
  String get onboardingLocationBody;

  /// زر طلب الموقع التقريبي (DESIGN onboarding.location.allow)
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقعي'**
  String get onboardingLocationAllow;

  /// زر الاختيار اليدوي بلا طلب إذن (DESIGN onboarding.location.manual)
  ///
  /// In ar, this message translates to:
  /// **'اختر مدينتك يدوياً'**
  String get onboardingLocationManual;

  /// زر نصي ظاهر أثناء تحديد الموقع (DESIGN 8.2 ج)
  ///
  /// In ar, this message translates to:
  /// **'اختر يدوياً'**
  String get onboardingLocationManualShort;

  /// أثناء قراءة الموقع (DESIGN onboarding.location.loading)
  ///
  /// In ar, this message translates to:
  /// **'نحدد مدينتك…'**
  String get onboardingLocationLoading;

  /// نتيجة تحديد الموقع (DESIGN onboarding.location.found)
  ///
  /// In ar, this message translates to:
  /// **'وجدنا أقرب مدينة لك: {city}'**
  String onboardingLocationFound(String city);

  /// منطقة المدينة الموجودة (DESIGN onboarding.location.region)
  ///
  /// In ar, this message translates to:
  /// **'جدول المنطقة: {region}'**
  String onboardingLocationRegion(String region);

  /// يفتح القائمة لتغيير المدينة الموجودة (DESIGN onboarding.location.not_my_city)
  ///
  /// In ar, this message translates to:
  /// **'ليست مدينتي'**
  String get onboardingLocationNotMyCity;

  /// أعلى القائمة بعد رفض الإذن (DESIGN location.denied)
  ///
  /// In ar, this message translates to:
  /// **'لا بأس، اختر مدينتك من القائمة.'**
  String get locationDenied;

  /// رفض دائم سابق أو خدمة الموقع مطفأة أو خطأ من النظام (DESIGN location.unavailable)
  ///
  /// In ar, this message translates to:
  /// **'خدمة الموقع غير متاحة. اختر مدينتك من القائمة.'**
  String get locationUnavailable;

  /// لم تصل قراءة خلال 10 ثوانٍ (DESIGN location.timeout)
  ///
  /// In ar, this message translates to:
  /// **'تأخر تحديد الموقع. اختر مدينتك من القائمة.'**
  String get locationTimeout;

  /// أقرب مدينة أبعد من 250 كم (DESIGN location.out_of_range)
  ///
  /// In ar, this message translates to:
  /// **'منطقتك خارج نطاق الجداول المتاحة. اختر أقرب مدينة خليجية إليك.'**
  String get locationOutOfRange;

  /// فشل «تحديد موقعي مرة أخرى» في الإعدادات (DESIGN location.failed_settings)
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من الوصول لموقعك. يمكنك اختيار مدينتك يدوياً.'**
  String get locationFailedSettings;

  /// نجاح «تحديد موقعي مرة أخرى» بمدينة جديدة (DESIGN location.updated)
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث مدينتك إلى {city} — جدول {region}'**
  String locationUpdated(String city, String region);

  /// نجاح «تحديد موقعي مرة أخرى» بالمدينة نفسها (DESIGN location.unchanged)
  ///
  /// In ar, this message translates to:
  /// **'مدينتك كما هي: {city}'**
  String locationUnchanged(String city);

  /// زر في رسالة فشل تحديد الموقع يفتح القائمة (DESIGN 8.7)
  ///
  /// In ar, this message translates to:
  /// **'اختيار المدينة'**
  String get locationChooseCity;

  /// صف في الإعدادات (SPEC الميزة 4 بند 6، DESIGN settings.relocate)
  ///
  /// In ar, this message translates to:
  /// **'تحديد موقعي مرة أخرى'**
  String get settingsRelocate;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
