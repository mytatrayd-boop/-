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
  /// **'لتستمع إلى الكتب ثبّت محرّك Google للنطق: اضغط «ثبّت صوت قوقل من المتجر» وثبّت «Speech Recognition & Synthesis from Google»، ثم افتح إعدادات الصوت: الإعدادات ← النظام ← اللغة والإدخال ← تحويل النص إلى كلام ← محرّك Google ← تثبيت بيانات الصوت ← العربية.'**
  String get audioNoVoiceBody;

  /// No description provided for @audioInstallGoogleVoice.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت صوت قوقل من المتجر'**
  String get audioInstallGoogleVoice;

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

  /// No description provided for @askTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسأل الأديب'**
  String get askTitle;

  /// No description provided for @askQuotaBadge.
  ///
  /// In ar, this message translates to:
  /// **'باقٍ لك {remaining} من {limit} اليوم'**
  String askQuotaBadge(String remaining, String limit);

  /// No description provided for @askQuotaExhausted.
  ///
  /// In ar, this message translates to:
  /// **'انتهت أسئلة اليوم'**
  String get askQuotaExhausted;

  /// No description provided for @askQuotaExplainTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأسئلة اليومية'**
  String get askQuotaExplainTitle;

  /// No description provided for @askQuotaExplain.
  ///
  /// In ar, this message translates to:
  /// **'لكل جهاز {limit} أسئلة يومياً لإبقاء الخدمة مجانية. يتجدد الرصيد كل يوم. ويُحتسب السؤال إذا وصل إلى الأديب حتى لو لم يجد الإجابة في الكتب.'**
  String askQuotaExplain(String limit);

  /// No description provided for @askQuotaExplainClose.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get askQuotaExplainClose;

  /// No description provided for @askPrivacyBanner.
  ///
  /// In ar, this message translates to:
  /// **'لا تكتب معلومات شخصية في سؤالك'**
  String get askPrivacyBanner;

  /// No description provided for @askHint.
  ///
  /// In ar, this message translates to:
  /// **'اسأل عن شيء في الكتب… مثل: ما تعريف البيان عند الجاحظ؟'**
  String get askHint;

  /// No description provided for @askFieldLabel.
  ///
  /// In ar, this message translates to:
  /// **'سؤالك'**
  String get askFieldLabel;

  /// No description provided for @askCharCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} / {max}'**
  String askCharCount(String count, String max);

  /// No description provided for @askTooLong.
  ///
  /// In ar, this message translates to:
  /// **'السؤال أطول من {max} حرف'**
  String askTooLong(String max);

  /// No description provided for @askTooShort.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سؤالاً أوضح'**
  String get askTooShort;

  /// No description provided for @askButton.
  ///
  /// In ar, this message translates to:
  /// **'اسأل'**
  String get askButton;

  /// No description provided for @askSearchTextsButton.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في النصوص'**
  String get askSearchTextsButton;

  /// No description provided for @askExamples.
  ///
  /// In ar, this message translates to:
  /// **'ما تعريف البيان عند الجاحظ؟|ماذا قال ابن المقفع عن الصديق؟|ما آداب المجالسة في أدب الدنيا والدين؟'**
  String get askExamples;

  /// No description provided for @askExamplesTitle.
  ///
  /// In ar, this message translates to:
  /// **'أمثلة'**
  String get askExamplesTitle;

  /// No description provided for @askArabicNote.
  ///
  /// In ar, this message translates to:
  /// **'الإجابات بالعربية ومقتبسة من الكتب'**
  String get askArabicNote;

  /// No description provided for @askStageSearching.
  ///
  /// In ar, this message translates to:
  /// **'يبحث في الكتب…'**
  String get askStageSearching;

  /// No description provided for @askStageAnswering.
  ///
  /// In ar, this message translates to:
  /// **'يصوغ الإجابة…'**
  String get askStageAnswering;

  /// No description provided for @askStageVerifying.
  ///
  /// In ar, this message translates to:
  /// **'يتحقق من الاقتباس…'**
  String get askStageVerifying;

  /// No description provided for @askSlow.
  ///
  /// In ar, this message translates to:
  /// **'يستغرق الأمر وقتاً أطول من المعتاد…'**
  String get askSlow;

  /// No description provided for @askCancelNote.
  ///
  /// In ar, this message translates to:
  /// **'قد يُحتسب السؤال إذا وصل إلى الخادم'**
  String get askCancelNote;

  /// No description provided for @askYourQuestion.
  ///
  /// In ar, this message translates to:
  /// **'سؤالك: {question}'**
  String askYourQuestion(String question);

  /// No description provided for @askAiLabel.
  ///
  /// In ar, this message translates to:
  /// **'إجابة مولَّدة آلياً من نص الكتاب — راجع الاقتباس'**
  String get askAiLabel;

  /// No description provided for @askQuoted.
  ///
  /// In ar, this message translates to:
  /// **'«{quote}»'**
  String askQuoted(String quote);

  /// No description provided for @askQuoteSemantics.
  ///
  /// In ar, this message translates to:
  /// **'اقتباس: {quote}'**
  String askQuoteSemantics(String quote);

  /// No description provided for @askOpenSource.
  ///
  /// In ar, this message translates to:
  /// **'افتح المصدر: {book}، {chapter}'**
  String askOpenSource(String book, String chapter);

  /// No description provided for @askNewQuestion.
  ///
  /// In ar, this message translates to:
  /// **'سؤال جديد'**
  String get askNewQuestion;

  /// No description provided for @askOtherPassages.
  ///
  /// In ar, this message translates to:
  /// **'نصوص مطابقة أخرى ({count})'**
  String askOtherPassages(String count);

  /// No description provided for @askAnswerArrived.
  ///
  /// In ar, this message translates to:
  /// **'وصلت الإجابة'**
  String get askAnswerArrived;

  /// No description provided for @askCopyCitation.
  ///
  /// In ar, this message translates to:
  /// **'«{quote}»\n— {book}، {chapter}'**
  String askCopyCitation(String quote, String book, String chapter);

  /// No description provided for @askNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم أجد هذا في الكتب المتاحة.'**
  String get askNotFound;

  /// No description provided for @askNotFoundHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب صياغة أخرى أو اختر كتاباً محدداً.'**
  String get askNotFoundHint;

  /// No description provided for @askBooksOnly.
  ///
  /// In ar, this message translates to:
  /// **'يجيب الأديب عن محتوى الكتب فقط، ولا يقدّم فتاوى.'**
  String get askBooksOnly;

  /// No description provided for @askClosestPassages.
  ///
  /// In ar, this message translates to:
  /// **'أقرب النصوص إلى سؤالك'**
  String get askClosestPassages;

  /// No description provided for @askMatchingPassages.
  ///
  /// In ar, this message translates to:
  /// **'النصوص المطابقة'**
  String get askMatchingPassages;

  /// No description provided for @askUnverified.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من التحقق من الإجابة، فإليك النصوص المطابقة مباشرة.'**
  String get askUnverified;

  /// No description provided for @askDailyLimit.
  ///
  /// In ar, this message translates to:
  /// **'انتهت أسئلة اليوم ({limit} من {limit}). يتجدد رصيدك غداً. إليك النصوص المطابقة لسؤالك من الكتب:'**
  String askDailyLimit(String limit);

  /// No description provided for @askOffline.
  ///
  /// In ar, this message translates to:
  /// **'أنت دون إنترنت. الإجابة الذكية تحتاج اتصالاً، وهذه النصوص المطابقة من كتبك المحمّلة:'**
  String get askOffline;

  /// No description provided for @askUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة غير متاحة الآن. حاول لاحقاً. إليك النصوص المطابقة:'**
  String get askUnavailable;

  /// No description provided for @askRateLimit.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت أسئلة كثيرة بسرعة. انتظر دقيقة ثم حاول.'**
  String get askRateLimit;

  /// No description provided for @askUpgrade.
  ///
  /// In ar, this message translates to:
  /// **'حدّث التطبيق لتستخدم «اسأل الأديب». إليك النصوص المطابقة:'**
  String get askUpgrade;

  /// No description provided for @askNoBooks.
  ///
  /// In ar, this message translates to:
  /// **'حمّل كتاباً واحداً على الأقل ليجيبك الأديب من نصه.'**
  String get askNoBooks;

  /// No description provided for @askNoLocalMatches.
  ///
  /// In ar, this message translates to:
  /// **'ولم نجد نصوصاً مطابقة لكلمات سؤالك.'**
  String get askNoLocalMatches;

  /// No description provided for @askBooksError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قراءة الكتب المحمّلة.'**
  String get askBooksError;

  /// No description provided for @askConsentTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل أن تسأل'**
  String get askConsentTitle;

  /// No description provided for @askConsentBooks.
  ///
  /// In ar, this message translates to:
  /// **'يجيب الأديب من نصوص الكتب المحمّلة فقط، ويذكر لك الاقتباس ومصدره.'**
  String get askConsentBooks;

  /// No description provided for @askConsentGemini.
  ///
  /// In ar, this message translates to:
  /// **'يُرسل سؤالك ومقاطع من الكتب إلى خدمة Gemini من Google لصياغة الإجابة، وقد تستخدمه Google لتحسين خدماتها.'**
  String get askConsentGemini;

  /// No description provided for @askConsentPersonal.
  ///
  /// In ar, this message translates to:
  /// **'لا تكتب معلومات شخصية في سؤالك.'**
  String get askConsentPersonal;

  /// No description provided for @askConsentNoFatwa.
  ///
  /// In ar, this message translates to:
  /// **'لا يجيب الأديب عن الفتاوى ولا عن أسئلة من خارج الكتب.'**
  String get askConsentNoFatwa;

  /// No description provided for @askConsentAge.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة لمن هم 18 سنة فأكثر.'**
  String get askConsentAge;

  /// No description provided for @askConsentConfirm.
  ///
  /// In ar, this message translates to:
  /// **'عمري 18 سنة فأكثر، فهمت'**
  String get askConsentConfirm;

  /// No description provided for @askConsentDecline.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get askConsentDecline;

  /// No description provided for @askAboutThis.
  ///
  /// In ar, this message translates to:
  /// **'اسأل الأديب عن هذا'**
  String get askAboutThis;

  /// No description provided for @askQuoteBookNotInstalled.
  ///
  /// In ar, this message translates to:
  /// **'النص المقتبس:'**
  String get askQuoteBookNotInstalled;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In ar, this message translates to:
  /// **'العامة'**
  String get settingsGeneral;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get languageSystem;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChanged.
  ///
  /// In ar, this message translates to:
  /// **'صارت الواجهة بالعربية'**
  String get languageChanged;

  /// No description provided for @settingsAppearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsAppearance;

  /// No description provided for @appearanceLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get appearanceDark;

  /// No description provided for @appearanceSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get appearanceSystem;

  /// No description provided for @settingsReading.
  ///
  /// In ar, this message translates to:
  /// **'القراءة'**
  String get settingsReading;

  /// No description provided for @settingsTextSizeAndColor.
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط ولون الصفحة'**
  String get settingsTextSizeAndColor;

  /// No description provided for @settingsListening.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع'**
  String get settingsListening;

  /// No description provided for @settingsVoiceDefault.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get settingsVoiceDefault;

  /// No description provided for @settingsResetAge.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط تأكيد العمر'**
  String get settingsResetAge;

  /// No description provided for @settingsResetAgeHint.
  ///
  /// In ar, this message translates to:
  /// **'يُطلب التأكيد مرة أخرى عند فتح «اسأل الأديب»'**
  String get settingsResetAgeHint;

  /// No description provided for @settingsResetAgeQuestion.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط تأكيد العمر؟'**
  String get settingsResetAgeQuestion;

  /// No description provided for @settingsReset.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الضبط'**
  String get settingsReset;

  /// No description provided for @settingsResetAgeDone.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد ضبط تأكيد العمر'**
  String get settingsResetAgeDone;

  /// No description provided for @settingsClearAnswer.
  ///
  /// In ar, this message translates to:
  /// **'مسح آخر إجابة'**
  String get settingsClearAnswer;

  /// No description provided for @settingsClearAnswerHint.
  ///
  /// In ar, this message translates to:
  /// **'آخر إجابة فقط محفوظة على جهازك'**
  String get settingsClearAnswerHint;

  /// No description provided for @settingsNoAnswer.
  ///
  /// In ar, this message translates to:
  /// **'لا إجابة محفوظة'**
  String get settingsNoAnswer;

  /// No description provided for @settingsClearAnswerDone.
  ///
  /// In ar, this message translates to:
  /// **'مُسحت آخر إجابة'**
  String get settingsClearAnswerDone;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get settingsAbout;

  /// No description provided for @sourcesTitle.
  ///
  /// In ar, this message translates to:
  /// **'المصادر والتراخيص'**
  String get sourcesTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In ar, this message translates to:
  /// **'عن الأديب الذكي'**
  String get aboutTitle;

  /// No description provided for @sourcesIntro.
  ///
  /// In ar, this message translates to:
  /// **'نصوص الكتب من الملك العام، مأخوذة من مشروع OpenITI (Open Islamicate Texts Initiative) الذي نقلها عن المكتبة الشاملة. حذفنا منها الحواشي ومقدمات المحققين المعاصرين وتعليقاتهم، ونذكر لكل كتاب طبعته وما حُذف منه.'**
  String get sourcesIntro;

  /// No description provided for @sourcesOpenItiLicense.
  ///
  /// In ar, this message translates to:
  /// **'ملفات OpenITI منشورة بترخيص CC BY-NC-SA 4.0 (نسبة العمل إلى صاحبه، غير تجاري، المشاركة بالمثل)، ونعيد نشر الملفات المحوّلة بالترخيص نفسه.'**
  String get sourcesOpenItiLicense;

  /// No description provided for @sourcesBooks.
  ///
  /// In ar, this message translates to:
  /// **'الكتب'**
  String get sourcesBooks;

  /// No description provided for @sourcesNoBooks.
  ///
  /// In ar, this message translates to:
  /// **'تظهر الكتب هنا بعد تحميل قائمتها.'**
  String get sourcesNoBooks;

  /// No description provided for @sourcesSourceLabel.
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get sourcesSourceLabel;

  /// No description provided for @sourcesOriginalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الأصل'**
  String get sourcesOriginalLabel;

  /// No description provided for @sourcesEditionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الطبعة'**
  String get sourcesEditionLabel;

  /// No description provided for @sourcesRemovedLabel.
  ///
  /// In ar, this message translates to:
  /// **'ما حُذف'**
  String get sourcesRemovedLabel;

  /// No description provided for @sourcesLicenseLabel.
  ///
  /// In ar, this message translates to:
  /// **'الترخيص'**
  String get sourcesLicenseLabel;

  /// No description provided for @sourcesFileVersionLabel.
  ///
  /// In ar, this message translates to:
  /// **'إصدار الملف'**
  String get sourcesFileVersionLabel;

  /// No description provided for @sourcesLinkLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرابط'**
  String get sourcesLinkLabel;

  /// No description provided for @sourcesDetailsAfterDownload.
  ///
  /// In ar, this message translates to:
  /// **'تظهر الطبعة وما حُذف بعد تحميل الكتاب.'**
  String get sourcesDetailsAfterDownload;

  /// No description provided for @sourcesCopyLink.
  ///
  /// In ar, this message translates to:
  /// **'انسخ الرابط'**
  String get sourcesCopyLink;

  /// No description provided for @sourcesCopyLinkSemantics.
  ///
  /// In ar, this message translates to:
  /// **'انسخ رابط مصدر {book}'**
  String sourcesCopyLinkSemantics(String book);

  /// No description provided for @sourcesLinkCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الرابط'**
  String get sourcesLinkCopied;

  /// No description provided for @sourcesFonts.
  ///
  /// In ar, this message translates to:
  /// **'الخطوط'**
  String get sourcesFonts;

  /// No description provided for @fontAmiri.
  ///
  /// In ar, this message translates to:
  /// **'Amiri'**
  String get fontAmiri;

  /// No description provided for @fontIbmPlex.
  ///
  /// In ar, this message translates to:
  /// **'IBM Plex Sans Arabic'**
  String get fontIbmPlex;

  /// No description provided for @sourcesFontLicense.
  ///
  /// In ar, this message translates to:
  /// **'SIL Open Font License 1.1'**
  String get sourcesFontLicense;

  /// No description provided for @sourcesViewLicense.
  ///
  /// In ar, this message translates to:
  /// **'عرض الترخيص'**
  String get sourcesViewLicense;

  /// No description provided for @sourcesViewLicenseSemantics.
  ///
  /// In ar, this message translates to:
  /// **'عرض ترخيص خط {font}'**
  String sourcesViewLicenseSemantics(String font);

  /// No description provided for @fontLicenseTitle.
  ///
  /// In ar, this message translates to:
  /// **'ترخيص {font}'**
  String fontLicenseTitle(String font);

  /// No description provided for @sourcesServices.
  ///
  /// In ar, this message translates to:
  /// **'الخدمات'**
  String get sourcesServices;

  /// No description provided for @sourcesServiceAi.
  ///
  /// In ar, this message translates to:
  /// **'الإجابات الذكية: Gemini من Google عبر خادم وسيط'**
  String get sourcesServiceAi;

  /// No description provided for @sourcesServiceTts.
  ///
  /// In ar, this message translates to:
  /// **'القراءة الصوتية: محرّك الصوت في جهازك'**
  String get sourcesServiceTts;

  /// No description provided for @sourcesServiceHosting.
  ///
  /// In ar, this message translates to:
  /// **'استضافة الكتب: GitHub'**
  String get sourcesServiceHosting;

  /// No description provided for @sourcesLibraries.
  ///
  /// In ar, this message translates to:
  /// **'المكتبات البرمجية'**
  String get sourcesLibraries;

  /// No description provided for @sourcesViewLibraries.
  ///
  /// In ar, this message translates to:
  /// **'عرض تراخيص المكتبات'**
  String get sourcesViewLibraries;

  /// No description provided for @privacyIntro.
  ///
  /// In ar, this message translates to:
  /// **'خلاصة ما يحدث لبياناتك في «الأديب الذكي»، بلغة بسيطة.'**
  String get privacyIntro;

  /// No description provided for @privacyAccountTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا حساب'**
  String get privacyAccountTitle;

  /// No description provided for @privacyAccountBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يطلب التطبيق حساباً ولا اسماً ولا بريداً ولا رقم هاتف.'**
  String get privacyAccountBody;

  /// No description provided for @privacyLocalTitle.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك على جهازك'**
  String get privacyLocalTitle;

  /// No description provided for @privacyLocalBody.
  ///
  /// In ar, this message translates to:
  /// **'الكتب المحمّلة والمفضلة وآخر موضع قراءة وإعداداتك وآخر إجابة من «اسأل الأديب» محفوظة على جهازك فقط. القراءة والبحث والاستماع تعمل دون إنترنت، والقراءة الصوتية بمحرّك الصوت في جهازك.'**
  String get privacyLocalBody;

  /// No description provided for @privacyAskTitle.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة «اسأل الأديب»'**
  String get privacyAskTitle;

  /// No description provided for @privacyAskBody.
  ///
  /// In ar, this message translates to:
  /// **'عندما تسأل، يُرسل سؤالك ومقاطع من الكتب المحمّلة إلى خادمنا، ثم إلى خدمة Gemini من Google لصياغة الإجابة. قد تستخدم Google ما يُرسل إليها لتحسين خدماتها، وقد يراجعه مراجعون بشريون. خادمنا لا يحفظ نص سؤالك.'**
  String get privacyAskBody;

  /// No description provided for @privacyPersonalTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا تكتب معلومات شخصية'**
  String get privacyPersonalTitle;

  /// No description provided for @privacyPersonalBody.
  ///
  /// In ar, this message translates to:
  /// **'لا تكتب في سؤالك اسمك أو بيانات تواصلك أو أي معلومة شخصية أو سرية.'**
  String get privacyPersonalBody;

  /// No description provided for @privacyDeviceTitle.
  ///
  /// In ar, this message translates to:
  /// **'معرّف عشوائي للجهاز'**
  String get privacyDeviceTitle;

  /// No description provided for @privacyDeviceBody.
  ///
  /// In ar, this message translates to:
  /// **'يُنشئ التطبيق معرّفاً عشوائياً يُحفظ على جهازك، ويُرسل مع الأسئلة لحساب الحد اليومي فقط، ولا يرتبط بهويتك ولا بمعرّفات النظام. يرى خادمنا (على Cloudflare) عنوان IP لجهازك، ويحفظ منه ومن المعرّف قيمة مشفّرة لا تُعكس (HMAC) في عدّادات الحد اليومي ليوم واحد فقط، ثم تُحذف. ولا يحفظ المعرّف ولا عنوان IP كما هما.'**
  String get privacyDeviceBody;

  /// No description provided for @privacyAgeTitle.
  ///
  /// In ar, this message translates to:
  /// **'«اسأل الأديب» لمن هم 18 سنة فأكثر'**
  String get privacyAgeTitle;

  /// No description provided for @privacyAgeBody.
  ///
  /// In ar, this message translates to:
  /// **'شروط خدمة Gemini تشترط 18 سنة فأكثر، فيُطلب تأكيد العمر قبل أول سؤال. القراءة والبحث والاستماع متاحة للجميع.'**
  String get privacyAgeBody;

  /// No description provided for @privacyNetworkTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاتصالات'**
  String get privacyNetworkTitle;

  /// No description provided for @privacyNetworkBody.
  ///
  /// In ar, this message translates to:
  /// **'يتصل التطبيق بـ GitHub لتحميل قائمة الكتب وملفاتها، وبخادمنا عند استخدام «اسأل الأديب» فقط، وكل ذلك عبر HTTPS.'**
  String get privacyNetworkBody;

  /// No description provided for @privacyAdsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا إعلانات ولا تتبع'**
  String get privacyAdsTitle;

  /// No description provided for @privacyAdsBody.
  ///
  /// In ar, this message translates to:
  /// **'لا إعلانات ولا تحليلات ولا تقارير أعطال ولا أي تتبع.'**
  String get privacyAdsBody;

  /// No description provided for @privacyControlTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحكم في بياناتك'**
  String get privacyControlTitle;

  /// No description provided for @privacyControlBody.
  ///
  /// In ar, this message translates to:
  /// **'من الإعدادات يمكنك مسح آخر إجابة وإعادة ضبط تأكيد العمر. وحذف التطبيق يحذف كل بياناته من جهازك.'**
  String get privacyControlBody;

  /// No description provided for @askConsentPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'اقرأ سياسة الخصوصية'**
  String get askConsentPrivacy;

  /// No description provided for @aboutLogoLabel.
  ///
  /// In ar, this message translates to:
  /// **'شعار الأديب الذكي'**
  String get aboutLogoLabel;

  /// No description provided for @aboutDescription.
  ///
  /// In ar, this message translates to:
  /// **'قراءة كتب الأدب العربي التراثي والبحث فيها والاستماع إليها دون إنترنت، مع «اسأل الأديب» الذي يجيب من نصوص الكتب باقتباس ومصدر.'**
  String get aboutDescription;

  /// No description provided for @aboutFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني بلا إعلانات ولا اشتراكات ولا حساب.'**
  String get aboutFree;

  /// No description provided for @licenseLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض الترخيص.'**
  String get licenseLoadError;

  /// No description provided for @sourcesOpenItiLink.
  ///
  /// In ar, this message translates to:
  /// **'مشروع OpenITI'**
  String get sourcesOpenItiLink;

  /// No description provided for @sourcesLicenseLink.
  ///
  /// In ar, this message translates to:
  /// **'نص ترخيص CC BY-NC-SA 4.0'**
  String get sourcesLicenseLink;

  /// No description provided for @sourcesCopyNamedLinkSemantics.
  ///
  /// In ar, this message translates to:
  /// **'انسخ رابط {name}'**
  String sourcesCopyNamedLinkSemantics(String name);
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
