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
}
