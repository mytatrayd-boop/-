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

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'رحلة'**
  String get appName;

  /// No description provided for @homeTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get homeTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @settingsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات قيد البناء.'**
  String get settingsEmpty;

  /// No description provided for @openSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get openSettings;

  /// No description provided for @backToHome.
  ///
  /// In ar, this message translates to:
  /// **'رجوع إلى الرئيسية'**
  String get backToHome;

  /// No description provided for @notFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصفحة غير موجودة'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد هذه الصفحة. ارجع إلى الشاشة الرئيسية وأعد المحاولة.'**
  String get notFoundBody;

  /// No description provided for @permTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأذونات'**
  String get permTitle;

  /// No description provided for @permStepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {n} من {total}'**
  String permStepOf(int n, int total);

  /// No description provided for @permCameraTitle.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get permCameraTitle;

  /// No description provided for @permCameraReason.
  ///
  /// In ar, this message translates to:
  /// **'لتصوير طريقك.'**
  String get permCameraReason;

  /// No description provided for @permLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get permLocationTitle;

  /// No description provided for @permLocationReason.
  ///
  /// In ar, this message translates to:
  /// **'لرسم مسارك على الخريطة وحسابه.'**
  String get permLocationReason;

  /// No description provided for @permMicTitle.
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون'**
  String get permMicTitle;

  /// No description provided for @permMicReason.
  ///
  /// In ar, this message translates to:
  /// **'لتسجيل صوت الرحلة (اختياري ويمكنك كتمه).'**
  String get permMicReason;

  /// No description provided for @permPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'كل شيء يبقى على جوالك. لا حسابات ولا رفع.'**
  String get permPrivacy;

  /// No description provided for @permAllow.
  ///
  /// In ar, this message translates to:
  /// **'السماح'**
  String get permAllow;

  /// No description provided for @permNotNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get permNotNow;

  /// No description provided for @permGranted.
  ///
  /// In ar, this message translates to:
  /// **'تم السماح'**
  String get permGranted;

  /// No description provided for @permCameraDenied.
  ///
  /// In ar, this message translates to:
  /// **'لن تعمل الرحلة بدون الكاميرا.'**
  String get permCameraDenied;

  /// No description provided for @permLocationDenied.
  ///
  /// In ar, this message translates to:
  /// **'لن يُرسم المسار بدون الموقع، ولن تعمل الرحلة.'**
  String get permLocationDenied;

  /// No description provided for @permMicDenied.
  ///
  /// In ar, this message translates to:
  /// **'سيُسجَّل الفيديو بلا صوت.'**
  String get permMicDenied;

  /// No description provided for @permPermanentHint.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن طلب الإذن من التطبيق مرة أخرى. فعّله من إعدادات الجوال.'**
  String get permPermanentHint;

  /// No description provided for @permLocationApproximate.
  ///
  /// In ar, this message translates to:
  /// **'الموقع التقريبي لا يكفي. المسار يحتاج الدقة الكاملة؛ فعّل الموقع الدقيق من إعدادات الجوال.'**
  String get permLocationApproximate;

  /// No description provided for @permOpenPhoneSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات الجوال'**
  String get permOpenPhoneSettings;

  /// No description provided for @permRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get permRetry;

  /// No description provided for @permContinueNoAudio.
  ///
  /// In ar, this message translates to:
  /// **'متابعة بلا صوت'**
  String get permContinueNoAudio;

  /// No description provided for @permAudioUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الصوت غير متاح'**
  String get permAudioUnavailable;

  /// No description provided for @permStartBlocked.
  ///
  /// In ar, this message translates to:
  /// **'امنح الكاميرا والموقع لبدء الرحلة.'**
  String get permStartBlocked;

  /// No description provided for @permIllustration.
  ///
  /// In ar, this message translates to:
  /// **'رسم توضيحي لإذن {name}'**
  String permIllustration(String name);

  /// No description provided for @mapLocating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد موقعك...'**
  String get mapLocating;

  /// No description provided for @mapRecenter.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التمركز'**
  String get mapRecenter;

  /// No description provided for @startTrip.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startTrip;

  /// No description provided for @stopTrip.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الرحلة'**
  String get stopTrip;

  /// No description provided for @mute.
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get unmute;

  /// No description provided for @audioOn.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مفعّل'**
  String get audioOn;

  /// No description provided for @audioMuted.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مكتوم'**
  String get audioMuted;

  /// No description provided for @audioMutedChip.
  ///
  /// In ar, this message translates to:
  /// **'مكتوم'**
  String get audioMutedChip;

  /// No description provided for @qualityTitle.
  ///
  /// In ar, this message translates to:
  /// **'جودة الفيديو'**
  String get qualityTitle;

  /// No description provided for @gpsGood.
  ///
  /// In ar, this message translates to:
  /// **'GPS جيد'**
  String get gpsGood;

  /// No description provided for @gpsWeak.
  ///
  /// In ar, this message translates to:
  /// **'إشارة GPS ضعيفة'**
  String get gpsWeak;

  /// No description provided for @gpsSearching.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد الموقع'**
  String get gpsSearching;

  /// No description provided for @offlineBanner.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد إنترنت: الخريطة لن تتحدث'**
  String get offlineBanner;

  /// No description provided for @cameraOpening.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا قيد التجهيز...'**
  String get cameraOpening;

  /// No description provided for @cameraError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الكاميرا. أغلق التطبيقات الأخرى المستخدمة لها.'**
  String get cameraError;

  /// No description provided for @homeOpenPermissions.
  ///
  /// In ar, this message translates to:
  /// **'فتح الأذونات'**
  String get homeOpenPermissions;

  /// No description provided for @hudDistanceKm.
  ///
  /// In ar, this message translates to:
  /// **'{km} كم'**
  String hudDistanceKm(String km);
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
