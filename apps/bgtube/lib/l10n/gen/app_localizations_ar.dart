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
}
