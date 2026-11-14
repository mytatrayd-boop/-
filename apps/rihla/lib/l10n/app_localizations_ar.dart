// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'رحلة';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsEmpty => 'الإعدادات قيد البناء.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get backToHome => 'رجوع إلى الرئيسية';

  @override
  String get notFoundTitle => 'الصفحة غير موجودة';

  @override
  String get notFoundBody =>
      'لم نجد هذه الصفحة. ارجع إلى الشاشة الرئيسية وأعد المحاولة.';

  @override
  String get permTitle => 'الأذونات';

  @override
  String permStepOf(int n, int total) {
    return 'الخطوة $n من $total';
  }

  @override
  String get permCameraTitle => 'الكاميرا';

  @override
  String get permCameraReason => 'لتصوير طريقك.';

  @override
  String get permLocationTitle => 'الموقع';

  @override
  String get permLocationReason => 'لرسم مسارك على الخريطة وحسابه.';

  @override
  String get permMicTitle => 'الميكروفون';

  @override
  String get permMicReason => 'لتسجيل صوت الرحلة (اختياري ويمكنك كتمه).';

  @override
  String get permPrivacy => 'كل شيء يبقى على جوالك. لا حسابات ولا رفع.';

  @override
  String get permAllow => 'السماح';

  @override
  String get permNotNow => 'ليس الآن';

  @override
  String get permGranted => 'تم السماح';

  @override
  String get permCameraDenied => 'لن تعمل الرحلة بدون الكاميرا.';

  @override
  String get permLocationDenied =>
      'لن يُرسم المسار بدون الموقع، ولن تعمل الرحلة.';

  @override
  String get permMicDenied => 'سيُسجَّل الفيديو بلا صوت.';

  @override
  String get permPermanentHint =>
      'لا يمكن طلب الإذن من التطبيق مرة أخرى. فعّله من إعدادات الجوال.';

  @override
  String get permLocationApproximate =>
      'الموقع التقريبي لا يكفي. المسار يحتاج الدقة الكاملة؛ فعّل الموقع الدقيق من إعدادات الجوال.';

  @override
  String get permOpenPhoneSettings => 'فتح إعدادات الجوال';

  @override
  String get permRetry => 'إعادة المحاولة';

  @override
  String get permContinueNoAudio => 'متابعة بلا صوت';

  @override
  String get permAudioUnavailable => 'الصوت غير متاح';

  @override
  String get permStartBlocked => 'امنح الكاميرا والموقع لبدء الرحلة.';

  @override
  String permIllustration(String name) {
    return 'رسم توضيحي لإذن $name';
  }

  @override
  String get mapLocating => 'جارٍ تحديد موقعك...';

  @override
  String get mapRecenter => 'إعادة التمركز';

  @override
  String get startTrip => 'بدء الرحلة';

  @override
  String get stopTrip => 'إيقاف الرحلة';

  @override
  String get mute => 'كتم الصوت';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get audioOn => 'الصوت مفعّل';

  @override
  String get audioMuted => 'الصوت مكتوم';

  @override
  String get audioMutedChip => 'مكتوم';

  @override
  String get qualityTitle => 'جودة الفيديو';

  @override
  String get gpsGood => 'GPS جيد';

  @override
  String get gpsWeak => 'إشارة GPS ضعيفة';

  @override
  String get gpsSearching => 'جارٍ تحديد الموقع';

  @override
  String get offlineBanner => 'لا يوجد إنترنت: الخريطة لن تتحدث';

  @override
  String get cameraOpening => 'الكاميرا قيد التجهيز...';

  @override
  String get cameraError =>
      'تعذّر فتح الكاميرا. أغلق التطبيقات الأخرى المستخدمة لها.';

  @override
  String get homeOpenPermissions => 'فتح الأذونات';

  @override
  String hudDistanceKm(String km) {
    return '$km كم';
  }

  @override
  String get countdownCancelHint => 'المس الشاشة للإلغاء';

  @override
  String countdownLabel(int n) {
    return 'العدّ التنازلي $n';
  }

  @override
  String get stopConfirmTitle => 'إنهاء الرحلة؟';

  @override
  String get stopConfirmBody => 'التسجيل مستمر حتى تؤكد.';

  @override
  String get stopConfirmEnd => 'إنهاء وحفظ';

  @override
  String get stopConfirmContinue => 'متابعة التسجيل';

  @override
  String get savingTrip => 'جارٍ الحفظ...';

  @override
  String get savingDoNotClose => 'لا تغلق التطبيق';

  @override
  String get startFailed => 'تعذّر بدء التسجيل. حاول مرة أخرى.';

  @override
  String get summarySaved => 'تم حفظ رحلتك';

  @override
  String get summaryDuration => 'المدة';

  @override
  String get summaryDistance => 'المسافة';

  @override
  String get summaryVideoSaved => 'حُفظ الفيديو على الجوال';

  @override
  String get summaryVideoFailed => 'حُفظ المسار لكن تعذّر حفظ الفيديو';

  @override
  String get summaryInterruptedBackground =>
      'أُوقفت الرحلة لأن التطبيق خرج من الواجهة. حُفظ ما صُوِّر.';

  @override
  String get summaryInterruptedCamera =>
      'أُوقفت الرحلة بسبب خطأ في الكاميرا. حُفظ ما صُوِّر.';

  @override
  String get summaryInterruptedWrite =>
      'أُوقفت الرحلة بسبب خطأ في الكتابة. حُفظ ما صُوِّر.';

  @override
  String get summaryInterruptedStorage =>
      'أُوقفت الرحلة لقلة المساحة. حُفظ ما صُوِّر.';

  @override
  String get summaryInterruptedOther =>
      'أُوقفت الرحلة بشكل غير متوقع. حُفظ ما صُوِّر.';

  @override
  String get summaryNewTrip => 'رحلة جديدة';

  @override
  String get summaryViewTrip => 'عرض الرحلة';

  @override
  String get summaryLoadError => 'تعذّر فتح الرحلة';
}
