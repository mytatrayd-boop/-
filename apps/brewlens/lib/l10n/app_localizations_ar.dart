// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'عدسة البُن';

  @override
  String get appTagline => 'قيّم مظهر قهوتك واحفظ مقاهيك';

  @override
  String get demoBanner => 'نسخة عرض — البيانات تجريبية';

  @override
  String get demoDialogTitle => 'نسخة عرض';

  @override
  String get demoDialogBody =>
      'هذه نسخة للمراجعة، لا تتصل بالخادم ولا بالمتجر.';

  @override
  String get ok => 'حسناً';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get back => 'رجوع';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get signInButton => 'دخول';

  @override
  String get noAccountPrompt => 'ليس لديك حساب؟';

  @override
  String get createAccountLink => 'أنشئ حساباً';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpReason =>
      'نحتاج حساباً لحفظ سجلك ومقاهيك وحماية محاولاتك اليومية';

  @override
  String passwordHint(int count) {
    return '$count أحرف على الأقل';
  }

  @override
  String get termsNotice => 'بالتسجيل توافق على الشروط وسياسة الخصوصية';

  @override
  String get signUpButton => 'إنشاء الحساب';

  @override
  String get haveAccountPrompt => 'لديك حساب؟';

  @override
  String get signInLink => 'سجّل الدخول';

  @override
  String get forgotTitle => 'استعادة كلمة المرور';

  @override
  String get forgotBody => 'سنرسل رابطاً لبريدك';

  @override
  String get sendLinkButton => 'إرسال الرابط';

  @override
  String resetSentBody(String email) {
    return 'أرسلنا الرابط إلى $email، تحقق من البريد المزعج أيضاً';
  }

  @override
  String get backToSignIn => 'العودة للدخول';

  @override
  String get resendButton => 'إعادة الإرسال';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال ($seconds)';
  }

  @override
  String get errorInvalidEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String errorPasswordShort(int count) {
    return 'كلمة المرور $count أحرف على الأقل';
  }

  @override
  String get errorPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get errorUnknown => 'حدث خطأ، حاول مجدداً';

  @override
  String get failureUnauthorized => 'انتهت الجلسة، سجّل الدخول مجدداً';

  @override
  String get failureInvalidCredentials => 'البريد أو كلمة المرور غير صحيحة';

  @override
  String get failureEmailTaken => 'هذا البريد مسجّل، سجّل الدخول';

  @override
  String get failureLimitReached => 'انتهت محاولاتك المجانية لليوم';

  @override
  String get failureFairUseReached => 'وصلت لحد الاستخدام العادل';

  @override
  String get failureServiceUnavailable =>
      'الخدمة غير متاحة الآن، لم تُحتسب المحاولة';

  @override
  String get failureImageTooLarge => 'الصورة كبيرة جداً، جرّب صورة أخرى';

  @override
  String get failureOffline => 'لا يوجد اتصال بالإنترنت';

  @override
  String get failureSaveFailed => 'تعذّر الحفظ، حاول مجدداً';

  @override
  String get failurePurchaseUnavailable => 'الشراء غير متاح حالياً';

  @override
  String get invalidImageNotCoffee => 'لا يبدو أن الصورة لكوب قهوة';

  @override
  String get invalidImageTooDark => 'الصورة مظلمة، جرّب إضاءة أفضل';

  @override
  String get invalidImageBlurry => 'الصورة غير واضحة، ثبّت الجوال وأعد التصوير';

  @override
  String get invalidImageNoCup =>
      'اجعل الكوب ظاهراً بالكامل من الأعلى أو الجانب';

  @override
  String get invalidImageOther => 'تعذّر تحليل الصورة، جرّب صورة أخرى';

  @override
  String get homeWelcome => 'أهلاً بك';

  @override
  String get homeHeroTitle => 'صوّر كوبك';

  @override
  String get homeHeroBody => 'احصل على تقييم المظهر ونصيحة باريستا';

  @override
  String get homeEmpty => 'لا تقييمات بعد — صوّر كوبك الأول';

  @override
  String usageRemainingDay(int remaining, int limit) {
    return 'متبقٍّ لك اليوم: $remaining من $limit';
  }

  @override
  String usageRemainingMonth(int remaining, int limit) {
    return 'متبقٍّ لك هذا الشهر: $remaining من $limit';
  }

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirm => 'تسجيل الخروج من حسابك؟';
}
