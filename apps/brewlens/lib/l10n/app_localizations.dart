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

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get navHistory;

  /// No description provided for @openCamera.
  ///
  /// In ar, this message translates to:
  /// **'افتح الكاميرا'**
  String get openCamera;

  /// No description provided for @seeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get seeAll;

  /// No description provided for @recentReviews.
  ///
  /// In ar, this message translates to:
  /// **'آخر التقييمات'**
  String get recentReviews;

  /// No description provided for @favoriteShops.
  ///
  /// In ar, this message translates to:
  /// **'مقاهيّ المفضلة'**
  String get favoriteShops;

  /// No description provided for @coffeeEspresso.
  ///
  /// In ar, this message translates to:
  /// **'إسبريسو'**
  String get coffeeEspresso;

  /// No description provided for @coffeeV60.
  ///
  /// In ar, this message translates to:
  /// **'V60'**
  String get coffeeV60;

  /// No description provided for @coffeeFrenchPress.
  ///
  /// In ar, this message translates to:
  /// **'فرنش بريس'**
  String get coffeeFrenchPress;

  /// No description provided for @visualLimitedNote.
  ///
  /// In ar, this message translates to:
  /// **'التحليل البصري لهذا النوع محدود؛ تقييمك الذوقي أهم'**
  String get visualLimitedNote;

  /// No description provided for @cameraGuide.
  ///
  /// In ar, this message translates to:
  /// **'ضع الكوب داخل الدائرة، والإضاءة من الأمام'**
  String get cameraGuide;

  /// No description provided for @capturePhoto.
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة'**
  String get capturePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من المعرض'**
  String get pickFromGallery;

  /// No description provided for @analyzing.
  ///
  /// In ar, this message translates to:
  /// **'الباريستا يتفحص كوبك…'**
  String get analyzing;

  /// No description provided for @analyzingLong.
  ///
  /// In ar, this message translates to:
  /// **'لحظات إضافية…'**
  String get analyzingLong;

  /// No description provided for @cameraDenied.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج الكاميرا لتصوير كوبك وتقييم مظهره'**
  String get cameraDenied;

  /// No description provided for @galleryDenied.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج الوصول للصور لاختيار صورة كوبك'**
  String get galleryDenied;

  /// No description provided for @openSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get openSettings;

  /// No description provided for @attemptNotCounted.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحتسب هذه المحاولة'**
  String get attemptNotCounted;

  /// No description provided for @retakePhoto.
  ///
  /// In ar, this message translates to:
  /// **'التقط مجدداً'**
  String get retakePhoto;

  /// No description provided for @tryLater.
  ///
  /// In ar, this message translates to:
  /// **'حاول لاحقاً'**
  String get tryLater;

  /// No description provided for @resubmit.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get resubmit;

  /// No description provided for @demoSimulateRejection.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة صورة مرفوضة'**
  String get demoSimulateRejection;

  /// No description provided for @resultTitle.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get resultTitle;

  /// No description provided for @appearanceScore.
  ///
  /// In ar, this message translates to:
  /// **'تقييم المظهر'**
  String get appearanceScore;

  /// No description provided for @scoreOutOf.
  ///
  /// In ar, this message translates to:
  /// **'/10'**
  String get scoreOutOf;

  /// No description provided for @scoreSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تقييم المظهر {score} من 10'**
  String scoreSemantics(String score);

  /// No description provided for @scoreNeedsCare.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج عناية'**
  String get scoreNeedsCare;

  /// No description provided for @scoreGood.
  ///
  /// In ar, this message translates to:
  /// **'جيد'**
  String get scoreGood;

  /// No description provided for @scoreExcellent.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز'**
  String get scoreExcellent;

  /// No description provided for @scoreExceptional.
  ///
  /// In ar, this message translates to:
  /// **'استثنائي'**
  String get scoreExceptional;

  /// No description provided for @baristaReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير الباريستا'**
  String get baristaReport;

  /// No description provided for @tipLine.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة للمرة القادمة: {tip}'**
  String tipLine(String tip);

  /// No description provided for @tasteRatingPrompt.
  ///
  /// In ar, this message translates to:
  /// **'بعد التذوق، كم تعطيه؟'**
  String get tasteRatingPrompt;

  /// No description provided for @ratingSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تقييمك {rating} من 5'**
  String ratingSemantics(int rating);

  /// No description provided for @starSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{count} من 5'**
  String starSemantics(int count);

  /// No description provided for @userNotesLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظاتك (اختياري)'**
  String get userNotesLabel;

  /// No description provided for @shopPrompt.
  ///
  /// In ar, this message translates to:
  /// **'أين شربته؟ (اختياري)'**
  String get shopPrompt;

  /// No description provided for @addFavorite.
  ///
  /// In ar, this message translates to:
  /// **'إضافة للمفضلة'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المفضلة'**
  String get removeFavorite;

  /// No description provided for @addedToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف للمفضلة'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من المفضلة'**
  String get removedFromFavorites;

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @saveReview.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التقييم'**
  String get saveReview;

  /// No description provided for @savedDone.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get savedDone;

  /// No description provided for @viewInHistory.
  ///
  /// In ar, this message translates to:
  /// **'عرض في السجل'**
  String get viewInHistory;

  /// No description provided for @discardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل النتيجة؟'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In ar, this message translates to:
  /// **'ستبقى المحاولة محتسبة'**
  String get discardBody;

  /// No description provided for @discard.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get discard;

  /// No description provided for @stay.
  ///
  /// In ar, this message translates to:
  /// **'البقاء'**
  String get stay;

  /// No description provided for @shopNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المقهى'**
  String get shopNameLabel;

  /// No description provided for @previousShops.
  ///
  /// In ar, this message translates to:
  /// **'مقاهيك السابقة'**
  String get previousShops;

  /// No description provided for @hasSavedLocation.
  ///
  /// In ar, this message translates to:
  /// **'له موقع محفوظ'**
  String get hasSavedLocation;

  /// No description provided for @saveMyLocation.
  ///
  /// In ar, this message translates to:
  /// **'حفظ موقعي الحالي كموقع المقهى'**
  String get saveMyLocation;

  /// No description provided for @locating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد الموقع…'**
  String get locating;

  /// No description provided for @locationSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الموقع'**
  String get locationSaved;

  /// No description provided for @remove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get remove;

  /// No description provided for @usingSavedLocation.
  ///
  /// In ar, this message translates to:
  /// **'سيُستخدم الموقع المحفوظ'**
  String get usingSavedLocation;

  /// No description provided for @locationFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من تحديد موقعك — سيُحفظ الاسم فقط'**
  String get locationFailed;

  /// No description provided for @enableLocation.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الموقع'**
  String get enableLocation;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @noShop.
  ///
  /// In ar, this message translates to:
  /// **'بدون مقهى'**
  String get noShop;

  /// No description provided for @historyTitle.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get historyTitle;

  /// No description provided for @tabMyReviews.
  ///
  /// In ar, this message translates to:
  /// **'تقييماتي'**
  String get tabMyReviews;

  /// No description provided for @tabFavorites.
  ///
  /// In ar, this message translates to:
  /// **'المقاهي المفضلة'**
  String get tabFavorites;

  /// No description provided for @notRated.
  ///
  /// In ar, this message translates to:
  /// **'لم تُقيّم'**
  String get notRated;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل يوم} =2{قبل يومين} few{قبل {count} أيام} many{قبل {count} يوماً} other{قبل {count} يوم}}'**
  String daysAgo(int count);

  /// No description provided for @favoritesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مقاهٍ مفضلة بعد — أضف مقهى من شاشة النتيجة'**
  String get favoritesEmpty;

  /// No description provided for @noRatingYet.
  ///
  /// In ar, this message translates to:
  /// **'—'**
  String get noRatingYet;

  /// No description provided for @shopRating.
  ///
  /// In ar, this message translates to:
  /// **'★ {rating}'**
  String shopRating(String rating);

  /// No description provided for @shopScore.
  ///
  /// In ar, this message translates to:
  /// **'مظهر {score}'**
  String shopScore(String score);

  /// No description provided for @reviewsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تقييمات} =1{تقييم واحد} =2{تقييمان} few{{count} تقييمات} many{{count} تقييماً} other{{count} تقييم}}'**
  String reviewsCount(int count);

  /// No description provided for @openInGoogleMaps.
  ///
  /// In ar, this message translates to:
  /// **'فتح في خرائط جوجل'**
  String get openInGoogleMaps;

  /// No description provided for @mapsFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الخرائط'**
  String get mapsFailed;

  /// No description provided for @reviewDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل التقييم'**
  String get reviewDetailTitle;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get saveChanges;

  /// No description provided for @moreOptions.
  ///
  /// In ar, this message translates to:
  /// **'خيارات أخرى'**
  String get moreOptions;

  /// No description provided for @deleteReview.
  ///
  /// In ar, this message translates to:
  /// **'حذف التقييم'**
  String get deleteReview;

  /// No description provided for @deleteReviewConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا التقييم وصورته نهائياً؟'**
  String get deleteReviewConfirm;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @reviewDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التقييم'**
  String get reviewDeleted;

  /// No description provided for @paywallRenews.
  ///
  /// In ar, this message translates to:
  /// **'تتجدد منتصف الليل بتوقيت الرياض'**
  String get paywallRenews;

  /// No description provided for @failurePurchaseFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم تكتمل العملية، لم يُخصم منك شيء'**
  String get failurePurchaseFailed;

  /// No description provided for @failureNoPurchases.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مشتريات سابقة لهذا الحساب'**
  String get failureNoPurchases;

  /// No description provided for @failureDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحذف، حاول مجدداً'**
  String get failureDeleteFailed;

  /// No description provided for @failureShareFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء البطاقة، حاول مجدداً'**
  String get failureShareFailed;

  /// No description provided for @shareCard.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة كبطاقة'**
  String get shareCard;

  /// No description provided for @shareCardBrand.
  ///
  /// In ar, this message translates to:
  /// **'BrewLens'**
  String get shareCardBrand;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get termsOfUse;

  /// No description provided for @privacyBody.
  ///
  /// In ar, this message translates to:
  /// **'نسخة مؤقتة مختصرة حتى نشر السياسة الكاملة.\n\n• نجمع بريدك الإلكتروني لإنشاء حسابك فقط، بلا اسم عرض.\n• صورة الكوب تُرسل لخدمة ذكاء اصطناعي (Google Gemini) لتحليل مظهرها، وتُحفظ في حسابك فقط.\n• موقع المقهى يُقرأ مرة واحدة عند ضغطك «حفظ موقعي»، ولا يُربط بتقييماتك.\n• لا نستخدم أدوات تتبع ولا نبيع بياناتك.\n• يمكنك حذف حسابك وكل بياناتك وصورك نهائياً من الإعدادات.'**
  String get privacyBody;

  /// No description provided for @termsBody.
  ///
  /// In ar, this message translates to:
  /// **'نسخة مؤقتة مختصرة حتى نشر الشروط الكاملة.\n\n• «تقييم المظهر» تقدير آلي لشكل الكوب في الصورة فقط، وليس حكماً مهنياً.\n• تحليلان مجاناً يومياً، و20 يومياً للمشتركين ضمن الاستخدام العادل.\n• الاشتراك يتجدد تلقائياً ما لم تُلغِه قبل 24 ساعة من نهاية الفترة، والإلغاء من إعدادات المتجر.\n• لا ترفع صوراً لا تملك حق استخدامها.'**
  String get termsBody;

  /// No description provided for @restorePurchases.
  ///
  /// In ar, this message translates to:
  /// **'استعادة المشتريات'**
  String get restorePurchases;

  /// No description provided for @subscribedTitle.
  ///
  /// In ar, this message translates to:
  /// **'أصبحت مشتركاً'**
  String get subscribedTitle;

  /// No description provided for @startCapturing.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التصوير'**
  String get startCapturing;

  /// No description provided for @priceSar.
  ///
  /// In ar, this message translates to:
  /// **'{amount} ر.س'**
  String priceSar(String amount);

  /// No description provided for @paywallTitleSettings.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في عدسة البُن'**
  String get paywallTitleSettings;

  /// No description provided for @paywallTitleLimit.
  ///
  /// In ar, this message translates to:
  /// **'انتهت محاولاتك المجانية لليوم'**
  String get paywallTitleLimit;

  /// No description provided for @paywallBenefitLimit.
  ///
  /// In ar, this message translates to:
  /// **'20 تحليلاً يومياً'**
  String get paywallBenefitLimit;

  /// No description provided for @paywallBenefitReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير باريستا لكل كوب'**
  String get paywallBenefitReport;

  /// No description provided for @paywallBenefitHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل ومفضلة بلا حدود'**
  String get paywallBenefitHistory;

  /// No description provided for @planAnnual.
  ///
  /// In ar, this message translates to:
  /// **'سنوي'**
  String get planAnnual;

  /// No description provided for @planMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get planMonthly;

  /// No description provided for @perYear.
  ///
  /// In ar, this message translates to:
  /// **'{price} / سنة'**
  String perYear(String price);

  /// No description provided for @perMonth.
  ///
  /// In ar, this message translates to:
  /// **'{price} / شهر'**
  String perMonth(String price);

  /// No description provided for @perMonthApprox.
  ///
  /// In ar, this message translates to:
  /// **'≈ {price} شهرياً'**
  String perMonthApprox(String price);

  /// No description provided for @trialDays.
  ///
  /// In ar, this message translates to:
  /// **'{days} أيام مجاناً'**
  String trialDays(int days);

  /// No description provided for @savePercent.
  ///
  /// In ar, this message translates to:
  /// **'وفّر {percent}%'**
  String savePercent(int percent);

  /// No description provided for @startFreeTrial.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التجربة المجانية'**
  String get startFreeTrial;

  /// No description provided for @subscribeNow.
  ///
  /// In ar, this message translates to:
  /// **'اشترك الآن'**
  String get subscribeNow;

  /// No description provided for @subscriptionTerms.
  ///
  /// In ar, this message translates to:
  /// **'يتجدد تلقائياً ما لم تُلغِه قبل 24 ساعة من نهاية الفترة. الإلغاء من إعدادات المتجر.'**
  String get subscriptionTerms;

  /// No description provided for @termsShort.
  ///
  /// In ar, this message translates to:
  /// **'الشروط'**
  String get termsShort;

  /// No description provided for @privacyShort.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacyShort;

  /// No description provided for @purchaseUnavailableDemo.
  ///
  /// In ar, this message translates to:
  /// **'الشراء غير متاح في نسخة العرض'**
  String get purchaseUnavailableDemo;

  /// No description provided for @languageSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get languageSystem;

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

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @settingsAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get settingsAccount;

  /// No description provided for @subscription.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك'**
  String get subscription;

  /// No description provided for @subscriptionActive.
  ///
  /// In ar, this message translates to:
  /// **'مشترك'**
  String get subscriptionActive;

  /// No description provided for @subscriptionFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get subscriptionFree;

  /// No description provided for @settingsApp.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق'**
  String get settingsApp;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @settingsDemo.
  ///
  /// In ar, this message translates to:
  /// **'وضع العرض فقط'**
  String get settingsDemo;

  /// No description provided for @simulateSubscriber.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة مشترك'**
  String get simulateSubscriber;

  /// No description provided for @simulateSubscriberHint.
  ///
  /// In ar, this message translates to:
  /// **'يرفع الحد إلى 20 تحليلاً يومياً في نسخة العرض'**
  String get simulateSubscriberHint;

  /// No description provided for @deleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get deleteAccount;

  /// No description provided for @versionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String versionLabel(String version);

  /// No description provided for @accountDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف حسابك'**
  String get accountDeleted;

  /// No description provided for @deleteConfirmWord.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get deleteConfirmWord;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف حسابك وكل تقييماتك وصورك ومفضلتك نهائياً ولا يمكن استرجاعها'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountSubscriptionNote.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك لا يُلغى بالحذف — ألغِه من إعدادات المتجر'**
  String get deleteAccountSubscriptionNote;

  /// No description provided for @deleteConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'اكتب «{word}» للتأكيد'**
  String deleteConfirmLabel(String word);

  /// No description provided for @deleteAccountButton.
  ///
  /// In ar, this message translates to:
  /// **'حذف حسابي نهائياً'**
  String get deleteAccountButton;

  /// No description provided for @manageSubscription.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الاشتراك في المتجر'**
  String get manageSubscription;
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
