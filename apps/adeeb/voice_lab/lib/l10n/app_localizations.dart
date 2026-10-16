import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LabLocalizations
/// returned by `LabLocalizations.of(context)`.
///
/// Applications need to include `LabLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LabLocalizations.localizationsDelegates,
///   supportedLocales: LabLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the LabLocalizations.supportedLocales
/// property.
abstract class LabLocalizations {
  LabLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LabLocalizations of(BuildContext context) {
    return Localizations.of<LabLocalizations>(context, LabLocalizations)!;
  }

  static const LocalizationsDelegate<LabLocalizations> delegate =
      _LabLocalizationsDelegate();

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

  /// عنوان شاشة تجربة الصوت
  ///
  /// In ar, this message translates to:
  /// **'تجربة الصوت المدمج (T0)'**
  String get labTitle;

  /// No description provided for @labPreparing.
  ///
  /// In ar, this message translates to:
  /// **'تجهيز النموذج…'**
  String get labPreparing;

  /// No description provided for @labLoading.
  ///
  /// In ar, this message translates to:
  /// **'تحميل النموذج في الذاكرة…'**
  String get labLoading;

  /// No description provided for @labMissingModel.
  ///
  /// In ar, this message translates to:
  /// **'النموذج غير مضمَّن في هذه النسخة. ابنِها من سير «Adeeb — voice lab APK».'**
  String get labMissingModel;

  /// No description provided for @labError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: {message}'**
  String labError(String message);

  /// No description provided for @labPlayAll.
  ///
  /// In ar, this message translates to:
  /// **'استمع للفقرات كلها'**
  String get labPlayAll;

  /// No description provided for @labStop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get labStop;

  /// No description provided for @labRtf.
  ///
  /// In ar, this message translates to:
  /// **'عامل الزمن الحقيقي (RTF)'**
  String get labRtf;

  /// No description provided for @labRtfValue.
  ///
  /// In ar, this message translates to:
  /// **'آخر فقرة {last} — الكل {all} (الهدف ≤ 0.5)'**
  String labRtfValue(String last, String all);

  /// No description provided for @labFirstAudio.
  ///
  /// In ar, this message translates to:
  /// **'زمن أول صوت'**
  String get labFirstAudio;

  /// No description provided for @labFirstAudioValue.
  ///
  /// In ar, this message translates to:
  /// **'آخر فقرة {last} ث — الأسوأ {worst} ث (الهدف ≤ 1.5)'**
  String labFirstAudioValue(String last, String worst);

  /// No description provided for @labPeakMemory.
  ///
  /// In ar, this message translates to:
  /// **'ذروة الذاكرة'**
  String get labPeakMemory;

  /// No description provided for @labPeakMemoryValue.
  ///
  /// In ar, this message translates to:
  /// **'{peak} م.ب (قبل النموذج {base} م.ب، الهدف ≤ 300)'**
  String labPeakMemoryValue(String peak, String base);

  /// No description provided for @labModelLoad.
  ///
  /// In ar, this message translates to:
  /// **'تحميل النموذج'**
  String get labModelLoad;

  /// No description provided for @labModelLoadValue.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث — {threads} خيوط'**
  String labModelLoadValue(String seconds, int threads);

  /// No description provided for @labNotMeasured.
  ///
  /// In ar, this message translates to:
  /// **'—'**
  String get labNotMeasured;

  /// No description provided for @labProse.
  ///
  /// In ar, this message translates to:
  /// **'نثر'**
  String get labProse;

  /// No description provided for @labVerse.
  ///
  /// In ar, this message translates to:
  /// **'شعر'**
  String get labVerse;

  /// No description provided for @labParagraphNumber.
  ///
  /// In ar, this message translates to:
  /// **'{book} — فقرة {number} ({kind})'**
  String labParagraphNumber(String book, int number, String kind);
}

class _LabLocalizationsDelegate
    extends LocalizationsDelegate<LabLocalizations> {
  const _LabLocalizationsDelegate();

  @override
  Future<LabLocalizations> load(Locale locale) {
    return SynchronousFuture<LabLocalizations>(lookupLabLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LabLocalizationsDelegate old) => false;
}

LabLocalizations lookupLabLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LabLocalizationsAr();
    case 'en':
      return LabLocalizationsEn();
  }

  throw FlutterError(
    'LabLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
