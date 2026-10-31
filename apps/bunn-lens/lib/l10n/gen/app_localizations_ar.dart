// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'عدسة البن';

  @override
  String get tabScan => 'فحص';

  @override
  String get tabHistory => 'السجل';

  @override
  String get tabFavorites => 'المفضلة';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get scanTitle => 'فحص';

  @override
  String get historyTitle => 'السجل';

  @override
  String get favoritesTitle => 'المفضلة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get logoLabel => 'شعار عدسة البن';

  @override
  String get placeholderSoon => 'قريباً';

  @override
  String get historyFilterAll => 'الكل';

  @override
  String get historyFilterBean => 'بن';

  @override
  String get historyFilterCoffee => 'قهوة';

  @override
  String get scanTypeBean => 'بن';

  @override
  String get scanTypeCoffee => 'قهوة';

  @override
  String get historyEmptyTitle => 'لا فحوصات بعد';

  @override
  String get historyEmptyAction => 'افحص الآن';

  @override
  String get historyErrorTitle => 'تعذّر تحميل السجل';

  @override
  String get retry => 'أعد المحاولة';

  @override
  String get historyLoading => 'جارٍ تحميل السجل';

  @override
  String scoreOutOf(int score) {
    return '$score/100';
  }

  @override
  String scanCardLabel(String type, int score) {
    return 'فحص $type، الدرجة $score من 100';
  }

  @override
  String get scanMenu => 'خيارات الفحص';

  @override
  String get scanDelete => 'حذف';

  @override
  String get deleteScanTitle => 'حذف هذا الفحص؟';

  @override
  String get deleteScanBody => 'لا يمكن التراجع.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get scanDeleted => 'تم حذف الفحص';

  @override
  String get scanDeleteFailed => 'تعذّر حذف الفحص';

  @override
  String get scanDetailTitle => 'تفاصيل الفحص';

  @override
  String get scanNotFound => 'هذا الفحص غير موجود';

  @override
  String get scanNotesTitle => 'الملاحظات';

  @override
  String get scanDisclaimer => 'التقدير بصري تقريبي وليس حكماً نهائياً';

  @override
  String get scanRoaster => 'المحمصة';

  @override
  String get scanPrice => 'السعر';

  @override
  String get scanDate => 'التاريخ';

  @override
  String get scanImageUnavailable => 'الصورة غير متاحة';

  @override
  String get scanTypeField => 'النوع';
}
