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
  /// **'دليل المواسم'**
  String get appTitle;

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
  /// **'أهلاً بك في دليل المواسم'**
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

  /// قسم الجو المعتاد في بطاقة اليوم (DESIGN home.usual_weather)
  ///
  /// In ar, this message translates to:
  /// **'الجو المعتاد'**
  String get homeUsualWeather;

  /// لم يجد المحرك نتيجة (DESIGN home.calc_error)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حساب هذا اليوم.'**
  String get homeCalcError;

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

  /// تلميح قارئ الشاشة للدائرة: المقبض يفتح ما يعرضه المركز، موسم الجو المسمّى أو الموسم الكبير (DESIGN R2.5 F، wheel.a11y.hint_season)
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

  /// لسهيل والثريا: تاريخ الطلوع المحسوب لمدينة المستخدم (DESIGN home.star_rises_on، الميزة 5 معيار 4). gender = جنس النجم من items.json: "f" مؤنث، وغيره مذكر (DESIGN §13 «جنس النجم»)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{تطلع في {city} يوم {date}} other{يطلع في {city} يوم {date}}}'**
  String detailStarRisesOn(String gender, String city, String date);

  /// لسهيل والثريا: مضى على الطلوع المحسوب (DESIGN home.star_risen_ago). gender = جنس النجم من items.json: "f" مؤنث، وغيره مذكر (DESIGN §13 «جنس النجم»)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{{count, plural, =1{طلعت في {city} قبل يوم واحد} =2{طلعت في {city} قبل يومين} few{طلعت في {city} قبل {days} أيام} other{طلعت في {city} قبل {days} يوماً}}} other{{count, plural, =1{طلع في {city} قبل يوم واحد} =2{طلع في {city} قبل يومين} few{طلع في {city} قبل {days} أيام} other{طلع في {city} قبل {days} يوماً}}}}'**
  String detailStarRisenAgo(String gender, int count, String city, String days);

  /// لسهيل والثريا: الطلوع المحسوب هو اليوم. gender = جنس النجم من items.json: "f" مؤنث، وغيره مذكر (DESIGN §13 «جنس النجم»)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{تطلع في {city} اليوم} other{يطلع في {city} اليوم}}'**
  String detailStarRisesToday(String gender, String city);

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

  /// أصل الدرور (research/SAUDI.md §3)، معاد صياغته بعد D43/D50 (ARCHITECTURE §18): «حساب خليجي ساحلي لا يُستعمل في السعودية». بانتظار المراجع
  ///
  /// In ar, this message translates to:
  /// **'حساب عشري (٣٦ دَرّاً × ١٠ أيام) لأهل الساحل الخليجي، ولا يُستعمل في السعودية.'**
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

  /// إشارة Natural Earth لخريطة الخلفية (DESIGN R3.1-13)؛ ملكية عامة لا تشترط إشارة لكننا نذكرها
  ///
  /// In ar, this message translates to:
  /// **'خريطة الخليج في خلفية الشاشة الرئيسية من بيانات Natural Earth (naturalearthdata.com)، وهي ملكية عامة.'**
  String get sourcesNaturalEarth;

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

  /// زر نصي للتأجيل (DESIGN common.not_now)
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get commonNotNow;

  /// عنوان شرح التنبيهات في البداية (DESIGN onboarding.notifications.title، 8.2 د)
  ///
  /// In ar, this message translates to:
  /// **'لا يفوتك الوسم'**
  String get onboardingNotificationsTitle;

  /// سطر شرح سبب إذن التنبيهات (DESIGN onboarding.notifications.body، SPEC 8 معيار 8). الأرقام تتبع إعداد «الأرقام»
  ///
  /// In ar, this message translates to:
  /// **'نذكّرك الساعة ٨ صباحاً عند دخول المواسم المهمة: سهيل، والوسم، والمربعانية، وبرد العجايز، والثريا، وجمرة القيظ.'**
  String get onboardingNotificationsBody;

  /// زر طلب إذن التنبيهات (DESIGN onboarding.notifications.allow)
  ///
  /// In ar, this message translates to:
  /// **'فعّل التنبيهات'**
  String get onboardingNotificationsAllow;

  /// قسم في الإعدادات (DESIGN settings.section.notifications)
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get settingsSectionNotifications;

  /// مفتاح تنبيهات المواسم المهمة (DESIGN settings.notif.important)
  ///
  /// In ar, this message translates to:
  /// **'المواسم المهمة'**
  String get settingsNotifImportant;

  /// وصف مفتاح المواسم المهمة (DESIGN settings.notif.important_desc)
  ///
  /// In ar, this message translates to:
  /// **'سهيل، الوسم، المربعانية، برد العجايز، الثريا، جمرة القيظ.'**
  String get settingsNotifImportantDesc;

  /// مفتاح تنبيه بداية الدَّرّ (DESIGN settings.notif.dar)
  ///
  /// In ar, this message translates to:
  /// **'بداية كل دَرّ'**
  String get settingsNotifDar;

  /// وصف مفتاح بداية الدَّرّ (DESIGN settings.notif.dar_desc)
  ///
  /// In ar, this message translates to:
  /// **'تنبيه كل عشرة أيام تقريباً عند بداية دَرّ جديد.'**
  String get settingsNotifDarDesc;

  /// سطر ثابت تحت مفاتيح التنبيهات (DESIGN settings.notif.time_note). الأرقام تتبع إعداد «الأرقام»
  ///
  /// In ar, this message translates to:
  /// **'تصل التنبيهات الساعة ٨:٠٠ صباحاً بتوقيت جهازك.'**
  String get settingsNotifTimeNote;

  /// ملاحظة عند عدم منح إذن التنبيهات (DESIGN settings.notif.denied)
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات متوقفة من إعدادات جهازك.'**
  String get settingsNotifDenied;

  /// زر نصي يفتح إعدادات تنبيهات التطبيق في النظام (DESIGN settings.notif.open_device_settings)
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات الجهاز'**
  String get settingsNotifOpenDeviceSettings;

  /// فشل جدولة التنبيهات (DESIGN settings.notif.schedule_error)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر ضبط التنبيهات. أعد فتح التطبيق وحاول مرة أخرى.'**
  String get settingsNotifScheduleError;

  /// قسم في الإعدادات (DESIGN settings.section.appearance)
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsSectionAppearance;

  /// عنوان اختيار شكل الأرقام (DESIGN settings.digits)
  ///
  /// In ar, this message translates to:
  /// **'الأرقام'**
  String get settingsDigits;

  /// شريحة الأرقام العربية الهندية (DESIGN 8.7)
  ///
  /// In ar, this message translates to:
  /// **'١٢٣'**
  String get settingsDigitsArabic;

  /// شريحة الأرقام اللاتينية (DESIGN 8.7)
  ///
  /// In ar, this message translates to:
  /// **'123'**
  String get settingsDigitsLatin;

  /// عنوان تنبيه موسم مهم (DESIGN notif.season.title، SPEC 8 معيار 4). region = منطقة المستخدم
  ///
  /// In ar, this message translates to:
  /// **'دخل {season} اليوم في {region}'**
  String notifSeasonTitle(String season, String region);

  /// نص تنبيه موسم مهم (DESIGN notif.season.body)
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتعرف عن {season} ومثله الشعبي.'**
  String notifSeasonBody(String season);

  /// عنوان تنبيه سهيل والثريا بالتاريخ المحسوب لمدينة المستخدم (DESIGN notif.star.title). gender = جنس النجم من items.json: "f" مؤنث، وغيره مذكر (DESIGN §13 «جنس النجم»)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{طلعت {star} اليوم في {city}} other{طلع {star} اليوم في {city}}}'**
  String notifStarTitle(String gender, String star, String city);

  /// نص تنبيه سهيل والثريا (DESIGN notif.star.body). gender = جنس النجم من items.json: "f" مؤنث، وغيره مذكر (DESIGN §13 «جنس النجم»)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{أول ظهورها قبل الفجر. اضغط لتعرف عنها.} other{أول ظهوره قبل الفجر. اضغط لتعرف عنه.}}'**
  String notifStarBody(String gender);

  /// عنوان تنبيه بداية الدَّرّ (DESIGN notif.dar.title). season = مئة الدَّرّ (D25)
  ///
  /// In ar, this message translates to:
  /// **'بدأ دَرّ {dar} من {season}'**
  String notifDarTitle(String dar, String season);

  /// نص تنبيه بداية الدَّرّ (DESIGN notif.dar.body). weather = أسماء رموز الجو بالفاصلة
  ///
  /// In ar, this message translates to:
  /// **'الجو المعتاد: {weather}'**
  String notifDarBody(String weather);

  /// اسم قناة تنبيهات المواسم المهمة في إعدادات أندرويد (DESIGN notif.channel.important)
  ///
  /// In ar, this message translates to:
  /// **'المواسم المهمة'**
  String get notifChannelImportant;

  /// اسم قناة تنبيهات بداية الدَّرّ في إعدادات أندرويد (DESIGN notif.channel.dar)
  ///
  /// In ar, this message translates to:
  /// **'بداية كل دَرّ'**
  String get notifChannelDar;

  /// زر ثانوي أسفل صفحة النجم/الموسم/الدَّرّ يفتح ورقة البلاغ (DESIGN detail.report)
  ///
  /// In ar, this message translates to:
  /// **'أبلغ عن خطأ'**
  String get detailReport;

  /// صف في قسم البيانات والمساعدة يفتح ورقة بلاغ عام (DESIGN settings.report)
  ///
  /// In ar, this message translates to:
  /// **'أبلغ عن خطأ'**
  String get settingsReport;

  /// عنوان ورقة البلاغ وزر البلاغ في خطأ الحساب بالرئيسية (DESIGN report.title)
  ///
  /// In ar, this message translates to:
  /// **'أبلغ عن خطأ'**
  String get reportTitle;

  /// سطر الورقة حين يُعبأ النموذج مسبقاً (DESIGN report.intro_form)
  ///
  /// In ar, this message translates to:
  /// **'سنفتح لك النموذج وفيه هذه المعلومات. أكمل وصف الخطأ ثم اضغط إرسال بنفسك.'**
  String get reportIntroForm;

  /// سطر الورقة حين يُفتح النموذج بلا تعبئة مسبقة (قرار المالك النهائي، ليس في DESIGN بعد)
  ///
  /// In ar, this message translates to:
  /// **'سننسخ لك هذه المعلومات ونفتح النموذج. الصقها فيه وأكمل وصف الخطأ ثم اضغط إرسال بنفسك.'**
  String get reportIntroFormPaste;

  /// سطر الورقة حين لا يوجد نموذج مضبوط فيظهر «نسخ» فقط (ليس في DESIGN بعد)
  ///
  /// In ar, this message translates to:
  /// **'انسخ هذه المعلومات وأرفقها بوصف الخطأ في بلاغك.'**
  String get reportIntroCopy;

  /// سطر في ملخص البلاغ (DESIGN report.item)
  ///
  /// In ar, this message translates to:
  /// **'العنصر: {item}'**
  String reportItem(String item);

  /// سطر في ملخص البلاغ: منطقة الجدول (DESIGN report.region)
  ///
  /// In ar, this message translates to:
  /// **'المنطقة: {region}'**
  String reportRegion(String region);

  /// سطر في ملخص البلاغ (DESIGN report.date)
  ///
  /// In ar, this message translates to:
  /// **'التاريخ المعروض: {date}'**
  String reportDate(String date);

  /// سطر في ملخص البلاغ (DESIGN report.version)
  ///
  /// In ar, this message translates to:
  /// **'نسخة التطبيق: {version}'**
  String reportVersion(String version);

  /// سطر في ملخص البلاغ: dataVersion ثم dataSeq من meta.json (ليس في DESIGN بعد)
  ///
  /// In ar, this message translates to:
  /// **'نسخة البيانات: {version} ({seq})'**
  String reportDataVersion(String version, String seq);

  /// الزر الأساسي في ورقة البلاغ (DESIGN report.open_form)
  ///
  /// In ar, this message translates to:
  /// **'متابعة إلى النموذج'**
  String get reportOpenForm;

  /// سطر caption أسفل ورقة البلاغ (DESIGN report.nothing_sent)
  ///
  /// In ar, this message translates to:
  /// **'لن يُرسل شيء حتى تضغط إرسال بنفسك.'**
  String get reportNothingSent;

  /// زر ينسخ ملخص البلاغ نصاً (DESIGN report.copy_details)
  ///
  /// In ar, this message translates to:
  /// **'نسخ تفاصيل البلاغ'**
  String get reportCopyDetails;

  /// تأكيد بعد النسخ (ليس في DESIGN بعد؛ report.copied خاص بالعنوان)
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ تفاصيل البلاغ'**
  String get reportDetailsCopied;

  /// رسالة بعد فتح النموذج بلا تعبئة مسبقة (قرار المالك النهائي، ليس في DESIGN بعد)
  ///
  /// In ar, this message translates to:
  /// **'نسخنا تفاصيل البلاغ. الصقها في النموذج ثم أكمل وصف الخطأ.'**
  String get reportPasteHint;

  /// فشل فتح النموذج (لا متصفح) فتبقى نافذة النسخ (ليس في DESIGN بعد)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح النموذج. انسخ تفاصيل البلاغ وأرسلها لاحقاً.'**
  String get reportFormOpenError;

  /// فشل النسخ للحافظة: بزر «نسخ تفاصيل البلاغ»، أو قبل فتح النموذج بلا تعبئة مسبقة فلا يُفتح (ليس في DESIGN بعد)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر نسخ تفاصيل البلاغ. حاول مرة أخرى.'**
  String get reportCopyError;

  /// عنوان قسم تحديث البيانات بين «المظهر» و«البيانات والمساعدة» (DESIGN settings.section.update)
  ///
  /// In ar, this message translates to:
  /// **'تحديث البيانات'**
  String get settingsSectionUpdate;

  /// مفتاح التحقق التلقائي، مفعّل افتراضياً (DESIGN settings.update.auto)
  ///
  /// In ar, this message translates to:
  /// **'تحديث البيانات تلقائياً'**
  String get settingsUpdateAuto;

  /// وصف المفتاح (DESIGN settings.update.auto_desc)
  ///
  /// In ar, this message translates to:
  /// **'نتحقق مرة في الأسبوع عند فتح التطبيق، بلا أي معلومة عنك.'**
  String get settingsUpdateAutoDesc;

  /// سطر الحالة؛ مسافة غير قابلة للكسر قبل «—» (DESIGN settings.update.status)
  ///
  /// In ar, this message translates to:
  /// **'نسخة البيانات: {version} — آخر تحقق: {date}'**
  String settingsUpdateStatus(String version, String date);

  /// سطر الحالة قبل أول تحقق ناجح (DESIGN settings.update.status_never)
  ///
  /// In ar, this message translates to:
  /// **'نسخة البيانات: {version} — لم نتحقق بعد'**
  String settingsUpdateStatusNever(String version);

  /// {date} في سطر الحالة (DESIGN settings.update.date_today)
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get settingsUpdateDateToday;

  /// {date} في سطر الحالة (DESIGN settings.update.date_yesterday)
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get settingsUpdateDateYesterday;

  /// زر التحقق اليدوي (DESIGN settings.update.check_now)
  ///
  /// In ar, this message translates to:
  /// **'تحقق الآن'**
  String get settingsUpdateCheckNow;

  /// نص الزر أثناء التحقق (DESIGN settings.update.checking)
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق…'**
  String get settingsUpdateChecking;

  /// سطر النتيجة: لا جديد (DESIGN settings.update.up_to_date)
  ///
  /// In ar, this message translates to:
  /// **'بياناتك محدّثة.'**
  String get settingsUpdateUpToDate;

  /// سطر النتيجة: فشل الشبكة (DESIGN settings.update.network_error)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة أخرى.'**
  String get settingsUpdateNetworkError;

  /// سطر النتيجة: حزمة مرفوضة (DESIGN settings.update.verify_error)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من التحديث. بياناتك الحالية تعمل كما هي.'**
  String get settingsUpdateVerifyError;

  /// رسالة أسفل الشاشة عند قبول حزمة، على أي شاشة (DESIGN settings.update.updated)
  ///
  /// In ar, this message translates to:
  /// **'حُدّثت البيانات'**
  String get settingsUpdateUpdated;

  /// بطاقة نسخة البيانات: publishedAt من البيان الموقّع (DESIGN sources.data_updated)
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث للبيانات: {date}'**
  String sourcesDataUpdated(String date);

  /// بطاقة نسخة البيانات حين تكون المضمّنة (DESIGN sources.data_bundled)
  ///
  /// In ar, this message translates to:
  /// **'البيانات المرفقة مع نسخة التطبيق {appVersion}'**
  String sourcesDataBundled(String appVersion);

  /// السطر الثاني في بطاقة نسخة البيانات (DESIGN sources.data_version)
  ///
  /// In ar, this message translates to:
  /// **'نسخة البيانات: {version} ({seq})'**
  String sourcesDataVersion(String version, String seq);

  /// تبويب الرئيسية (DESIGN R2.9 tab.wheel)
  ///
  /// In ar, this message translates to:
  /// **'الدائرة'**
  String get tabWheel;

  /// تبويب دليل الرموز (DESIGN R2.9 tab.symbols)
  ///
  /// In ar, this message translates to:
  /// **'الرموز'**
  String get tabSymbols;

  /// تبويب التراث: أصل التقويم والمصادر (DESIGN R2.9 tab.heritage)
  ///
  /// In ar, this message translates to:
  /// **'التراث'**
  String get tabHeritage;

  /// تبويب الإعدادات (DESIGN R2.9 tab.settings)
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get tabSettings;

  /// كلمة الأيام بجانب الرقم الكبير في العدّاد؛ لـ 1 و2 تُعرض الكلمة وحدها بلا رقم (DESIGN R2.12 countdown.days)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{أيام} many{يوماً} other{يوم}}'**
  String countdownDaysUnit(int count);

  /// عدد الأيام بالرقم والكلمة لقارئ الشاشة (DESIGN R2.12 countdown.days)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} many{{days} يوماً} other{{days} يوم}}'**
  String countdownDaysPhrase(int count, String days);

  /// هدف العدّاد: موسم أو موسم جو (DESIGN R2.12 countdown.to_season)
  ///
  /// In ar, this message translates to:
  /// **'على دخول {name}'**
  String countdownToSeason(String name);

  /// هدف العدّاد: طالع أو نجم محسوب (DESIGN R2.12 countdown.to_star)
  ///
  /// In ar, this message translates to:
  /// **'على طلوع {name}'**
  String countdownToStar(String name);

  /// يوم البداية نفسه لموسم (DESIGN R2.12 countdown.season_today)
  ///
  /// In ar, this message translates to:
  /// **'دخل {name} اليوم'**
  String countdownSeasonToday(String name);

  /// يوم بداية طالع من الجدول، بجنس النجم (DESIGN R2.8، §13)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{طلعت {name} اليوم} other{طلع {name} اليوم}}'**
  String countdownStarToday(String gender, String name);

  /// يوم الطلوع المحسوب لسهيل/الثريا في مدينة المستخدم، بجنس النجم (DESIGN R2.8)
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, f{طلعت {name} اليوم في {city}} other{طلع {name} اليوم في {city}}}'**
  String countdownStarTodayIn(String gender, String name, String city);

  /// تحت العدّاد إن كان التاريخ المعروض غير اليوم (DESIGN R2.12 countdown.from_date)
  ///
  /// In ar, this message translates to:
  /// **'من {date}'**
  String countdownFromDate(String date);

  /// العدّاد لقارئ الشاشة: «باقي ٩ أيام على دخول الوسم، الجمعة ١٦ أكتوبر» (DESIGN R2.8)
  ///
  /// In ar, this message translates to:
  /// **'باقي {days} {target}، {date}'**
  String countdownA11y(String days, String target, String date);

  /// اسم اليوم ثم اليوم والشهر بلا سنة: «الجمعة ١٦ أكتوبر»
  ///
  /// In ar, this message translates to:
  /// **'{weekday} {date}'**
  String weekdayDayMonth(String weekday, String date);

  /// اليوم والشهر الميلادي بلا سنة: «١٦ أكتوبر». month بالصيغة g1..g12
  ///
  /// In ar, this message translates to:
  /// **'{day} {month, select, g1{يناير} g2{فبراير} g3{مارس} g4{أبريل} g5{مايو} g6{يونيو} g7{يوليو} g8{أغسطس} g9{سبتمبر} g10{أكتوبر} g11{نوفمبر} g12{ديسمبر} other{}}'**
  String dayMonthDate(String day, String month);

  /// عنوان بطاقة الطالع (DESIGN R2.12 card.star.title)
  ///
  /// In ar, this message translates to:
  /// **'الطالع'**
  String get cardStarTitle;

  /// سطر ثابت في بطاقة الجو المعتاد (DESIGN R2.12 card.weather.note)
  ///
  /// In ar, this message translates to:
  /// **'حسب التراث، وليس توقعاً للطقس.'**
  String get cardWeatherNote;

  /// عنوان بطاقة الزراعة (DESIGN R2.12 card.agri.title)
  ///
  /// In ar, this message translates to:
  /// **'مواسم الزراعة'**
  String get cardAgriTitle;

  /// عنوان بطاقة القادم (DESIGN R2.12 card.upcoming.title)
  ///
  /// In ar, this message translates to:
  /// **'القادم'**
  String get cardUpcomingTitle;

  /// متى يبدأ صف في بطاقة القادم (DESIGN R2.12 upcoming.after)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بعد يوم واحد} =2{بعد يومين} few{بعد {days} أيام} many{بعد {days} يوماً} other{بعد {days} يوم}}'**
  String upcomingAfter(int count, String days);

  /// سطر الموسم في بطاقة الطالع (DESIGN R2.12 home.season_label)
  ///
  /// In ar, this message translates to:
  /// **'الموسم: {season}'**
  String homeSeasonLabel(String season);

  /// عنوان شريط الدَّرّ: «دَرّ الستين» (DESIGN R2.8)
  ///
  /// In ar, this message translates to:
  /// **'دَرّ {dar}'**
  String darTitle(String dar);

  /// شريحة مئة الدَّرّ في شريطه (DESIGN R2.12 dar.of_season)
  ///
  /// In ar, this message translates to:
  /// **'من {season}'**
  String darOfSeason(String season);

  /// حالة بلا بيانات زراعية معتمدة، النص بالضبط (SPEC 15.5، DESIGN R2.7)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات زراعية موثقة لمنطقتك'**
  String get agriNoData;

  /// زر يفتح البلاغ معبأً باسم المنطقة (SPEC 15.5، DESIGN R2.7)
  ///
  /// In ar, this message translates to:
  /// **'أعرف مصدراً'**
  String get agriKnowSource;

  /// سطر الفترة في فقاعة رمز الجو (DESIGN R2.12 bubble.period)
  ///
  /// In ar, this message translates to:
  /// **'يتبع: {period}'**
  String bubblePeriod(String period);

  /// فترة الرمز: الاسم ثم المدى بلا سنة (DESIGN R2.6)
  ///
  /// In ar, this message translates to:
  /// **'{name} — {start} إلى {end}'**
  String bubbleRange(String name, String start, String end);

  /// عنوان صفحة دليل الرموز (DESIGN R2.12 symbols.title، SPEC 16.8)
  ///
  /// In ar, this message translates to:
  /// **'دليل الرموز'**
  String get symbolsTitle;

  /// إجراء مخصص للدائرة لقارئ الشاشة (DESIGN R2.12 wheel.a11y.read_symbols)
  ///
  /// In ar, this message translates to:
  /// **'اقرأ رموز الجو حول اليوم'**
  String get wheelA11yReadSymbols;

  /// سطر شرح رمز الجو في الفقاعة ودليل الرموز (DESIGN R2.6 weather.<code>.desc، SPEC 16.9). نص تراثي يراجعه المراجع
  ///
  /// In ar, this message translates to:
  /// **'{symbol, select, hot{حرّ معتاد في هذه الفترة حسب التراث.} very_hot{حرّ شديد، من أشد أيام السنة حرارة حسب التراث.} mild{جو معتدل، لا حرّ شديد ولا برد.} cool{برودة خفيفة، خاصة في الليل والصباح الباكر.} cold{برد معتاد في هذه الفترة حسب التراث.} very_cold{برد شديد، من أبرد أيام السنة حسب التراث.} wind{هبوب رياح معتاد في هذه الفترة حسب التراث.} wind_strong{رياح شديدة أو هبايب قد تثير الغبار.} rain{فترة يُرجى فيها المطر حسب التراث.} heavy_rain{فترة تُعرف بأمطار غزيرة حسب التراث.} thunder{فترة تكثر فيها السحب الرعدية والبرق.} cloud{سماء يكثر فيها الغيم.} dust{غبار معتاد في هذه الفترة حسب التراث.} humidity{رطوبة عالية، خاصة على السواحل.} fog{ضباب أو شبورة في الصباح الباكر.} sea_calm{بحر هادئ في الغالب حسب التراث.} sea_rough{بحر هائج وأمواج عالية في الغالب حسب التراث.} other{}}'**
  String weatherSymbolDesc(String symbol);

  /// اسم الفصل الفلكي (DESIGN R3.6 astro.season.*، D40)
  ///
  /// In ar, this message translates to:
  /// **'{season, select, spring{الربيع} summer{الصيف} autumn{الخريف} winter{الشتاء} other{}}'**
  String astroSeasonName(String season);

  /// حدث بداية الفصل (DESIGN R3.6 astro.event.*)
  ///
  /// In ar, this message translates to:
  /// **'{event, select, march_equinox{الاعتدال الربيعي} june_solstice{الانقلاب الصيفي} september_equinox{الاعتدال الخريفي} december_solstice{الانقلاب الشتوي} other{}}'**
  String astroEventName(String event);

  /// ورقة الفصل (R3.6 astro.season.starts)
  ///
  /// In ar, this message translates to:
  /// **'يبدأ: {datetime}'**
  String astroSeasonStarts(String datetime);

  /// ورقة الفصل (R3.6 astro.season.ends)
  ///
  /// In ar, this message translates to:
  /// **'ينتهي: {datetime}'**
  String astroSeasonEnds(String datetime);

  /// مدة الفصل بصيغ الجمع (R3.6 astro.season.length)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مدته يوم واحد} =2{مدته يومان} few{مدته {days} أيام} many{مدته {days} يوماً} other{مدته {days} يوم}}'**
  String astroSeasonLength(int count, String days);

  /// الجزء الأول من astroSeasonElapsed
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{مضى أقل من يوم} =1{مضى يوم واحد} =2{مضى يومان} few{مضى {days} أيام} many{مضى {days} يوماً} other{مضى {days} يوم}}'**
  String astroDaysElapsed(int count, String days);

  /// الجزء الثاني من astroSeasonElapsed
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بقي أقل من يوم} =1{بقي يوم واحد} =2{بقي يومان} few{بقي {days} أيام} many{بقي {days} يوماً} other{بقي {days} يوم}}'**
  String astroDaysRemaining(int count, String days);

  /// «مضى ١٤ يوماً — بقي ٧٥ يوماً» للفصل الحالي فقط (R3.6 astro.season.elapsed)
  ///
  /// In ar, this message translates to:
  /// **'{elapsed} — {remaining}'**
  String astroSeasonElapsed(String elapsed, String remaining);

  /// المقابل التراثي في ورقة الفصل (R3.6 astro.season.heritage)
  ///
  /// In ar, this message translates to:
  /// **'يقابله في التراث: {name} ({period})'**
  String astroSeasonHeritage(String name, String period);

  /// مدى تاريخين في أوراق الفصل والبرج
  ///
  /// In ar, this message translates to:
  /// **'من {start} إلى {end}'**
  String astroPeriodRange(String start, String end);

  /// سطر ثابت في ورقة الفصل (R3.6 astro.season.note)
  ///
  /// In ar, this message translates to:
  /// **'الفصول الفلكية تبدأ بالاعتدالين والانقلابين؛ والمواسم التراثية تبدأ بطلوع النجوم، فلا تتطابق بدايتها.'**
  String get astroSeasonNote;

  /// اسم الفصل مع الموسم التراثي المقابل لقارئ الشاشة (R3.2، R3.6 astro.season.a11y_heritage، SPEC 19.9)
  ///
  /// In ar, this message translates to:
  /// **'{season}، ويقابله في التراث {heritage}'**
  String astroSeasonA11yHeritage(String season, String heritage);

  /// جملة الفصل في قيمة الدائرة لقارئ الشاشة (R3.5، R3.6 astro.season.a11y_sentence)
  ///
  /// In ar, this message translates to:
  /// **'الفصل: {season}، من {start} إلى {end}.'**
  String astroSeasonA11ySentence(String season, String start, String end);

  /// بدل المصدر في أوراق الحساب الفلكي (R3.6 astro.computed)
  ///
  /// In ar, this message translates to:
  /// **'حساب فلكي'**
  String get astroComputed;

  /// تاريخ الفاصل المختصر على ذراع الصليب «٢١/١٢» (R3.2)
  ///
  /// In ar, this message translates to:
  /// **'{day}/{month}'**
  String astroDateShort(String day, String month);

  /// الساعة في ورقة الفصل «٣:٠٥ ص»
  ///
  /// In ar, this message translates to:
  /// **'{hour}:{minute} {period, select, am{ص} pm{م} other{}}'**
  String astroTime(String hour, String minute, String period);

  /// «الأربعاء ٢٣ سبتمبر ٢٠٢٦م، ٣:٠٥ ص» في ورقة الفصل
  ///
  /// In ar, this message translates to:
  /// **'{weekday} {date}، {time}'**
  String astroDateTime(String weekday, String date, String time);

  /// أسماء البروج العربية التقليدية (R3.1-10، R3.6 zodiac.*). بلا أي معنى تنجيمي؛ يراجع المراجع إملاءها
  ///
  /// In ar, this message translates to:
  /// **'{sign, select, aries{الحمل} taurus{الثور} gemini{الجوزاء} cancer{السرطان} leo{الأسد} virgo{السنبلة} libra{الميزان} scorpio{العقرب} sagittarius{القوس} capricorn{الجدي} aquarius{الدلو} pisces{الحوت} other{}}'**
  String zodiacName(String sign);

  /// عنوان ورقة البرج (R3.6 zodiac.sun_in)
  ///
  /// In ar, this message translates to:
  /// **'الشمس في برج {name}'**
  String zodiacSunIn(String name);

  /// سطر ثابت في ورقة البرج (R3.6 zodiac.note)
  ///
  /// In ar, this message translates to:
  /// **'موقع الشمس بين البروج، حساب فلكي.'**
  String get zodiacNote;

  /// إجراء مخصص للدائرة (R3.5، R3.6 wheel.a11y.read_season_zodiac)
  ///
  /// In ar, this message translates to:
  /// **'اقرأ الفصل والبرج'**
  String get wheelA11yReadSeasonZodiac;

  /// إجراء مخصص للدائرة (R3.5)
  ///
  /// In ar, this message translates to:
  /// **'افتح ورقة الفصل'**
  String get wheelA11yOpenSeasonSheet;

  /// إجراء مخصص في منطقة بلا درور (R3.10) بدل wheelA11yNextDar
  ///
  /// In ar, this message translates to:
  /// **'انتقل طالعاً للأمام'**
  String get wheelA11yNextStar;

  /// إجراء مخصص في منطقة بلا درور (R3.10) بدل wheelA11yPrevDar
  ///
  /// In ar, this message translates to:
  /// **'انتقل طالعاً للخلف'**
  String get wheelA11yPrevStar;

  /// تلميح الدائرة في منطقة بلا درور (R3.10)
  ///
  /// In ar, this message translates to:
  /// **'اسحب لأعلى أو لأسفل بإصبع واحد لتغيير اليوم. انقر مرتين لفتح صفحة الطالع.'**
  String get wheelA11yHintStar;

  /// زر القائمة في الصف العلوي (R3.6 header.menu)
  ///
  /// In ar, this message translates to:
  /// **'القائمة'**
  String get headerMenu;

  /// زر الجرس (R3.6 header.notifications)
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get headerNotifications;

  /// زر الجرس حين رفض النظام الإذن (R3.6 header.notifications_denied)
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات، الإذن مرفوض'**
  String get headerNotificationsDenied;

  /// الفاصل بين المكان والتاريخ تحت العنوان (R3.1-1)
  ///
  /// In ar, this message translates to:
  /// **' — '**
  String get headerSeparator;

  /// العنوان الفرعي لبطاقة الطالع (R3.6 card.star.subtitle)
  ///
  /// In ar, this message translates to:
  /// **'نجم الموسم الآن'**
  String get cardStarSubtitle;

  /// العنوان الفرعي لبطاقة القادم (R3.6 card.upcoming.subtitle)
  ///
  /// In ar, this message translates to:
  /// **'الدرور والمواسم والطوالع'**
  String get cardUpcomingSubtitle;

  /// بطاقة الطقس الفعلي (R3.8، D42)
  ///
  /// In ar, this message translates to:
  /// **'الطقس'**
  String get cardLiveWeatherTitle;

  /// العنوان الفرعي لبطاقة الطقس الفعلي (R3.8)
  ///
  /// In ar, this message translates to:
  /// **'الآن والأيام القادمة'**
  String get cardLiveWeatherSubtitle;

  /// حالة بطاقة الطقس الفعلي قبل تنفيذ الجلب (الجزء ب)
  ///
  /// In ar, this message translates to:
  /// **'غير متاح بعد'**
  String get cardLiveWeatherUnavailable;

  /// عنوان صف/بطاقة الجو المعتاد (R3.1-18، R3.10)
  ///
  /// In ar, this message translates to:
  /// **'الجو المعتاد حسب التراث'**
  String get usualWeatherHeritageTitle;
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
