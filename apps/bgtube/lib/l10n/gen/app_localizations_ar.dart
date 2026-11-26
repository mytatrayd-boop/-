// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'BGTube';

  @override
  String get emptyTitle => 'الصق رابط يوتيوب لتشغيله';

  @override
  String get linkHint => 'رابط يوتيوب';

  @override
  String get pasteAndPlay => 'لصق وتشغيل';

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get stop => 'إيقاف';

  @override
  String get speed => 'سرعة التشغيل';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String sleepMinutes(String minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get sleepCancel => 'إلغاء المؤقت';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get resolving => 'جارٍ التحضير…';

  @override
  String get clipboardEmpty => 'لا يوجد رابط يوتيوب في الحافظة';

  @override
  String get errorInvalidLink =>
      'الرابط غير صالح. تأكد أنه رابط فيديو من يوتيوب.';

  @override
  String get errorPlaylistNotSupported =>
      'روابط القوائم غير مدعومة بعد. الصق رابط فيديو واحد.';

  @override
  String get errorExtraction =>
      'تعذّر استخراج الصوت من هذا الفيديو. جرّب مرة أخرى.';

  @override
  String get errorNetwork =>
      'تعذّر الاتصال بالإنترنت. تحقق من الشبكة وأعد المحاولة.';

  @override
  String get errorRateLimited =>
      'يوتيوب يقيّد الطلبات من شبكتك الآن. انتظر قليلاً ثم أعد المحاولة.';

  @override
  String get errorPlayback => 'تعذّر تشغيل الصوت. أعد المحاولة.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageHint => 'تُطبَّق فوراً وتبقى محفوظة.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAbout => 'حول';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsPersonalUse => 'تطبيق للاستخدام الشخصي فقط، وليس للنشر.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountSignedOut => 'غير مسجّل الدخول';

  @override
  String get accountSignedIn => 'متصل بحساب جوجل';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get signOutConfirmBody => 'ستُمسح بيانات الدخول من هذا الجهاز.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get loginExplain => 'سجّل الدخول لعرض قوائمك واشتراكاتك وإعجاباتك';

  @override
  String get loginContinue => 'المتابعة بحساب جوجل';

  @override
  String get loginNotNow => 'ليس الآن';

  @override
  String get loginNoPassword => 'التطبيق لا يرى كلمة مرورك';

  @override
  String get sessionExpired => 'انتهت جلستك، سجّل الدخول من جديد';

  @override
  String get errorNotSignedIn => 'سجّل الدخول لعرض حسابك';

  @override
  String get errorSignIn =>
      'تعذّر تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى';

  @override
  String get errorSignInUnavailable => 'الدخول غير مفعّل بعد في هذه النسخة';

  @override
  String get errorSignOut => 'تعذّر تسجيل الخروج. حاول مرة أخرى';

  @override
  String get riskTitle => 'قبل أول دخول';

  @override
  String get riskBody =>
      'هذا التطبيق يستخرج صوت يوتيوب بطريقة غير رسمية تخالف شروط يوتيوب. قد يؤدي ذلك إلى حجب شبكتك أو تقييد حسابك أو مشروع Google Cloud. الاستخراج منفصل عن حسابك ولا يتلقى أي رمز دخول، لكن الخطر يبقى قائماً.\n\nاستخدمه شخصياً فقط، ويُنصح بحساب لا تعتمد عليه في عمل حرج.\n\nستعرض جوجل تحذير «تطبيق غير موثّق»: اختر «متقدم» ثم «المتابعة».';

  @override
  String get riskAccept => 'أقرّ وأتابع';
}
