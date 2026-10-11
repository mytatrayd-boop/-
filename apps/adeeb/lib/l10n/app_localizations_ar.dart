// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الأديب الذكي';

  @override
  String get libraryTitle => 'المكتبة';

  @override
  String get download => 'تحميل';

  @override
  String downloadingPercent(String percent) {
    return 'يُحمَّل… $percent٪';
  }

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get redownload => 'إعادة التحميل';

  @override
  String get open => 'افتح';

  @override
  String get installed => 'محمّل';

  @override
  String get notInstalled => 'غير محمّل';

  @override
  String get updateAvailable => 'تحديث متاح';

  @override
  String get update => 'تحديث';

  @override
  String get preparing => 'يُجهَّز للبحث…';

  @override
  String get downloadFailed => 'تعذّر التحميل';

  @override
  String get downloadInterrupted => 'انقطع الاتصال أثناء التحميل';

  @override
  String get fileCorrupt => 'الملف غير سليم. أعد تحميله.';

  @override
  String get needsConnection => 'يحتاج اتصالاً';

  @override
  String get offlineBanner => 'أنت دون إنترنت — الكتب المحمّلة متاحة';

  @override
  String get staleCatalogBanner => 'قد لا تكون القائمة محدّثة';

  @override
  String get updateAppBanner =>
      'قائمة الكتب بصيغة أحدث من هذا الإصدار. حدّث التطبيق لرؤية الكتب الجديدة.';

  @override
  String get offlineFirstRunTitle => 'تحتاج اتصالاً لتحميل الكتب';

  @override
  String get offlineFirstRunBody =>
      'اتصل بالإنترنت مرة واحدة لتحميل قائمة الكتب، وبعدها تقرأ وتبحث وتستمع دون اتصال.';

  @override
  String get catalogError =>
      'تعذّر تحميل قائمة الكتب. تحقّق من الاتصال وحاول مجدداً.';

  @override
  String get emptyLibrary => 'لا توجد كتب متاحة بعد.';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get deleteFromDevice => 'حذف من الجهاز';

  @override
  String get deleteDialogTitle => 'حذف الكتاب من الجهاز؟';

  @override
  String deleteDialogBody(String title, String size) {
    return 'سيُحذف «$title» من جهازك ويتحرّر $size. تبقى المفضلة وآخر موضع، ويمكنك تحميله مجدداً في أي وقت.';
  }

  @override
  String get delete => 'حذف';

  @override
  String get bookDeleted => 'حُذف الكتاب';

  @override
  String get deleteFailed => 'تعذّر حذف الكتاب';

  @override
  String get bookUpdated => 'حُدّث الكتاب';

  @override
  String sizeMb(String size) {
    return '$size م.ب';
  }

  @override
  String sizeKb(String size) {
    return '$size ك.ب';
  }

  @override
  String sizeMbSpoken(String size) {
    return '$size ميغابايت';
  }

  @override
  String sizeKbSpoken(String size) {
    return '$size كيلوبايت';
  }

  @override
  String deathHijri(String year) {
    return 'ت $yearهـ';
  }

  @override
  String deathHijriSpoken(String year) {
    return 'متوفى $year للهجرة';
  }

  @override
  String authorWithDeath(String author, String death) {
    return '$author ($death)';
  }

  @override
  String bookCardSemantics(String title, String author, String details) {
    return '$title، $author، $details';
  }

  @override
  String get moreOptions => 'خيارات أخرى';

  @override
  String sourceLine(String source, String license) {
    return 'المصدر: $source — $license';
  }

  @override
  String get licensePublicDomain => 'ملك عام';

  @override
  String downloadBook(String size) {
    return 'تحميل الكتاب ($size)';
  }

  @override
  String get chapters => 'الأبواب';

  @override
  String get downloadToSeeChapters => 'حمّل الكتاب لعرض أبوابه';

  @override
  String get bookOpenError => 'تعذّر فتح الكتاب. أعد تحميله.';

  @override
  String chapterSemantics(String number, String total, String title) {
    return 'الباب $number من $total: $title';
  }

  @override
  String get bookNotFound => 'هذا الكتاب غير موجود في المكتبة.';
}
