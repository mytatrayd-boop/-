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

  /// زر العودة إلى اليوم (DESIGN common.today)
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get commonToday;

  /// زر إغلاق الورقة السفلية (DESIGN common.close)
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get commonClose;

  /// سطر المصدر (DESIGN common.source)
  ///
  /// In ar, this message translates to:
  /// **'المصدر: {source}'**
  String commonSource(String source);

  /// شريط ثابت أعلى الشاشات ما دامت في البيانات سجلات غير معتمدة (DESIGN 5.7، common.draft_data_banner)
  ///
  /// In ar, this message translates to:
  /// **'بيانات تجريبية — غير معتمدة'**
  String get draftDataBanner;

  /// فاصل بين عناصر قائمة نصية (مثل رموز الجو المعتاد)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get listSeparator;

  /// اسم اليوم. weekday بالصيغة w1..w7 (1 = الاثنين كما في DateTime.weekday)
  ///
  /// In ar, this message translates to:
  /// **'{weekday, select, w1{الاثنين} w2{الثلاثاء} w3{الأربعاء} w4{الخميس} w5{الجمعة} w6{السبت} w7{الأحد} other{}}'**
  String weekdayName(String weekday);

  /// اسم الشهر الميلادي في حلقة الأشهر. month بالصيغة g1..g12
  ///
  /// In ar, this message translates to:
  /// **'{month, select, g1{يناير} g2{فبراير} g3{مارس} g4{أبريل} g5{مايو} g6{يونيو} g7{يوليو} g8{أغسطس} g9{سبتمبر} g10{أكتوبر} g11{نوفمبر} g12{ديسمبر} other{}}'**
  String gregorianMonthName(String month);

  /// سطر التاريخين في الرئيسية، مثل: الجمعة ٢ أكتوبر ٢٠٢٦م — ٢١ ربيع الآخر ١٤٤٨هـ. الفاصل شرطة طويلة قبلها مسافة لا تنكسر (U+00A0)؛ «·» ممنوعة بجانب الأرقام (DESIGN §3، home.dates_line)
  ///
  /// In ar, this message translates to:
  /// **'{weekday} {gregorian} — {hijri}'**
  String homeDatesLine(String weekday, String gregorian, String hijri);

  /// سطر التاريخين عند عرض تاريخ غير اليوم (DESIGN home.viewing_date)
  ///
  /// In ar, this message translates to:
  /// **'تعرض: {date}'**
  String homeViewingDate(String date);

  /// زر اليوم السابق؛ الضغط المطوّل دَرّ كامل (DESIGN home.prev_day)
  ///
  /// In ar, this message translates to:
  /// **'اليوم السابق'**
  String get homePrevDay;

  /// زر اليوم التالي؛ الضغط المطوّل دَرّ كامل (DESIGN home.next_day)
  ///
  /// In ar, this message translates to:
  /// **'اليوم التالي'**
  String get homeNextDay;

  /// زر اختيار تاريخ (DESIGN home.pick_date)
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخاً'**
  String get homePickDate;

  /// اليوم داخل الدَّرّ بطوله الفعلي (DESIGN home.day_of_dar)
  ///
  /// In ar, this message translates to:
  /// **'اليوم {day} من {total}'**
  String homeDayOfDar(String day, String total);

  /// صف النجم في بطاقة اليوم (DESIGN home.star)
  ///
  /// In ar, this message translates to:
  /// **'النجم'**
  String get homeStar;

  /// صف موسم الجو في بطاقة اليوم (DESIGN home.weather_season)
  ///
  /// In ar, this message translates to:
  /// **'موسم الجو'**
  String get homeWeatherSeason;

  /// بلا موسم جو (DESIGN home.no_weather_season)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موسم جو مسمّى في هذه الأيام'**
  String get homeNoWeatherSeason;

  /// قسم الجو المعتاد في بطاقة اليوم (DESIGN home.usual_weather)
  ///
  /// In ar, this message translates to:
  /// **'الجو المعتاد'**
  String get homeUsualWeather;

  /// صف الدَّرّ في بطاقة اليوم (DESIGN home.dar_details)
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل دَرّ {dar}'**
  String homeDarDetails(String dar);

  /// لم يجد المحرك نتيجة (DESIGN home.calc_error)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حساب هذا اليوم.'**
  String get homeCalcError;

  /// عنوان قسم الدَّرّ لمنطقة تستعير الدرور (D24)، مثل: الدَّرّ حسب حساب الإمارات وعُمان
  ///
  /// In ar, this message translates to:
  /// **'الدَّرّ حسب حساب {region}'**
  String homeDururBorrowed(String region);

  /// وسيلة إيضاح تحت الدائرة لمنطقة تستعير الدرور (D24، ARCHITECTURE §11)
  ///
  /// In ar, this message translates to:
  /// **'حلقة الدرور: حساب {region}'**
  String dialDururLegend(String region);

  /// زر إعادة تكبير الدائرة إلى 1× (DESIGN wheel.reset_zoom)
  ///
  /// In ar, this message translates to:
  /// **'إعادة الحجم'**
  String get wheelResetZoom;

  /// بداية نص قارئ الشاشة للدائرة حين يكون المعروض اليوم (DESIGN wheel.a11y.today)
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get wheelA11yPrefixToday;

  /// بداية نص قارئ الشاشة للدائرة لتاريخ غير اليوم (DESIGN wheel.a11y.viewing)
  ///
  /// In ar, this message translates to:
  /// **'التاريخ المعروض'**
  String get wheelA11yPrefixViewing;

  /// جملة التاريخ لقارئ الشاشة، gregorian وhijri بلا لاحقتي م وهـ (DESIGN wheel.a11y.date)
  ///
  /// In ar, this message translates to:
  /// **'{prefix}: {weekday}، {gregorian}، {hijri} هجري.'**
  String wheelA11yDate(
    String prefix,
    String weekday,
    String gregorian,
    String hijri,
  );

  /// جملة الدَّرّ في نص قارئ الشاشة؛ total طول الدَّرّ الفعلي (DESIGN 7.7)
  ///
  /// In ar, this message translates to:
  /// **'دَرّ {dar} من {season}، اليوم {day} من {total}.'**
  String wheelA11yDar(String dar, String season, String day, String total);

  /// جملة الدَّرّ المستعار (D24) في نص قارئ الشاشة
  ///
  /// In ar, this message translates to:
  /// **'دَرّ {dar} من {season} حسب حساب {region}، اليوم {day} من {total}.'**
  String wheelA11yDarBorrowed(
    String dar,
    String season,
    String region,
    String day,
    String total,
  );

  /// جملة الموسم الكبير في نص قارئ الشاشة لمنطقة تستعير الدرور (D24: المواسم والطوالع أولاً)
  ///
  /// In ar, this message translates to:
  /// **'الموسم: {season}.'**
  String wheelA11yMajorSeason(String season);

  /// جملة النجم في نص قارئ الشاشة (DESIGN 7.7)
  ///
  /// In ar, this message translates to:
  /// **'النجم: {star}.'**
  String wheelA11yStar(String star);

  /// جملة موسم الجو في نص قارئ الشاشة (DESIGN 7.7)
  ///
  /// In ar, this message translates to:
  /// **'موسم الجو: {name}.'**
  String wheelA11yWeatherSeason(String name);

  /// جملة الجو المعتاد في نص قارئ الشاشة (DESIGN 7.7)
  ///
  /// In ar, this message translates to:
  /// **'الجو المعتاد: {weather}.'**
  String wheelA11yWeather(String weather);

  /// لا موسم جو أو لا رموز جو (DESIGN wheel.a11y.none)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد'**
  String get wheelA11yNone;

  /// تلميح قارئ الشاشة للدائرة (DESIGN wheel.a11y.hint)
  ///
  /// In ar, this message translates to:
  /// **'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الدَّرّ.'**
  String get wheelA11yHint;

  /// إجراء مخصص لقارئ الشاشة (DESIGN wheel.a11y.open_star)
  ///
  /// In ar, this message translates to:
  /// **'افتح صفحة النجم'**
  String get wheelA11yOpenStar;

  /// إجراء مخصص لقارئ الشاشة (DESIGN wheel.a11y.open_season)
  ///
  /// In ar, this message translates to:
  /// **'افتح صفحة الموسم'**
  String get wheelA11yOpenSeason;

  /// إجراء مخصص لقارئ الشاشة (DESIGN wheel.a11y.open_weather_season)
  ///
  /// In ar, this message translates to:
  /// **'افتح صفحة موسم الجو'**
  String get wheelA11yOpenWeatherSeason;

  /// إجراء مخصص لقارئ الشاشة (DESIGN wheel.a11y.next_dar)
  ///
  /// In ar, this message translates to:
  /// **'انتقل دَرّاً للأمام'**
  String get wheelA11yNextDar;

  /// إجراء مخصص لقارئ الشاشة (DESIGN wheel.a11y.prev_dar)
  ///
  /// In ar, this message translates to:
  /// **'انتقل دَرّاً للخلف'**
  String get wheelA11yPrevDar;

  /// إجراء مخصص لقارئ الشاشة (DESIGN wheel.a11y.back_to_today)
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى اليوم'**
  String get wheelA11yBackToToday;

  /// نوع العنصر في ورقته (DESIGN detail.type.star)
  ///
  /// In ar, this message translates to:
  /// **'نجم'**
  String get detailTypeStar;

  /// نوع العنصر في ورقته (DESIGN detail.type.season)
  ///
  /// In ar, this message translates to:
  /// **'موسم'**
  String get detailTypeSeason;

  /// نوع العنصر في ورقته (DESIGN detail.type.weather_season)
  ///
  /// In ar, this message translates to:
  /// **'موسم جو'**
  String get detailTypeWeatherSeason;

  /// نوع العنصر في ورقته (DESIGN detail.type.dar)
  ///
  /// In ar, this message translates to:
  /// **'دَرّ'**
  String get detailTypeDar;

  /// تواريخ العنصر في منطقة المستخدم (DESIGN detail.range)
  ///
  /// In ar, this message translates to:
  /// **'من {start} إلى {end} في جدول {region}'**
  String detailRange(String start, String end, String region);

  /// اسم رمز الجو للشرائح وقارئ الشاشة (D23، DESIGN weather.*). symbol رمز JSON مثل very_hot
  ///
  /// In ar, this message translates to:
  /// **'{symbol, select, hot{حر} very_hot{حر شديد} mild{معتدل} cool{بارد خفيف} cold{برد} very_cold{برد شديد} wind{رياح} wind_strong{رياح شديدة} rain{مطر} heavy_rain{أمطار غزيرة} thunder{رعد وبرق} cloud{غيوم} dust{غبار} humidity{رطوبة} fog{ضباب} sea_calm{بحر هادئ} sea_rough{بحر هائج} other{}}'**
  String weatherSymbolName(String symbol);

  /// جملة التاريخ في قيمة الدائرة لقارئ الشاشة (value): مثل wheelA11yDate بلا البادئة، لأن البادئة («اليوم» أو «التاريخ المعروض») في label
  ///
  /// In ar, this message translates to:
  /// **'{weekday}، {gregorian}، {hijri} هجري.'**
  String wheelA11yDateValue(String weekday, String gregorian, String hijri);

  /// التاريخ الميلادي المسموع بلا لاحقة «م» (DESIGN 13: wheel.a11y.date)
  ///
  /// In ar, this message translates to:
  /// **'{day} {month, select, g1{يناير} g2{فبراير} g3{مارس} g4{أبريل} g5{مايو} g6{يونيو} g7{يوليو} g8{أغسطس} g9{سبتمبر} g10{أكتوبر} g11{نوفمبر} g12{ديسمبر} other{}} {year}'**
  String gregorianDateSpoken(String day, String month, String year);

  /// التاريخ الهجري المسموع بلا لاحقة «هـ» (DESIGN 13: wheel.a11y.date)
  ///
  /// In ar, this message translates to:
  /// **'{day} {month, select, m1{محرم} m2{صفر} m3{ربيع الأول} m4{ربيع الآخر} m5{جمادى الأولى} m6{جمادى الآخرة} m7{رجب} m8{شعبان} m9{رمضان} m10{شوال} m11{ذو القعدة} m12{ذو الحجة} other{}} {year}'**
  String hijriDateSpoken(String day, String month, String year);

  /// السطر الثاني في محور الدائرة للمنطقة المستعيرة للدرور، مثل: طالع الغفر (DESIGN wheel.hub_star، 7.8)
  ///
  /// In ar, this message translates to:
  /// **'طالع {star}'**
  String wheelHubStar(String star);

  /// رابط صفحة أصل التقويم للمنطقة المستعيرة (DESIGN home.origin_link، 7.8)
  ///
  /// In ar, this message translates to:
  /// **'أصل التقويم'**
  String get homeOriginLink;

  /// تلميح قارئ الشاشة للدائرة في المنطقة المستعيرة، المحور يفتح الموسم (DESIGN wheel.a11y.hint_season)
  ///
  /// In ar, this message translates to:
  /// **'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الموسم.'**
  String get wheelA11yHintSeason;

  /// جملة التاريخ في قيمة الدائرة لقارئ الشاشة حين لا يوجد تاريخ هجري (خارج مدى جدول أم القرى): بلا كلمة «هجري»
  ///
  /// In ar, this message translates to:
  /// **'{weekday}، {gregorian}.'**
  String wheelA11yDateValueNoHijri(String weekday, String gregorian);

  /// زر الرجوع (DESIGN common.back)، ومنه الرجوع الداخلي في ورقة العنصر
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get commonBack;

  /// مدة الفترة في صفحة العنصر (DESIGN detail.duration). count العدد، days العدد منسّقاً بأرقام الإعداد
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} other{{days} يوماً}}'**
  String detailDuration(int count, String days);

  /// حالة العنصر اليوم: داخله (DESIGN detail.status.now)
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الآن — اليوم {day} من {total}'**
  String detailStatusNow(String day, String total);

  /// حالة العنصر: لم يبدأ بعد (DESIGN detail.status.upcoming)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يبدأ بعد يوم واحد} =2{يبدأ بعد يومين} few{يبدأ بعد {days} أيام} other{يبدأ بعد {days} يوماً}}'**
  String detailStatusUpcoming(int count, String days);

  /// حالة العنصر: انتهى (DESIGN detail.status.past)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{انتهى قبل يوم واحد} =2{انتهى قبل يومين} few{انتهى قبل {days} أيام} other{انتهى قبل {days} يوماً}}'**
  String detailStatusPast(int count, String days);

  /// لسهيل والثريا: تاريخ الطلوع المحسوب لمدينة المستخدم (DESIGN home.star_rises_on، الميزة 5 معيار 4)
  ///
  /// In ar, this message translates to:
  /// **'يطلع في {city} يوم {date}'**
  String detailStarRisesOn(String city, String date);

  /// لسهيل والثريا: مضى على الطلوع المحسوب (DESIGN home.star_risen_ago)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{طلع في {city} قبل يوم واحد} =2{طلع في {city} قبل يومين} few{طلع في {city} قبل {days} أيام} other{طلع في {city} قبل {days} يوماً}}'**
  String detailStarRisenAgo(int count, String city, String days);

  /// لسهيل والثريا: الطلوع المحسوب هو اليوم
  ///
  /// In ar, this message translates to:
  /// **'يطلع في {city} اليوم'**
  String detailStarRisesToday(String city);

  /// تحت تاريخ طلوع سهيل/الثريا (DESIGN detail.astro_note)
  ///
  /// In ar, this message translates to:
  /// **'محسوب فلكياً لموقع مدينتك.'**
  String get detailAstroNote;

  /// تعذّر حساب طلوع سهيل/الثريا (DESIGN detail.astro_fallback)
  ///
  /// In ar, this message translates to:
  /// **'تاريخ تقريبي من جدول المنطقة.'**
  String get detailAstroFallback;

  /// عنوان بطاقة المثل (DESIGN detail.proverb)
  ///
  /// In ar, this message translates to:
  /// **'مثل شعبي'**
  String get detailProverb;

  /// زر نصي في بطاقة التواريخ يدير الدائرة إلى أول يوم في العنصر (DESIGN detail.go_to_start)
  ///
  /// In ar, this message translates to:
  /// **'انتقل إلى بدايته'**
  String get detailGoToStart;

  /// شريحة مئة الدَّرّ في صفحة الدَّرّ (D26): «من الصفري»، والضغط يفتح صفحة المئة
  ///
  /// In ar, this message translates to:
  /// **'من {season}'**
  String detailDarHundred(String season);

  /// مصدر نص العنصر في items.json
  ///
  /// In ar, this message translates to:
  /// **'مصدر التعريف والمثل: {source}'**
  String detailContentSource(String source);

  /// مصدر سجل الفترة في جدول المنطقة
  ///
  /// In ar, this message translates to:
  /// **'مصدر التواريخ: {source}'**
  String detailDatesSource(String source);

  /// سجل لم يعتمده المراجع بعد (صفحة العنصر وصفحة المصادر)
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الاعتماد'**
  String get approvalPending;

  /// عنوان صفحة أصل التقويم (/about/origin، D24)
  ///
  /// In ar, this message translates to:
  /// **'أصل التقويم'**
  String get originTitle;

  /// قسم في صفحة أصل التقويم
  ///
  /// In ar, this message translates to:
  /// **'الطوالع والمواسم'**
  String get originTawaliTitle;

  /// أصل الطوالع والمواسم (research/SAUDI.md §3، بانتظار المراجع)
  ///
  /// In ar, this message translates to:
  /// **'ميراث أهل نجد والجزيرة، يبدأ بسهيل. المصادر: المسند والزعاق وغيرهما.'**
  String get originTawaliBody;

  /// قسم في صفحة أصل التقويم
  ///
  /// In ar, this message translates to:
  /// **'الدرور'**
  String get originDururTitle;

  /// أصل الدرور (research/SAUDI.md §3، بانتظار المراجع)
  ///
  /// In ar, this message translates to:
  /// **'حساب عشري (٣٦ دَرّاً × ١٠ أيام) لأهل الساحل الخليجي. معروض هنا للمقارنة.'**
  String get originDururBody;

  /// قسم في الإعدادات (DESIGN settings.section.help)
  ///
  /// In ar, this message translates to:
  /// **'البيانات والمساعدة'**
  String get settingsSectionHelp;

  /// صف المصادر في الإعدادات وعنوان صفحتها (DESIGN settings.sources)
  ///
  /// In ar, this message translates to:
  /// **'المصادر'**
  String get settingsSources;

  /// قسم في صفحة المصادر: مصادر كل السجلات بلا تكرار (D27)
  ///
  /// In ar, this message translates to:
  /// **'مصادر الجداول'**
  String get sourcesTablesTitle;

  /// مرجع الاعتماد لمصدر في صفحة المصادر
  ///
  /// In ar, this message translates to:
  /// **'اعتمده: {reviewers}'**
  String sourcesApprovedBy(String reviewers);

  /// قسم ثابت في صفحة المصادر (D27)
  ///
  /// In ar, this message translates to:
  /// **'رخص البيانات'**
  String get sourcesLicensesTitle;

  /// إشارة GeoNames المطلوبة برخصة CC BY 4.0 (D27)
  ///
  /// In ar, this message translates to:
  /// **'إحداثيات المدن من GeoNames (geonames.org)، برخصة المشاع الإبداعي نَسب المُصنَّف 4.0 (CC BY 4.0). عُدّلت: اختيار المدن وربطها بالمناطق.'**
  String get sourcesGeoNames;

  /// رابط يفتح https://www.geonames.org/ في المتصفح
  ///
  /// In ar, this message translates to:
  /// **'موقع GeoNames'**
  String get sourcesGeoNamesLink;

  /// رابط يفتح https://creativecommons.org/licenses/by/4.0/ في المتصفح
  ///
  /// In ar, this message translates to:
  /// **'نص رخصة CC BY 4.0'**
  String get sourcesLicenseLink;

  /// قسم في صفحة المصادر (D27 بند 3)
  ///
  /// In ar, this message translates to:
  /// **'التقويم الهجري'**
  String get sourcesHijriTitle;

  /// مصدر التقويم الهجري (D27 بند 3)
  ///
  /// In ar, this message translates to:
  /// **'تقويم أم القرى: بدايات الأشهر من جداول R. H. van Gent.'**
  String get sourcesHijri;

  /// فشل فتح رابط خارجي في المتصفح
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرابط.'**
  String get linkOpenError;
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
