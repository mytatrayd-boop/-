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

  /// No description provided for @countdownCancelHint.
  ///
  /// In ar, this message translates to:
  /// **'المس الشاشة للإلغاء'**
  String get countdownCancelHint;

  /// No description provided for @countdownLabel.
  ///
  /// In ar, this message translates to:
  /// **'العدّ التنازلي {n}'**
  String countdownLabel(int n);

  /// No description provided for @stopConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة؟'**
  String get stopConfirmTitle;

  /// No description provided for @stopConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'التسجيل مستمر حتى تؤكد.'**
  String get stopConfirmBody;

  /// No description provided for @stopConfirmEnd.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء وحفظ'**
  String get stopConfirmEnd;

  /// No description provided for @stopConfirmContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة التسجيل'**
  String get stopConfirmContinue;

  /// No description provided for @savingTrip.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ...'**
  String get savingTrip;

  /// No description provided for @savingDoNotClose.
  ///
  /// In ar, this message translates to:
  /// **'لا تغلق التطبيق'**
  String get savingDoNotClose;

  /// No description provided for @startFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء التسجيل. حاول مرة أخرى.'**
  String get startFailed;

  /// No description provided for @summarySaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ رحلتك'**
  String get summarySaved;

  /// No description provided for @summaryDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get summaryDuration;

  /// No description provided for @summaryDistance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get summaryDistance;

  /// No description provided for @summaryVideoFailed.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ المسار لكن تعذّر حفظ الفيديو'**
  String get summaryVideoFailed;

  /// No description provided for @summaryInterruptedBackground.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت الرحلة لأن التطبيق خرج من الواجهة. حُفظ ما صُوِّر.'**
  String get summaryInterruptedBackground;

  /// No description provided for @summaryInterruptedCamera.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت الرحلة بسبب خطأ في الكاميرا. حُفظ ما صُوِّر.'**
  String get summaryInterruptedCamera;

  /// No description provided for @summaryInterruptedWrite.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت الرحلة بسبب خطأ في الكتابة. حُفظ ما صُوِّر.'**
  String get summaryInterruptedWrite;

  /// No description provided for @summaryInterruptedStorage.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت الرحلة لقلة المساحة. حُفظ ما صُوِّر.'**
  String get summaryInterruptedStorage;

  /// No description provided for @summaryInterruptedOther.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت الرحلة بشكل غير متوقع. حُفظ ما صُوِّر.'**
  String get summaryInterruptedOther;

  /// No description provided for @summaryNewTrip.
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get summaryNewTrip;

  /// No description provided for @summaryViewTrip.
  ///
  /// In ar, this message translates to:
  /// **'عرض الرحلة'**
  String get summaryViewTrip;

  /// No description provided for @summaryLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرحلة'**
  String get summaryLoadError;

  /// No description provided for @summaryGallerySaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ حفظ الفيديو في ألبوم الجوال…'**
  String get summaryGallerySaving;

  /// No description provided for @summaryGallerySaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الفيديو في ألبوم الجوال'**
  String get summaryGallerySaved;

  /// No description provided for @summaryGalleryFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ الفيديو في ألبوم الجوال'**
  String get summaryGalleryFailed;

  /// No description provided for @summaryGalleryRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get summaryGalleryRetry;

  /// No description provided for @summaryDbError.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة لكن تعذّر حفظ بعض تفاصيلها'**
  String get summaryDbError;

  /// No description provided for @tripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلاتي'**
  String get tripsTitle;

  /// No description provided for @tripsNew.
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get tripsNew;

  /// No description provided for @tripsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات بعد'**
  String get tripsEmpty;

  /// No description provided for @tripsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلتك الأولى لتظهر هنا.'**
  String get tripsEmptyHint;

  /// No description provided for @tripsLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الرحلات'**
  String get tripsLoadError;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @tripStatusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get tripStatusCompleted;

  /// No description provided for @tripStatusInterrupted.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت تلقائياً'**
  String get tripStatusInterrupted;

  /// No description provided for @tripStatusRecording.
  ///
  /// In ar, this message translates to:
  /// **'غير مكتملة'**
  String get tripStatusRecording;

  /// No description provided for @tripNoVideoChip.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو غير متوفر'**
  String get tripNoVideoChip;

  /// No description provided for @tripDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get tripDetailsTitle;

  /// No description provided for @tripDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get tripDate;

  /// No description provided for @tripPlayVideo.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الفيديو'**
  String get tripPlayVideo;

  /// No description provided for @tripVideoMissing.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو غير موجود على الجوال'**
  String get tripVideoMissing;

  /// No description provided for @tripPlayFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الفيديو'**
  String get tripPlayFailed;

  /// No description provided for @tripShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get tripShare;

  /// No description provided for @tripDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get tripDelete;

  /// No description provided for @tripDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الرحلة؟'**
  String get tripDeleteTitle;

  /// No description provided for @tripDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف المسار من التطبيق. يبقى الفيديو في ألبوم الجوال.'**
  String get tripDeleteBody;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @tripDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الرحلة'**
  String get tripDeleted;

  /// No description provided for @tripDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف الرحلة'**
  String get tripDeleteFailed;

  /// No description provided for @tripNoRoute.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نقاط مسار لهذه الرحلة'**
  String get tripNoRoute;

  /// No description provided for @shareTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الرحلة'**
  String get shareTitle;

  /// No description provided for @shareVideoTitle.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الفيديو'**
  String get shareVideoTitle;

  /// No description provided for @shareVideoDesc.
  ///
  /// In ar, this message translates to:
  /// **'فيديو واحد يجمع الصورة والمسار'**
  String get shareVideoDesc;

  /// No description provided for @shareVideoWarning.
  ///
  /// In ar, this message translates to:
  /// **'قد يضغط واتساب الفيديو الكبير فتقل جودته.'**
  String get shareVideoWarning;

  /// No description provided for @shareVideoMissing.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو غير موجود على الجوال'**
  String get shareVideoMissing;

  /// No description provided for @shareRouteTitle.
  ///
  /// In ar, this message translates to:
  /// **'إرسال مساري على الخريطة'**
  String get shareRouteTitle;

  /// No description provided for @shareRouteDesc.
  ///
  /// In ar, this message translates to:
  /// **'رابط لخرائط جوجل أو ملف GPX'**
  String get shareRouteDesc;

  /// No description provided for @shareLinkTitle.
  ///
  /// In ar, this message translates to:
  /// **'رابط خرائط جوجل'**
  String get shareLinkTitle;

  /// No description provided for @shareLinkNote.
  ///
  /// In ar, this message translates to:
  /// **'المسار تقريبي: اختُصر إلى نقاط قليلة. ملف GPX يحوي المسار كاملاً.'**
  String get shareLinkNote;

  /// No description provided for @shareLinkShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الرابط'**
  String get shareLinkShare;

  /// No description provided for @shareLinkOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح في خرائط جوجل'**
  String get shareLinkOpen;

  /// No description provided for @shareGpxTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملف GPX'**
  String get shareGpxTitle;

  /// No description provided for @shareGpxDesc.
  ///
  /// In ar, this message translates to:
  /// **'دقيق وكامل، يُفتح في تطبيقات المسارات'**
  String get shareGpxDesc;

  /// No description provided for @shareGpxShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الملف'**
  String get shareGpxShare;

  /// No description provided for @shareNoRoute.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مسار لمشاركته'**
  String get shareNoRoute;

  /// No description provided for @shareFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت المشاركة'**
  String get shareFailed;

  /// No description provided for @openMapsFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح خرائط جوجل'**
  String get openMapsFailed;

  /// No description provided for @shareLinkMessage.
  ///
  /// In ar, this message translates to:
  /// **'مساري على الخريطة: {url}'**
  String shareLinkMessage(String url);
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
