import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأديب الذكي'**
  String get appTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة'**
  String get libraryTitle;

  /// No description provided for @download.
  ///
  /// In ar, this message translates to:
  /// **'تحميل'**
  String get download;

  /// No description provided for @downloadingPercent.
  ///
  /// In ar, this message translates to:
  /// **'يُحمَّل… {percent}٪'**
  String downloadingPercent(String percent);

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @redownload.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التحميل'**
  String get redownload;

  /// No description provided for @open.
  ///
  /// In ar, this message translates to:
  /// **'افتح'**
  String get open;

  /// No description provided for @installed.
  ///
  /// In ar, this message translates to:
  /// **'محمّل'**
  String get installed;

  /// No description provided for @notInstalled.
  ///
  /// In ar, this message translates to:
  /// **'غير محمّل'**
  String get notInstalled;

  /// No description provided for @updateAvailable.
  ///
  /// In ar, this message translates to:
  /// **'تحديث متاح'**
  String get updateAvailable;

  /// No description provided for @update.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get update;

  /// No description provided for @preparing.
  ///
  /// In ar, this message translates to:
  /// **'يُجهَّز للبحث…'**
  String get preparing;

  /// No description provided for @downloadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل'**
  String get downloadFailed;

  /// No description provided for @downloadInterrupted.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال أثناء التحميل'**
  String get downloadInterrupted;

  /// No description provided for @fileCorrupt.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير سليم. أعد تحميله.'**
  String get fileCorrupt;

  /// No description provided for @needsConnection.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج اتصالاً'**
  String get needsConnection;

  /// No description provided for @offlineBanner.
  ///
  /// In ar, this message translates to:
  /// **'أنت دون إنترنت — الكتب المحمّلة متاحة'**
  String get offlineBanner;

  /// No description provided for @staleCatalogBanner.
  ///
  /// In ar, this message translates to:
  /// **'قد لا تكون القائمة محدّثة'**
  String get staleCatalogBanner;

  /// No description provided for @updateAppBanner.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الكتب بصيغة أحدث من هذا الإصدار. حدّث التطبيق لرؤية الكتب الجديدة.'**
  String get updateAppBanner;

  /// No description provided for @offlineFirstRunTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج اتصالاً لتحميل الكتب'**
  String get offlineFirstRunTitle;

  /// No description provided for @offlineFirstRunBody.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بالإنترنت مرة واحدة لتحميل قائمة الكتب، وبعدها تقرأ وتبحث وتستمع دون اتصال.'**
  String get offlineFirstRunBody;

  /// No description provided for @catalogError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل قائمة الكتب. تحقّق من الاتصال وحاول مجدداً.'**
  String get catalogError;

  /// No description provided for @emptyLibrary.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كتب متاحة بعد.'**
  String get emptyLibrary;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل'**
  String get loading;

  /// No description provided for @deleteFromDevice.
  ///
  /// In ar, this message translates to:
  /// **'حذف من الجهاز'**
  String get deleteFromDevice;

  /// No description provided for @deleteDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الكتاب من الجهاز؟'**
  String get deleteDialogTitle;

  /// No description provided for @deleteDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف «{title}» من جهازك ويتحرّر {size}. تبقى المفضلة وآخر موضع، ويمكنك تحميله مجدداً في أي وقت.'**
  String deleteDialogBody(String title, String size);

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @bookDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الكتاب'**
  String get bookDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف الكتاب'**
  String get deleteFailed;

  /// No description provided for @bookUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّث الكتاب'**
  String get bookUpdated;

  /// No description provided for @sizeMb.
  ///
  /// In ar, this message translates to:
  /// **'{size} م.ب'**
  String sizeMb(String size);

  /// No description provided for @sizeKb.
  ///
  /// In ar, this message translates to:
  /// **'{size} ك.ب'**
  String sizeKb(String size);

  /// No description provided for @sizeMbSpoken.
  ///
  /// In ar, this message translates to:
  /// **'{size} ميغابايت'**
  String sizeMbSpoken(String size);

  /// No description provided for @sizeKbSpoken.
  ///
  /// In ar, this message translates to:
  /// **'{size} كيلوبايت'**
  String sizeKbSpoken(String size);

  /// No description provided for @deathHijri.
  ///
  /// In ar, this message translates to:
  /// **'ت {year}هـ'**
  String deathHijri(String year);

  /// No description provided for @deathHijriSpoken.
  ///
  /// In ar, this message translates to:
  /// **'متوفى {year} للهجرة'**
  String deathHijriSpoken(String year);

  /// No description provided for @authorWithDeath.
  ///
  /// In ar, this message translates to:
  /// **'{author} ({death})'**
  String authorWithDeath(String author, String death);

  /// No description provided for @bookCardSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{title}، {author}، {details}'**
  String bookCardSemantics(String title, String author, String details);

  /// No description provided for @moreOptions.
  ///
  /// In ar, this message translates to:
  /// **'خيارات أخرى'**
  String get moreOptions;

  /// No description provided for @sourceLine.
  ///
  /// In ar, this message translates to:
  /// **'المصدر: {source} — {license}'**
  String sourceLine(String source, String license);

  /// No description provided for @licensePublicDomain.
  ///
  /// In ar, this message translates to:
  /// **'ملك عام'**
  String get licensePublicDomain;

  /// No description provided for @downloadBook.
  ///
  /// In ar, this message translates to:
  /// **'تحميل الكتاب ({size})'**
  String downloadBook(String size);

  /// No description provided for @chapters.
  ///
  /// In ar, this message translates to:
  /// **'الأبواب'**
  String get chapters;

  /// No description provided for @downloadToSeeChapters.
  ///
  /// In ar, this message translates to:
  /// **'حمّل الكتاب لعرض أبوابه'**
  String get downloadToSeeChapters;

  /// No description provided for @bookOpenError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الكتاب. أعد تحميله.'**
  String get bookOpenError;

  /// No description provided for @chapterSemantics.
  ///
  /// In ar, this message translates to:
  /// **'الباب {number} من {total}: {title}'**
  String chapterSemantics(String number, String total, String title);

  /// No description provided for @bookNotFound.
  ///
  /// In ar, this message translates to:
  /// **'هذا الكتاب غير موجود في المكتبة.'**
  String get bookNotFound;

  /// No description provided for @downloading.
  ///
  /// In ar, this message translates to:
  /// **'يُحمَّل…'**
  String get downloading;

  /// No description provided for @listSeparator.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get listSeparator;

  /// No description provided for @downloadAnnouncement.
  ///
  /// In ar, this message translates to:
  /// **'«{title}»: يُحمَّل… {percent}٪'**
  String downloadAnnouncement(String title, String percent);

  /// No description provided for @startReading.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ القراءة'**
  String get startReading;

  /// No description provided for @continueReading.
  ///
  /// In ar, this message translates to:
  /// **'تابع القراءة'**
  String get continueReading;

  /// No description provided for @reachedPosition.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى: {chapter} — {percent}٪'**
  String reachedPosition(String chapter, String percent);

  /// No description provided for @youAreHere.
  ///
  /// In ar, this message translates to:
  /// **'أنت هنا'**
  String get youAreHere;

  /// No description provided for @chapterHereSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{chapter}، أنت هنا'**
  String chapterHereSemantics(String chapter);

  /// No description provided for @booksTab.
  ///
  /// In ar, this message translates to:
  /// **'الكتب'**
  String get booksTab;

  /// No description provided for @favoritesTab.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get favoritesTab;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فقرات في المفضلة بعد.'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطوّلاً على أي فقرة أثناء القراءة واختر «أضف إلى المفضلة».'**
  String get favoritesEmptyHint;

  /// No description provided for @favoritesError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض المفضلة.'**
  String get favoritesError;

  /// No description provided for @remove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get remove;

  /// No description provided for @addedToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت إلى المفضلة'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت من المفضلة'**
  String get removedFromFavorites;

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @addToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى المفضلة'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أزل من المفضلة'**
  String get removeFromFavorites;

  /// No description provided for @inFavorites.
  ///
  /// In ar, this message translates to:
  /// **'في المفضلة'**
  String get inFavorites;

  /// No description provided for @bookNotInstalledShort.
  ///
  /// In ar, this message translates to:
  /// **'الكتاب غير محمّل'**
  String get bookNotInstalledShort;

  /// No description provided for @bookNotInstalledReader.
  ///
  /// In ar, this message translates to:
  /// **'هذا الكتاب غير محمّل على جهازك.'**
  String get bookNotInstalledReader;

  /// No description provided for @downloadWithSize.
  ///
  /// In ar, this message translates to:
  /// **'تحميل ({size})'**
  String downloadWithSize(String size);

  /// No description provided for @unavailableBook.
  ///
  /// In ar, this message translates to:
  /// **'كتاب غير متاح'**
  String get unavailableBook;

  /// No description provided for @breadcrumb.
  ///
  /// In ar, this message translates to:
  /// **'{book} ‹ {chapter}'**
  String breadcrumb(String book, String chapter);

  /// No description provided for @passageSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{source}: {text}'**
  String passageSemantics(String source, String text);

  /// No description provided for @contents.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get contents;

  /// No description provided for @displaySettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات العرض'**
  String get displaySettings;

  /// No description provided for @textSize.
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get textSize;

  /// No description provided for @decreaseTextLabel.
  ///
  /// In ar, this message translates to:
  /// **'أ−'**
  String get decreaseTextLabel;

  /// No description provided for @increaseTextLabel.
  ///
  /// In ar, this message translates to:
  /// **'أ+'**
  String get increaseTextLabel;

  /// No description provided for @decreaseText.
  ///
  /// In ar, this message translates to:
  /// **'تصغير الخط'**
  String get decreaseText;

  /// No description provided for @increaseText.
  ///
  /// In ar, this message translates to:
  /// **'تكبير الخط'**
  String get increaseText;

  /// No description provided for @textSizeLevel.
  ///
  /// In ar, this message translates to:
  /// **'المستوى {level} من {total}'**
  String textSizeLevel(String level, String total);

  /// No description provided for @textPreview.
  ///
  /// In ar, this message translates to:
  /// **'هكذا يظهر نص الكتاب بهذا الحجم.'**
  String get textPreview;

  /// No description provided for @pageColor.
  ///
  /// In ar, this message translates to:
  /// **'لون الصفحة'**
  String get pageColor;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themePaper.
  ///
  /// In ar, this message translates to:
  /// **'ورق'**
  String get themePaper;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @readerProgress.
  ///
  /// In ar, this message translates to:
  /// **'الباب {chapter} من {total} · {percent}٪'**
  String readerProgress(String chapter, String total, String percent);

  /// No description provided for @resumedHere.
  ///
  /// In ar, this message translates to:
  /// **'تابعت من حيث توقفت'**
  String get resumedHere;

  /// No description provided for @fromStart.
  ///
  /// In ar, this message translates to:
  /// **'من البداية'**
  String get fromStart;

  /// No description provided for @paragraphNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد الفقرة نفسها، فتحنا الباب الذي كانت فيه'**
  String get paragraphNotFound;

  /// No description provided for @continueReadingSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تابع القراءة: {source}. {text}'**
  String continueReadingSemantics(String source, String text);

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @textCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ النص'**
  String get textCopied;

  /// No description provided for @passageCitation.
  ///
  /// In ar, this message translates to:
  /// **'{text}\n— {book}، {author}، {chapter}'**
  String passageCitation(
    String text,
    String book,
    String author,
    String chapter,
  );

  /// No description provided for @saveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ، حاول مجدداً'**
  String get saveFailed;

  /// No description provided for @paragraphMissing.
  ///
  /// In ar, this message translates to:
  /// **'لم تعد هذه الفقرة موجودة في الكتاب'**
  String get paragraphMissing;

  /// No description provided for @searchTitle.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في الكتب… مثل: الحكمة'**
  String get searchHint;

  /// No description provided for @clearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get clearSearch;

  /// No description provided for @searchAllBooks.
  ///
  /// In ar, this message translates to:
  /// **'كل الكتب المحمّلة'**
  String get searchAllBooks;

  /// No description provided for @searchHelper.
  ///
  /// In ar, this message translates to:
  /// **'البحث يتجاهل التشكيل واختلاف الهمزات'**
  String get searchHelper;

  /// No description provided for @searchMinChars.
  ///
  /// In ar, this message translates to:
  /// **'اكتب حرفين على الأقل'**
  String get searchMinChars;

  /// No description provided for @searchNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج لـ «{query}»'**
  String searchNoResults(String query);

  /// No description provided for @searchNoResultsHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمة أقصر أو مرادفاً، أو وسّع البحث إلى كل الكتب.'**
  String get searchNoResultsHint;

  /// No description provided for @searchEverywhere.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في كل الكتب'**
  String get searchEverywhere;

  /// No description provided for @searchNoBooks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كتب على جهازك للبحث فيها.'**
  String get searchNoBooks;

  /// No description provided for @goToLibrary.
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى المكتبة'**
  String get goToLibrary;

  /// No description provided for @searchError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء البحث.'**
  String get searchError;

  /// No description provided for @searchResultCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نتيجة واحدة} =2{نتيجتان} few{{countText} نتائج} other{{countText} نتيجة}}'**
  String searchResultCount(int count, String countText);

  /// No description provided for @searchBookCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{كتاب واحد} =2{كتابين} few{{countText} كتب} other{{countText} كتاباً}}'**
  String searchBookCount(int count, String countText);

  /// No description provided for @searchSummary.
  ///
  /// In ar, this message translates to:
  /// **'{results} في {books}'**
  String searchSummary(String results, String books);

  /// No description provided for @searchSuggestionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'اقتراحات'**
  String get searchSuggestionsTitle;

  /// No description provided for @searchSuggestionWords.
  ///
  /// In ar, this message translates to:
  /// **'الحكمة|البيان|الصديق|الأسد'**
  String get searchSuggestionWords;

  /// No description provided for @searchShowMore.
  ///
  /// In ar, this message translates to:
  /// **'عرض المزيد'**
  String get searchShowMore;

  /// No description provided for @searchResultSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{chapter}، {book}. {snippet}. الكلمة المطابقة: {words}'**
  String searchResultSemantics(
    String chapter,
    String book,
    String snippet,
    String words,
  );

  /// No description provided for @searchGroupHeader.
  ///
  /// In ar, this message translates to:
  /// **'{book}، {count}'**
  String searchGroupHeader(String book, String count);

  /// No description provided for @collapse.
  ///
  /// In ar, this message translates to:
  /// **'طيّ'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In ar, this message translates to:
  /// **'توسيع'**
  String get expand;

  /// No description provided for @searchInBook.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في هذا الكتاب'**
  String get searchInBook;

  /// No description provided for @listen.
  ///
  /// In ar, this message translates to:
  /// **'استمع'**
  String get listen;

  /// No description provided for @listenFromHere.
  ///
  /// In ar, this message translates to:
  /// **'استمع من هنا'**
  String get listenFromHere;

  /// No description provided for @audioPlay.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل القراءة الصوتية'**
  String get audioPlay;

  /// No description provided for @audioPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get audioPause;

  /// No description provided for @audioNext.
  ///
  /// In ar, this message translates to:
  /// **'الفقرة التالية'**
  String get audioNext;

  /// No description provided for @audioPrevious.
  ///
  /// In ar, this message translates to:
  /// **'الفقرة السابقة'**
  String get audioPrevious;

  /// No description provided for @audioStop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الاستماع'**
  String get audioStop;

  /// No description provided for @audioMinimize.
  ///
  /// In ar, this message translates to:
  /// **'تصغير'**
  String get audioMinimize;

  /// No description provided for @audioOpenPlayer.
  ///
  /// In ar, this message translates to:
  /// **'افتح مشغّل الصوت'**
  String get audioOpenPlayer;

  /// No description provided for @audioPlayerTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشغّل الصوت'**
  String get audioPlayerTitle;

  /// No description provided for @audioPreparing.
  ///
  /// In ar, this message translates to:
  /// **'يُجهَّز الصوت…'**
  String get audioPreparing;

  /// No description provided for @audioSpeed.
  ///
  /// In ar, this message translates to:
  /// **'السرعة'**
  String get audioSpeed;

  /// No description provided for @audioSpeedValue.
  ///
  /// In ar, this message translates to:
  /// **'{speed}×'**
  String audioSpeedValue(String speed);

  /// No description provided for @audioSpeedSemantics.
  ///
  /// In ar, this message translates to:
  /// **'السرعة {speed} ضعف'**
  String audioSpeedSemantics(String speed);

  /// No description provided for @audioVoice.
  ///
  /// In ar, this message translates to:
  /// **'الصوت'**
  String get audioVoice;

  /// No description provided for @audioVoiceRow.
  ///
  /// In ar, this message translates to:
  /// **'الصوت: {voice}'**
  String audioVoiceRow(String voice);

  /// No description provided for @audioVoiceWithRegion.
  ///
  /// In ar, this message translates to:
  /// **'عربي ({region}) — صوت {number}'**
  String audioVoiceWithRegion(String region, String number);

  /// No description provided for @audioVoiceNoRegion.
  ///
  /// In ar, this message translates to:
  /// **'عربي — صوت {number}'**
  String audioVoiceNoRegion(String number);

  /// No description provided for @audioRegion.
  ///
  /// In ar, this message translates to:
  /// **'{code, select, EG{مصر} SA{السعودية} AE{الإمارات} JO{الأردن} MA{المغرب} DZ{الجزائر} TN{تونس} LB{لبنان} KW{الكويت} QA{قطر} BH{البحرين} OM{عُمان} SY{سوريا} IQ{العراق} YE{اليمن} LY{ليبيا} SD{السودان} PS{فلسطين} other{}}'**
  String audioRegion(String code);

  /// No description provided for @audioTryVoice.
  ///
  /// In ar, this message translates to:
  /// **'جرّب'**
  String get audioTryVoice;

  /// No description provided for @audioTryVoiceSemantics.
  ///
  /// In ar, this message translates to:
  /// **'جرّب {voice}'**
  String audioTryVoiceSemantics(String voice);

  /// No description provided for @audioSample.
  ///
  /// In ar, this message translates to:
  /// **'قال الجاحظ: البيان اسمٌ جامعٌ لكل شيء كشف لك قناع المعنى.'**
  String get audioSample;

  /// No description provided for @audioGoToText.
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى النص'**
  String get audioGoToText;

  /// No description provided for @audioNoVoiceTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد صوت عربي على جهازك'**
  String get audioNoVoiceTitle;

  /// No description provided for @audioNoVoiceBody.
  ///
  /// In ar, this message translates to:
  /// **'لتستمع إلى الكتب ثبّت الصوت العربي من إعدادات الهاتف: الإعدادات ← النظام ← اللغة والإدخال ← تحويل النص إلى كلام ← محرّك Google ← تثبيت بيانات الصوت ← العربية.'**
  String get audioNoVoiceBody;

  /// No description provided for @audioOpenVoiceSettings.
  ///
  /// In ar, this message translates to:
  /// **'افتح إعدادات الصوت'**
  String get audioOpenVoiceSettings;

  /// No description provided for @later.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get later;

  /// No description provided for @audioNoVoiceHelp.
  ///
  /// In ar, this message translates to:
  /// **'لم تجد الخيار؟'**
  String get audioNoVoiceHelp;

  /// No description provided for @audioNoVoiceAlternative.
  ///
  /// In ar, this message translates to:
  /// **'يختلف المسار حسب الشركة المصنّعة. ابحث في إعدادات الهاتف عن «تحويل النص إلى كلام» أو «النطق»، أو ثبّت تطبيق «خدمات Google للنطق» من متجر التطبيقات، ثم نزّل بيانات اللغة العربية واخترها.'**
  String get audioNoVoiceAlternative;

  /// No description provided for @audioEngineError.
  ///
  /// In ar, this message translates to:
  /// **'توقّف الصوت بسبب خطأ في محرّك القراءة.'**
  String get audioEngineError;

  /// No description provided for @audioBookFinished.
  ///
  /// In ar, this message translates to:
  /// **'انتهى الكتاب'**
  String get audioBookFinished;

  /// No description provided for @audioScreenReaderWarning.
  ///
  /// In ar, this message translates to:
  /// **'قد يتداخل صوت القراءة مع قارئ الشاشة. استخدم سماعة أو أوقف القراءة الصوتية مؤقتاً عند التنقل.'**
  String get audioScreenReaderWarning;

  /// No description provided for @audioBackToListening.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى موضع الاستماع'**
  String get audioBackToListening;

  /// No description provided for @audioNowReading.
  ///
  /// In ar, this message translates to:
  /// **'يُقرأ الآن'**
  String get audioNowReading;

  /// No description provided for @audioChannelName.
  ///
  /// In ar, this message translates to:
  /// **'القراءة الصوتية'**
  String get audioChannelName;

  /// No description provided for @audioNowPlayingSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'{book} — {author}'**
  String audioNowPlayingSubtitle(String book, String author);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
