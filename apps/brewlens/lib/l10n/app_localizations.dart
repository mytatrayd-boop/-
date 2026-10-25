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
  /// **'عدسة البُن'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'قيّم مظهر قهوتك واحفظ مقاهيك'**
  String get appTagline;

  /// No description provided for @demoBanner.
  ///
  /// In ar, this message translates to:
  /// **'نسخة عرض — البيانات تجريبية'**
  String get demoBanner;

  /// No description provided for @demoDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخة عرض'**
  String get demoDialogTitle;

  /// No description provided for @demoDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'هذه نسخة للمراجعة، لا تتصل بالخادم ولا بالمتجر.'**
  String get demoDialogBody;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get ok;

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

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPasswordLabel;

  /// No description provided for @showPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePassword;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPasswordLink;

  /// No description provided for @signInButton.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get signInButton;

  /// No description provided for @noAccountPrompt.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get noAccountPrompt;

  /// No description provided for @createAccountLink.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حساباً'**
  String get createAccountLink;

  /// No description provided for @signUpTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get signUpTitle;

  /// No description provided for @signUpReason.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج حساباً لحفظ سجلك ومقاهيك وحماية محاولاتك اليومية'**
  String get signUpReason;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'{count} أحرف على الأقل'**
  String passwordHint(int count);

  /// No description provided for @termsNotice.
  ///
  /// In ar, this message translates to:
  /// **'بالتسجيل توافق على الشروط وسياسة الخصوصية'**
  String get termsNotice;

  /// No description provided for @signUpButton.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get signUpButton;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب؟'**
  String get haveAccountPrompt;

  /// No description provided for @signInLink.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول'**
  String get signInLink;

  /// No description provided for @forgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة كلمة المرور'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل رابطاً لبريدك'**
  String get forgotBody;

  /// No description provided for @sendLinkButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرابط'**
  String get sendLinkButton;

  /// No description provided for @resetSentBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا الرابط إلى {email}، تحقق من البريد المزعج أيضاً'**
  String resetSentBody(String email);

  /// No description provided for @backToSignIn.
  ///
  /// In ar, this message translates to:
  /// **'العودة للدخول'**
  String get backToSignIn;

  /// No description provided for @resendButton.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get resendButton;

  /// No description provided for @resendIn.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال ({seconds})'**
  String resendIn(int seconds);

  /// No description provided for @errorInvalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريداً إلكترونياً صحيحاً'**
  String get errorInvalidEmail;

  /// No description provided for @errorPasswordShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور {count} أحرف على الأقل'**
  String errorPasswordShort(int count);

  /// No description provided for @errorPasswordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get errorPasswordMismatch;

  /// No description provided for @errorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ، حاول مجدداً'**
  String get errorUnknown;

  /// No description provided for @failureUnauthorized.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة، سجّل الدخول مجدداً'**
  String get failureUnauthorized;

  /// No description provided for @failureInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد أو كلمة المرور غير صحيحة'**
  String get failureInvalidCredentials;

  /// No description provided for @failureEmailTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مسجّل، سجّل الدخول'**
  String get failureEmailTaken;

  /// No description provided for @failureLimitReached.
  ///
  /// In ar, this message translates to:
  /// **'انتهت محاولاتك المجانية لليوم'**
  String get failureLimitReached;

  /// No description provided for @failureFairUseReached.
  ///
  /// In ar, this message translates to:
  /// **'وصلت لحد الاستخدام العادل'**
  String get failureFairUseReached;

  /// No description provided for @failureServiceUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة غير متاحة الآن، لم تُحتسب المحاولة'**
  String get failureServiceUnavailable;

  /// No description provided for @failureImageTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'الصورة كبيرة جداً، جرّب صورة أخرى'**
  String get failureImageTooLarge;

  /// No description provided for @failureOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get failureOffline;

  /// No description provided for @failureSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ، حاول مجدداً'**
  String get failureSaveFailed;

  /// No description provided for @failurePurchaseUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الشراء غير متاح حالياً'**
  String get failurePurchaseUnavailable;

  /// No description provided for @invalidImageNotCoffee.
  ///
  /// In ar, this message translates to:
  /// **'لا يبدو أن الصورة لكوب قهوة'**
  String get invalidImageNotCoffee;

  /// No description provided for @invalidImageTooDark.
  ///
  /// In ar, this message translates to:
  /// **'الصورة مظلمة، جرّب إضاءة أفضل'**
  String get invalidImageTooDark;

  /// No description provided for @invalidImageBlurry.
  ///
  /// In ar, this message translates to:
  /// **'الصورة غير واضحة، ثبّت الجوال وأعد التصوير'**
  String get invalidImageBlurry;

  /// No description provided for @invalidImageNoCup.
  ///
  /// In ar, this message translates to:
  /// **'اجعل الكوب ظاهراً بالكامل من الأعلى أو الجانب'**
  String get invalidImageNoCup;

  /// No description provided for @invalidImageOther.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحليل الصورة، جرّب صورة أخرى'**
  String get invalidImageOther;

  /// No description provided for @homeWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك'**
  String get homeWelcome;

  /// No description provided for @homeHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'صوّر كوبك'**
  String get homeHeroTitle;

  /// No description provided for @homeHeroBody.
  ///
  /// In ar, this message translates to:
  /// **'احصل على تقييم المظهر ونصيحة باريستا'**
  String get homeHeroBody;

  /// No description provided for @homeEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا تقييمات بعد — صوّر كوبك الأول'**
  String get homeEmpty;

  /// No description provided for @usageRemainingDay.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍّ لك اليوم: {remaining} من {limit}'**
  String usageRemainingDay(int remaining, int limit);

  /// No description provided for @usageRemainingMonth.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍّ لك هذا الشهر: {remaining} من {limit}'**
  String usageRemainingMonth(int remaining, int limit);

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج من حسابك؟'**
  String get signOutConfirm;
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
