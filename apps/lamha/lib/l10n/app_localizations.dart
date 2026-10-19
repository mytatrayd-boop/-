import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// اسم التطبيق
  ///
  /// In ar, this message translates to:
  /// **'لمحة'**
  String get appTitle;

  /// خطأ عند فشل تحميل البيانات
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الإعدادات'**
  String get loadError;

  /// عنوان شريط الشفافية (SPEC ٢)
  ///
  /// In ar, this message translates to:
  /// **'الشفافية'**
  String get opacityLabel;

  /// نسبة مئوية؛ value رقم منسق مسبقاً
  ///
  /// In ar, this message translates to:
  /// **'{value}٪'**
  String percent(String value);

  /// زر اختيار لقطة خلفية الشاشة (آيفون فقط)
  ///
  /// In ar, this message translates to:
  /// **'لقطة الخلفية'**
  String get backgroundButton;

  /// تأكيد حفظ اللقطة
  ///
  /// In ar, this message translates to:
  /// **'حُفظت لقطة الخلفية'**
  String get backgroundSaved;

  /// عنوان اختيار المدينة
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get cityLabel;

  /// زر تحديد المدينة من الموقع
  ///
  /// In ar, this message translates to:
  /// **'موقعي'**
  String get myLocation;

  /// رفض إذن الموقع
  ///
  /// In ar, this message translates to:
  /// **'لم يُسمح بالوصول إلى الموقع. اختر المدينة من القائمة.'**
  String get locationDenied;

  /// فشل قراءة الموقع
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع. اختر المدينة من القائمة.'**
  String get locationFailed;

  /// عنوان قائمة طرق الحساب
  ///
  /// In ar, this message translates to:
  /// **'طريقة حساب الصلاة'**
  String get prayerMethodLabel;

  /// اسم طريقة الحساب بمعرّفها
  ///
  /// In ar, this message translates to:
  /// **'{method, select, ummAlQura{أم القرى} muslimWorldLeague{رابطة العالم الإسلامي} egyptian{الهيئة المصرية العامة للمساحة} karachi{جامعة العلوم الإسلامية بكراتشي} dubai{دبي} kuwait{الكويت} qatar{قطر} gulfRegion{منطقة الخليج} northAmerica{أمريكا الشمالية} turkiye{تركيا} other{{method}}}'**
  String prayerMethodName(String method);

  /// عنوان قسم المفاتيح (SPEC ٤ب)
  ///
  /// In ar, this message translates to:
  /// **'ما يظهر على الودجت'**
  String get visibleSection;

  /// اسم عنصر الودجت بمعرّفه
  ///
  /// In ar, this message translates to:
  /// **'{element, select, hijri{التاريخ الهجري} gregorian{التاريخ الميلادي} weather{الطقس} prayer{الصلاة} qibla{القبلة} deposit{الإيداع} season{الفصل} tradSeason{الموسم} other{{element}}}'**
  String elementName(String element);

  /// عند محاولة إلغاء آخر إيداع
  ///
  /// In ar, this message translates to:
  /// **'يلزم إيداع واحد على الأقل. لإخفاء المربع أطفئ «الإيداع».'**
  String get lastDepositMessage;

  /// عنوان مربع الصلاة
  ///
  /// In ar, this message translates to:
  /// **'الصلاة القادمة'**
  String get tilePrayer;

  /// عنوان مربع القبلة
  ///
  /// In ar, this message translates to:
  /// **'القبلة'**
  String get tileQibla;

  /// عنوان مربع الإيداع
  ///
  /// In ar, this message translates to:
  /// **'الإيداع القادم'**
  String get tileDeposit;

  /// عنوان مربع الفصل الفلكي
  ///
  /// In ar, this message translates to:
  /// **'الفصل'**
  String get tileSeason;

  /// عنوان مربع الموسم التراثي
  ///
  /// In ar, this message translates to:
  /// **'الموسم'**
  String get tileTradSeason;

  /// التاريخ الهجري في المعاينة
  ///
  /// In ar, this message translates to:
  /// **'{date} هـ'**
  String hijriDateText(String date);

  /// التاريخ الميلادي في المعاينة
  ///
  /// In ar, this message translates to:
  /// **'{date} م'**
  String gregorianDateText(String date);

  /// سطر المدينة والطقس في المعاينة؛ الطقس الفعلي تجلبه الودجت الأصلية
  ///
  /// In ar, this message translates to:
  /// **'📍 {city} · ⛅ ‎--°'**
  String cityWeather(String city);

  /// مثل: باقي ٣٤ يوماً للشتاء؛ next مسبوق باللام
  ///
  /// In ar, this message translates to:
  /// **'{remaining} {next}'**
  String remainingToNext(String remaining, String next);

  /// زاوية بالدرجات
  ///
  /// In ar, this message translates to:
  /// **'{value}°'**
  String degrees(String value);

  /// إشارة رخص البيانات والخط
  ///
  /// In ar, this message translates to:
  /// **'إحداثيات المدن من GeoNames (geonames.org) برخصة CC BY 4.0. الخط Tajawal برخصة SIL OFL 1.1.'**
  String get dataLicense;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
