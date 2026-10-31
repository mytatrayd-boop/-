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

  @override
  String get favoriteAdd => 'إضافة إلى المفضلة';

  @override
  String get favoriteRemove => 'إزالة من المفضلة';

  @override
  String get favoriteAdded => 'أُضيف للمفضلة';

  @override
  String get favoriteRemoved => 'أُزيل من المفضلة';

  @override
  String get undo => 'تراجع';

  @override
  String get favoriteFailed => 'تعذّر تحديث المفضلة';

  @override
  String get favoritesEmptyTitle =>
      'لم تحفظ شيئاً بعد. اضغط النجمة في أي نتيجة';

  @override
  String get favoritesErrorTitle => 'تعذّر تحميل المفضلة';

  @override
  String get favoritesLoading => 'جارٍ تحميل المفضلة';

  @override
  String get cafeSave => 'احفظ مكان المقهى';

  @override
  String get cafeLocating => 'نحدد موقعك…';

  @override
  String get cafeLocationFailedTitle => 'تعذّر تحديد الموقع';

  @override
  String get cafeLocDenied =>
      'لم نحصل على إذن الموقع. يمكنك حفظ اسم المقهى فقط بلا رابط خرائط.';

  @override
  String get cafeLocDeniedForever =>
      'إذن الموقع مرفوض. فعّله من إعدادات الجوال، أو احفظ الاسم فقط بلا رابط خرائط.';

  @override
  String get cafeLocServiceOff =>
      'خدمة الموقع مغلقة في الجوال. شغّلها، أو احفظ الاسم فقط بلا رابط خرائط.';

  @override
  String get cafeLocTimeout =>
      'استغرق تحديد الموقع وقتاً طويلاً. حاول لاحقاً، أو احفظ الاسم فقط بلا رابط خرائط.';

  @override
  String get cafeLocError =>
      'تعذّر تحديد الموقع. يمكنك حفظ الاسم فقط بلا رابط خرائط.';

  @override
  String get cafeSaveNameOnly => 'احفظ الاسم فقط';

  @override
  String get cafeNameTitle => 'اسم المقهى';

  @override
  String get cafeNameLabel => 'اسم المقهى';

  @override
  String get cafeNameRequired => 'أدخل اسم المقهى';

  @override
  String get cafeSaveAction => 'حفظ';

  @override
  String get cafeSaved => 'حُفظ المقهى';

  @override
  String get cafeSaveFailed => 'تعذّر حفظ المقهى';

  @override
  String get cafeOpenInMaps => 'افتح في خرائط قوقل';

  @override
  String get cafeOpenFailed => 'تعذّر فتح الخرائط';

  @override
  String get cafesTitle => 'مقاهيّ المحفوظة';

  @override
  String get cafesEmptyTitle => 'لم تحدد مقهى بعد';

  @override
  String get cafesEmptyBody =>
      'افتح تفاصيل أي فحص واضغط «احفظ مكان المقهى» وأنت في المقهى.';

  @override
  String get cafesErrorTitle => 'تعذّر تحميل المقاهي';

  @override
  String get cafesLoading => 'جارٍ تحميل المقاهي';

  @override
  String cafeScanCount(int count) {
    return 'الفحوصات: $count';
  }

  @override
  String cafeLastScore(int score) {
    return 'آخر درجة: $score/100';
  }

  @override
  String get cafeNoLocation => 'بلا موقع';

  @override
  String get cafeMenu => 'خيارات المقهى';

  @override
  String get cafeEdit => 'تعديل الاسم';

  @override
  String get cafeEditTitle => 'تعديل اسم المقهى';

  @override
  String get cafeDelete => 'حذف المقهى';

  @override
  String get cafeDeleteTitle => 'حذف هذا المقهى؟';

  @override
  String get cafeDeleteBody =>
      'تبقى فحوصاتك ويُزال اسم المقهى منها. لا يمكن التراجع.';

  @override
  String get cafeDeleted => 'تم حذف المقهى';

  @override
  String get cafeDeleteFailed => 'تعذّر حذف المقهى';

  @override
  String get cafeRenameFailed => 'تعذّر تعديل الاسم';

  @override
  String get scanCafe => 'المقهى';

  @override
  String get settingsCafesSubtitle => 'أماكن المقاهي التي حفظتها';
}
