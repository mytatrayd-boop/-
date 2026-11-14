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
  String get homeEmpty => 'هنا ستبدأ رحلتك. الشاشة الرئيسية قيد البناء.';

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
}
