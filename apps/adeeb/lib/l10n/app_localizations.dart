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

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأديب الذكي'**
  String get appTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة'**
  String get libraryTitle;

  /// No description provided for @download.
  ///
  /// In ar, this message translates to:
  /// **'تحميل'**
  String get download;

  /// No description provided for @downloadingPercent.
  ///
  /// In ar, this message translates to:
  /// **'يُحمَّل… {percent}٪'**
  String downloadingPercent(String percent);

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @redownload.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التحميل'**
  String get redownload;

  /// No description provided for @open.
  ///
  /// In ar, this message translates to:
  /// **'افتح'**
  String get open;

  /// No description provided for @installed.
  ///
  /// In ar, this message translates to:
  /// **'محمّل'**
  String get installed;

  /// No description provided for @notInstalled.
  ///
  /// In ar, this message translates to:
  /// **'غير محمّل'**
  String get notInstalled;

  /// No description provided for @updateAvailable.
  ///
  /// In ar, this message translates to:
  /// **'تحديث متاح'**
  String get updateAvailable;

  /// No description provided for @update.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get update;

  /// No description provided for @preparing.
  ///
  /// In ar, this message translates to:
  /// **'يُجهَّز للبحث…'**
  String get preparing;

  /// No description provided for @downloadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل'**
  String get downloadFailed;

  /// No description provided for @downloadInterrupted.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال أثناء التحميل'**
  String get downloadInterrupted;

  /// No description provided for @fileCorrupt.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير سليم. أعد تحميله.'**
  String get fileCorrupt;

  /// No description provided for @needsConnection.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج اتصالاً'**
  String get needsConnection;

  /// No description provided for @offlineBanner.
  ///
  /// In ar, this message translates to:
  /// **'أنت دون إنترنت — الكتب المحمّلة متاحة'**
  String get offlineBanner;

  /// No description provided for @staleCatalogBanner.
  ///
  /// In ar, this message translates to:
  /// **'قد لا تكون القائمة محدّثة'**
  String get staleCatalogBanner;

  /// No description provided for @updateAppBanner.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الكتب بصيغة أحدث من هذا الإصدار. حدّث التطبيق لرؤية الكتب الجديدة.'**
  String get updateAppBanner;

  /// No description provided for @offlineFirstRunTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج اتصالاً لتحميل الكتب'**
  String get offlineFirstRunTitle;

  /// No description provided for @offlineFirstRunBody.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بالإنترنت مرة واحدة لتحميل قائمة الكتب، وبعدها تقرأ وتبحث وتستمع دون اتصال.'**
  String get offlineFirstRunBody;

  /// No description provided for @catalogError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل قائمة الكتب. تحقّق من الاتصال وحاول مجدداً.'**
  String get catalogError;

  /// No description provided for @emptyLibrary.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كتب متاحة بعد.'**
  String get emptyLibrary;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل'**
  String get loading;

  /// No description provided for @deleteFromDevice.
  ///
  /// In ar, this message translates to:
  /// **'حذف من الجهاز'**
  String get deleteFromDevice;

  /// No description provided for @deleteDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الكتاب من الجهاز؟'**
  String get deleteDialogTitle;

  /// No description provided for @deleteDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف «{title}» من جهازك ويتحرّر {size}. تبقى المفضلة وآخر موضع، ويمكنك تحميله مجدداً في أي وقت.'**
  String deleteDialogBody(String title, String size);

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @bookDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الكتاب'**
  String get bookDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف الكتاب'**
  String get deleteFailed;

  /// No description provided for @bookUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّث الكتاب'**
  String get bookUpdated;

  /// No description provided for @sizeMb.
  ///
  /// In ar, this message translates to:
  /// **'{size} م.ب'**
  String sizeMb(String size);

  /// No description provided for @sizeKb.
  ///
  /// In ar, this message translates to:
  /// **'{size} ك.ب'**
  String sizeKb(String size);

  /// No description provided for @sizeMbSpoken.
  ///
  /// In ar, this message translates to:
  /// **'{size} ميغابايت'**
  String sizeMbSpoken(String size);

  /// No description provided for @sizeKbSpoken.
  ///
  /// In ar, this message translates to:
  /// **'{size} كيلوبايت'**
  String sizeKbSpoken(String size);

  /// No description provided for @deathHijri.
  ///
  /// In ar, this message translates to:
  /// **'ت {year}هـ'**
  String deathHijri(String year);

  /// No description provided for @deathHijriSpoken.
  ///
  /// In ar, this message translates to:
  /// **'متوفى {year} للهجرة'**
  String deathHijriSpoken(String year);

  /// No description provided for @authorWithDeath.
  ///
  /// In ar, this message translates to:
  /// **'{author} ({death})'**
  String authorWithDeath(String author, String death);

  /// No description provided for @bookCardSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{title}، {author}، {details}'**
  String bookCardSemantics(String title, String author, String details);

  /// No description provided for @moreOptions.
  ///
  /// In ar, this message translates to:
  /// **'خيارات أخرى'**
  String get moreOptions;

  /// No description provided for @sourceLine.
  ///
  /// In ar, this message translates to:
  /// **'المصدر: {source} — {license}'**
  String sourceLine(String source, String license);

  /// No description provided for @licensePublicDomain.
  ///
  /// In ar, this message translates to:
  /// **'ملك عام'**
  String get licensePublicDomain;

  /// No description provided for @downloadBook.
  ///
  /// In ar, this message translates to:
  /// **'تحميل الكتاب ({size})'**
  String downloadBook(String size);

  /// No description provided for @chapters.
  ///
  /// In ar, this message translates to:
  /// **'الأبواب'**
  String get chapters;

  /// No description provided for @downloadToSeeChapters.
  ///
  /// In ar, this message translates to:
  /// **'حمّل الكتاب لعرض أبوابه'**
  String get downloadToSeeChapters;

  /// No description provided for @bookOpenError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الكتاب. أعد تحميله.'**
  String get bookOpenError;

  /// No description provided for @chapterSemantics.
  ///
  /// In ar, this message translates to:
  /// **'الباب {number} من {total}: {title}'**
  String chapterSemantics(String number, String total, String title);

  /// No description provided for @bookNotFound.
  ///
  /// In ar, this message translates to:
  /// **'هذا الكتاب غير موجود في المكتبة.'**
  String get bookNotFound;

  /// No description provided for @downloading.
  ///
  /// In ar, this message translates to:
  /// **'يُحمَّل…'**
  String get downloading;

  /// No description provided for @listSeparator.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get listSeparator;

  /// No description provided for @downloadAnnouncement.
  ///
  /// In ar, this message translates to:
  /// **'«{title}»: يُحمَّل… {percent}٪'**
  String downloadAnnouncement(String title, String percent);
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
