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

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'BGTube'**
  String get appTitle;

  /// No description provided for @emptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط يوتيوب لتشغيله'**
  String get emptyTitle;

  /// No description provided for @linkHint.
  ///
  /// In ar, this message translates to:
  /// **'رابط يوتيوب'**
  String get linkHint;

  /// No description provided for @pasteAndPlay.
  ///
  /// In ar, this message translates to:
  /// **'لصق وتشغيل'**
  String get pasteAndPlay;

  /// No description provided for @play.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get stop;

  /// No description provided for @speed.
  ///
  /// In ar, this message translates to:
  /// **'سرعة التشغيل'**
  String get speed;

  /// No description provided for @sleepTimer.
  ///
  /// In ar, this message translates to:
  /// **'مؤقت النوم'**
  String get sleepTimer;

  /// No description provided for @sleepMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{minutes} دقيقة'**
  String sleepMinutes(String minutes);

  /// No description provided for @sleepCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المؤقت'**
  String get sleepCancel;

  /// No description provided for @speedValue.
  ///
  /// In ar, this message translates to:
  /// **'{value}×'**
  String speedValue(String value);

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @resolving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحضير…'**
  String get resolving;

  /// No description provided for @clipboardEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رابط يوتيوب في الحافظة'**
  String get clipboardEmpty;

  /// No description provided for @errorInvalidLink.
  ///
  /// In ar, this message translates to:
  /// **'الرابط غير صالح. تأكد أنه رابط فيديو من يوتيوب.'**
  String get errorInvalidLink;

  /// No description provided for @errorPlaylistNotSupported.
  ///
  /// In ar, this message translates to:
  /// **'روابط القوائم غير مدعومة بعد. الصق رابط فيديو واحد.'**
  String get errorPlaylistNotSupported;

  /// No description provided for @errorExtraction.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر استخراج الصوت من هذا الفيديو. جرّب مرة أخرى.'**
  String get errorExtraction;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالإنترنت. تحقق من الشبكة وأعد المحاولة.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'يوتيوب يقيّد الطلبات من شبكتك الآن. انتظر قليلاً ثم أعد المحاولة.'**
  String get errorRateLimited;

  /// No description provided for @errorPlayback.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الصوت. أعد المحاولة.'**
  String get errorPlayback;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In ar, this message translates to:
  /// **'تُطبَّق فوراً وتبقى محفوظة.'**
  String get settingsLanguageHint;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsPersonalUse.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق للاستخدام الشخصي فقط، وليس للنشر.'**
  String get settingsPersonalUse;

  /// No description provided for @accountTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get accountTitle;

  /// No description provided for @accountSignedOut.
  ///
  /// In ar, this message translates to:
  /// **'غير مسجّل الدخول'**
  String get accountSignedOut;

  /// No description provided for @accountSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'متصل بحساب جوجل'**
  String get accountSignedIn;

  /// No description provided for @signIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج؟'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُمسح بيانات الدخول من هذا الجهاز.'**
  String get signOutConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @loginExplain.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لعرض قوائمك واشتراكاتك وإعجاباتك'**
  String get loginExplain;

  /// No description provided for @loginContinue.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة بحساب جوجل'**
  String get loginContinue;

  /// No description provided for @loginNotNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get loginNotNow;

  /// No description provided for @loginNoPassword.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق لا يرى كلمة مرورك'**
  String get loginNoPassword;

  /// No description provided for @sessionExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك، سجّل الدخول من جديد'**
  String get sessionExpired;

  /// No description provided for @errorNotSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لعرض حسابك'**
  String get errorNotSignedIn;

  /// No description provided for @errorSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى'**
  String get errorSignIn;

  /// No description provided for @errorSignInUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الدخول غير مفعّل بعد في هذه النسخة'**
  String get errorSignInUnavailable;

  /// No description provided for @errorSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الخروج. حاول مرة أخرى'**
  String get errorSignOut;

  /// No description provided for @riskTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل أول دخول'**
  String get riskTitle;

  /// No description provided for @riskBody.
  ///
  /// In ar, this message translates to:
  /// **'هذا التطبيق يستخرج صوت يوتيوب بطريقة غير رسمية تخالف شروط يوتيوب. قد يؤدي ذلك إلى حجب شبكتك أو تقييد حسابك أو مشروع Google Cloud. الاستخراج منفصل عن حسابك ولا يتلقى أي رمز دخول، لكن الخطر يبقى قائماً.\n\nاستخدمه شخصياً فقط، ويُنصح بحساب لا تعتمد عليه في عمل حرج.\n\nستعرض جوجل تحذير «تطبيق غير موثّق»: اختر «متقدم» ثم «المتابعة».'**
  String get riskBody;

  /// No description provided for @riskAccept.
  ///
  /// In ar, this message translates to:
  /// **'أقرّ وأتابع'**
  String get riskAccept;
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
