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

  /// No description provided for @favoriteAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى المفضلة'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المفضلة'**
  String get favoriteRemove;

  /// No description provided for @favoriteAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف للمفضلة'**
  String get favoriteAdded;

  /// No description provided for @favoriteRemoved.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من المفضلة'**
  String get favoriteRemoved;

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @favoriteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديث المفضلة'**
  String get favoriteFailed;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم تحفظ شيئاً بعد. اضغط النجمة في أي نتيجة'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المفضلة'**
  String get favoritesErrorTitle;

  /// No description provided for @favoritesLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل المفضلة'**
  String get favoritesLoading;

  /// No description provided for @cafeSave.
  ///
  /// In ar, this message translates to:
  /// **'احفظ مكان المقهى'**
  String get cafeSave;

  /// No description provided for @cafeLocating.
  ///
  /// In ar, this message translates to:
  /// **'نحدد موقعك…'**
  String get cafeLocating;

  /// No description provided for @cafeLocationFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع'**
  String get cafeLocationFailedTitle;

  /// No description provided for @cafeLocDenied.
  ///
  /// In ar, this message translates to:
  /// **'لم نحصل على إذن الموقع. يمكنك حفظ اسم المقهى فقط بلا رابط خرائط.'**
  String get cafeLocDenied;

  /// No description provided for @cafeLocDeniedForever.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع مرفوض. فعّله من إعدادات الجوال، أو احفظ الاسم فقط بلا رابط خرائط.'**
  String get cafeLocDeniedForever;

  /// No description provided for @cafeLocServiceOff.
  ///
  /// In ar, this message translates to:
  /// **'خدمة الموقع مغلقة في الجوال. شغّلها، أو احفظ الاسم فقط بلا رابط خرائط.'**
  String get cafeLocServiceOff;

  /// No description provided for @cafeLocTimeout.
  ///
  /// In ar, this message translates to:
  /// **'استغرق تحديد الموقع وقتاً طويلاً. حاول لاحقاً، أو احفظ الاسم فقط بلا رابط خرائط.'**
  String get cafeLocTimeout;

  /// No description provided for @cafeLocError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع. يمكنك حفظ الاسم فقط بلا رابط خرائط.'**
  String get cafeLocError;

  /// No description provided for @cafeSaveNameOnly.
  ///
  /// In ar, this message translates to:
  /// **'احفظ الاسم فقط'**
  String get cafeSaveNameOnly;

  /// No description provided for @cafeNameTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم المقهى'**
  String get cafeNameTitle;

  /// No description provided for @cafeNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المقهى'**
  String get cafeNameLabel;

  /// No description provided for @cafeNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المقهى'**
  String get cafeNameRequired;

  /// No description provided for @cafeSaveAction.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get cafeSaveAction;

  /// No description provided for @cafeSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ المقهى'**
  String get cafeSaved;

  /// No description provided for @cafeSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ المقهى'**
  String get cafeSaveFailed;

  /// No description provided for @cafeOpenInMaps.
  ///
  /// In ar, this message translates to:
  /// **'افتح في خرائط قوقل'**
  String get cafeOpenInMaps;

  /// No description provided for @cafeOpenFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الخرائط'**
  String get cafeOpenFailed;

  /// No description provided for @cafesTitle.
  ///
  /// In ar, this message translates to:
  /// **'مقاهيّ المحفوظة'**
  String get cafesTitle;

  /// No description provided for @cafesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم تحدد مقهى بعد'**
  String get cafesEmptyTitle;

  /// No description provided for @cafesEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'افتح تفاصيل أي فحص واضغط «احفظ مكان المقهى» وأنت في المقهى.'**
  String get cafesEmptyBody;

  /// No description provided for @cafesErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المقاهي'**
  String get cafesErrorTitle;

  /// No description provided for @cafesLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل المقاهي'**
  String get cafesLoading;

  /// No description provided for @cafeScanCount.
  ///
  /// In ar, this message translates to:
  /// **'الفحوصات: {count}'**
  String cafeScanCount(int count);

  /// No description provided for @cafeLastScore.
  ///
  /// In ar, this message translates to:
  /// **'آخر درجة: {score}/100'**
  String cafeLastScore(int score);

  /// No description provided for @cafeNoLocation.
  ///
  /// In ar, this message translates to:
  /// **'بلا موقع'**
  String get cafeNoLocation;

  /// No description provided for @cafeMenu.
  ///
  /// In ar, this message translates to:
  /// **'خيارات المقهى'**
  String get cafeMenu;

  /// No description provided for @cafeEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاسم'**
  String get cafeEdit;

  /// No description provided for @cafeEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل اسم المقهى'**
  String get cafeEditTitle;

  /// No description provided for @cafeDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف المقهى'**
  String get cafeDelete;

  /// No description provided for @cafeDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا المقهى؟'**
  String get cafeDeleteTitle;

  /// No description provided for @cafeDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'تبقى فحوصاتك ويُزال اسم المقهى منها. لا يمكن التراجع.'**
  String get cafeDeleteBody;

  /// No description provided for @cafeDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف المقهى'**
  String get cafeDeleted;

  /// No description provided for @cafeDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف المقهى'**
  String get cafeDeleteFailed;

  /// No description provided for @cafeRenameFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تعديل الاسم'**
  String get cafeRenameFailed;

  /// No description provided for @scanCafe.
  ///
  /// In ar, this message translates to:
  /// **'المقهى'**
  String get scanCafe;

  /// No description provided for @settingsCafesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أماكن المقاهي التي حفظتها'**
  String get settingsCafesSubtitle;

  /// No description provided for @shareAction.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get shareAction;

  /// No description provided for @shareGenerating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تجهيز الصورة…'**
  String get shareGenerating;

  /// No description provided for @shareFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز الصورة، حاول مجدداً'**
  String get shareFailed;

  /// No description provided for @shareImageMissing.
  ///
  /// In ar, this message translates to:
  /// **'صورة الفحص مفقودة، لا يمكن مشاركته'**
  String get shareImageMissing;

  /// No description provided for @shareNameDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمك للتوقيع'**
  String get shareNameDialogTitle;

  /// No description provided for @shareNameDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'يظهر اسمك بخط اليد تحت اللوقو في صورة المشاركة.'**
  String get shareNameDialogBody;

  /// No description provided for @shareNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get shareNameLabel;

  /// No description provided for @shareNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمك أولاً'**
  String get shareNameRequired;

  /// No description provided for @shareNameSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get shareNameSave;

  /// No description provided for @settingsUserNameTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم التوقيع'**
  String get settingsUserNameTitle;

  /// No description provided for @settingsUserNameEmpty.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمك ليوقّع صور المشاركة'**
  String get settingsUserNameEmpty;

  /// No description provided for @shareScoreOutOf.
  ///
  /// In ar, this message translates to:
  /// **'من 100'**
  String get shareScoreOutOf;

  /// No description provided for @scoreLabelExcellent.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز'**
  String get scoreLabelExcellent;

  /// No description provided for @scoreLabelGood.
  ///
  /// In ar, this message translates to:
  /// **'جيد'**
  String get scoreLabelGood;

  /// No description provided for @scoreLabelAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get scoreLabelAverage;

  /// No description provided for @scoreLabelWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيف'**
  String get scoreLabelWeak;

  /// No description provided for @shareCardTypeLine.
  ///
  /// In ar, this message translates to:
  /// **'{type} · محمصة {roaster}'**
  String shareCardTypeLine(String type, String roaster);

  /// No description provided for @shareTextRated.
  ///
  /// In ar, this message translates to:
  /// **'قيّمت {subject} بعدسة البن: {score}/100 (تقديري)'**
  String shareTextRated(String subject, int score);

  /// No description provided for @shareTextCafe.
  ///
  /// In ar, this message translates to:
  /// **'المقهى: {cafe}'**
  String shareTextCafe(String cafe);

  /// No description provided for @shareSubjectRoaster.
  ///
  /// In ar, this message translates to:
  /// **'المحمصة {name}'**
  String shareSubjectRoaster(String name);

  /// No description provided for @shareSubjectCafe.
  ///
  /// In ar, this message translates to:
  /// **'المقهى {name}'**
  String shareSubjectCafe(String name);

  /// No description provided for @shareSubjectType.
  ///
  /// In ar, this message translates to:
  /// **'{type}'**
  String shareSubjectType(String type);
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
