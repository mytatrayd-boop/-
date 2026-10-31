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
/// import 'gen/app_localizations.dart';
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

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'عدسة البن'**
  String get appName;

  /// No description provided for @tabScan.
  ///
  /// In ar, this message translates to:
  /// **'فحص'**
  String get tabScan;

  /// No description provided for @tabHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get tabHistory;

  /// No description provided for @tabFavorites.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get tabFavorites;

  /// No description provided for @tabSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get tabSettings;

  /// No description provided for @scanTitle.
  ///
  /// In ar, this message translates to:
  /// **'فحص'**
  String get scanTitle;

  /// No description provided for @historyTitle.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get historyTitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get favoritesTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @logoLabel.
  ///
  /// In ar, this message translates to:
  /// **'شعار عدسة البن'**
  String get logoLabel;

  /// No description provided for @placeholderSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get placeholderSoon;

  /// No description provided for @historyFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get historyFilterAll;

  /// No description provided for @historyFilterBean.
  ///
  /// In ar, this message translates to:
  /// **'بن'**
  String get historyFilterBean;

  /// No description provided for @historyFilterCoffee.
  ///
  /// In ar, this message translates to:
  /// **'قهوة'**
  String get historyFilterCoffee;

  /// No description provided for @scanTypeBean.
  ///
  /// In ar, this message translates to:
  /// **'بن'**
  String get scanTypeBean;

  /// No description provided for @scanTypeCoffee.
  ///
  /// In ar, this message translates to:
  /// **'قهوة'**
  String get scanTypeCoffee;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا فحوصات بعد'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyAction.
  ///
  /// In ar, this message translates to:
  /// **'افحص الآن'**
  String get historyEmptyAction;

  /// No description provided for @historyErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل السجل'**
  String get historyErrorTitle;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'أعد المحاولة'**
  String get retry;

  /// No description provided for @historyLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل السجل'**
  String get historyLoading;

  /// No description provided for @scoreOutOf.
  ///
  /// In ar, this message translates to:
  /// **'{score}/100'**
  String scoreOutOf(int score);

  /// No description provided for @scanCardLabel.
  ///
  /// In ar, this message translates to:
  /// **'فحص {type}، الدرجة {score} من 100'**
  String scanCardLabel(String type, int score);

  /// No description provided for @scanMenu.
  ///
  /// In ar, this message translates to:
  /// **'خيارات الفحص'**
  String get scanMenu;

  /// No description provided for @scanDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get scanDelete;

  /// No description provided for @deleteScanTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا الفحص؟'**
  String get deleteScanTitle;

  /// No description provided for @deleteScanBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن التراجع.'**
  String get deleteScanBody;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @scanDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الفحص'**
  String get scanDeleted;

  /// No description provided for @scanDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف الفحص'**
  String get scanDeleteFailed;

  /// No description provided for @scanDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الفحص'**
  String get scanDetailTitle;

  /// No description provided for @scanNotFound.
  ///
  /// In ar, this message translates to:
  /// **'هذا الفحص غير موجود'**
  String get scanNotFound;

  /// No description provided for @scanNotesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظات'**
  String get scanNotesTitle;

  /// No description provided for @scanDisclaimer.
  ///
  /// In ar, this message translates to:
  /// **'التقدير بصري تقريبي وليس حكماً نهائياً'**
  String get scanDisclaimer;

  /// No description provided for @scanRoaster.
  ///
  /// In ar, this message translates to:
  /// **'المحمصة'**
  String get scanRoaster;

  /// No description provided for @scanPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get scanPrice;

  /// No description provided for @scanDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get scanDate;

  /// No description provided for @scanImageUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الصورة غير متاحة'**
  String get scanImageUnavailable;

  /// No description provided for @scanTypeField.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get scanTypeField;
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
