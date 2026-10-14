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

  @override
  String get downloading => 'يُحمَّل…';

  @override
  String get listSeparator => '، ';

  @override
  String downloadAnnouncement(String title, String percent) {
    return '«$title»: يُحمَّل… $percent٪';
  }

  @override
  String get startReading => 'ابدأ القراءة';

  @override
  String get continueReading => 'تابع القراءة';

  @override
  String reachedPosition(String chapter, String percent) {
    return 'وصلت إلى: $chapter — $percent٪';
  }

  @override
  String get youAreHere => 'أنت هنا';

  @override
  String chapterHereSemantics(String chapter) {
    return '$chapter، أنت هنا';
  }

  @override
  String get booksTab => 'الكتب';

  @override
  String get favoritesTab => 'المفضلة';

  @override
  String get favoritesEmptyTitle => 'لا توجد فقرات في المفضلة بعد.';

  @override
  String get favoritesEmptyHint =>
      'اضغط مطوّلاً على أي فقرة أثناء القراءة واختر «أضف إلى المفضلة».';

  @override
  String get favoritesError => 'تعذّر عرض المفضلة.';

  @override
  String get remove => 'إزالة';

  @override
  String get addedToFavorites => 'أُضيفت إلى المفضلة';

  @override
  String get removedFromFavorites => 'أُزيلت من المفضلة';

  @override
  String get undo => 'تراجع';

  @override
  String get addToFavorites => 'أضف إلى المفضلة';

  @override
  String get removeFromFavorites => 'أزل من المفضلة';

  @override
  String get inFavorites => 'في المفضلة';

  @override
  String get bookNotInstalledShort => 'الكتاب غير محمّل';

  @override
  String get bookNotInstalledReader => 'هذا الكتاب غير محمّل على جهازك.';

  @override
  String downloadWithSize(String size) {
    return 'تحميل ($size)';
  }

  @override
  String get unavailableBook => 'كتاب غير متاح';

  @override
  String breadcrumb(String book, String chapter) {
    return '$book ‹ $chapter';
  }

  @override
  String passageSemantics(String source, String text) {
    return '$source: $text';
  }

  @override
  String get contents => 'الفهرس';

  @override
  String get displaySettings => 'إعدادات العرض';

  @override
  String get textSize => 'حجم الخط';

  @override
  String get decreaseTextLabel => 'أ−';

  @override
  String get increaseTextLabel => 'أ+';

  @override
  String get decreaseText => 'تصغير الخط';

  @override
  String get increaseText => 'تكبير الخط';

  @override
  String textSizeLevel(String level, String total) {
    return 'المستوى $level من $total';
  }

  @override
  String get textPreview => 'هكذا يظهر نص الكتاب بهذا الحجم.';

  @override
  String get pageColor => 'لون الصفحة';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themePaper => 'ورق';

  @override
  String get themeDark => 'داكن';

  @override
  String readerProgress(String chapter, String total, String percent) {
    return 'الباب $chapter من $total · $percent٪';
  }

  @override
  String get resumedHere => 'تابعت من حيث توقفت';

  @override
  String get fromStart => 'من البداية';

  @override
  String get paragraphNotFound =>
      'لم نجد الفقرة نفسها، فتحنا الباب الذي كانت فيه';

  @override
  String continueReadingSemantics(String source, String text) {
    return 'تابع القراءة: $source. $text';
  }

  @override
  String get copy => 'نسخ';

  @override
  String get share => 'مشاركة';

  @override
  String get textCopied => 'نُسخ النص';

  @override
  String passageCitation(
    String text,
    String book,
    String author,
    String chapter,
  ) {
    return '$text\n— $book، $author، $chapter';
  }

  @override
  String get saveFailed => 'تعذّر الحفظ، حاول مجدداً';

  @override
  String get paragraphMissing => 'لم تعد هذه الفقرة موجودة في الكتاب';

  @override
  String get searchTitle => 'البحث';

  @override
  String get searchHint => 'ابحث في الكتب… مثل: الحكمة';

  @override
  String get clearSearch => 'مسح';

  @override
  String get searchAllBooks => 'كل الكتب المحمّلة';

  @override
  String get searchHelper => 'البحث يتجاهل التشكيل واختلاف الهمزات';

  @override
  String get searchMinChars => 'اكتب حرفين على الأقل';

  @override
  String searchNoResults(String query) {
    return 'لا توجد نتائج لـ «$query»';
  }

  @override
  String get searchNoResultsHint =>
      'جرّب كلمة أقصر أو مرادفاً، أو وسّع البحث إلى كل الكتب.';

  @override
  String get searchEverywhere => 'ابحث في كل الكتب';

  @override
  String get searchNoBooks => 'لا توجد كتب على جهازك للبحث فيها.';

  @override
  String get goToLibrary => 'اذهب إلى المكتبة';

  @override
  String get searchError => 'حدث خطأ أثناء البحث.';

  @override
  String searchResultCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText نتيجة',
      few: '$countText نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String searchBookCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText كتاباً',
      few: '$countText كتب',
      two: 'كتابين',
      one: 'كتاب واحد',
    );
    return '$_temp0';
  }

  @override
  String searchSummary(String results, String books) {
    return '$results في $books';
  }

  @override
  String get searchSuggestionsTitle => 'اقتراحات';

  @override
  String get searchSuggestionWords => 'الحكمة|البيان|الصديق|الأسد';

  @override
  String get searchShowMore => 'عرض المزيد';

  @override
  String searchResultSemantics(
    String chapter,
    String book,
    String snippet,
    String words,
  ) {
    return '$chapter، $book. $snippet. الكلمة المطابقة: $words';
  }

  @override
  String searchGroupHeader(String book, String count) {
    return '$book، $count';
  }

  @override
  String get collapse => 'طيّ';

  @override
  String get expand => 'توسيع';

  @override
  String get searchInBook => 'ابحث في هذا الكتاب';

  @override
  String get listen => 'استمع';

  @override
  String get listenFromHere => 'استمع من هنا';

  @override
  String get audioPlay => 'تشغيل القراءة الصوتية';

  @override
  String get audioPause => 'إيقاف مؤقت';

  @override
  String get audioNext => 'الفقرة التالية';

  @override
  String get audioPrevious => 'الفقرة السابقة';

  @override
  String get audioStop => 'إيقاف الاستماع';

  @override
  String get audioMinimize => 'تصغير';

  @override
  String get audioOpenPlayer => 'افتح مشغّل الصوت';

  @override
  String get audioPlayerTitle => 'مشغّل الصوت';

  @override
  String get audioPreparing => 'يُجهَّز الصوت…';

  @override
  String get audioSpeed => 'السرعة';

  @override
  String audioSpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String audioSpeedSemantics(String speed) {
    return 'السرعة $speed ضعف';
  }

  @override
  String get audioVoice => 'الصوت';

  @override
  String audioVoiceRow(String voice) {
    return 'الصوت: $voice';
  }

  @override
  String audioVoiceWithRegion(String region, String number) {
    return 'عربي ($region) — صوت $number';
  }

  @override
  String audioVoiceNoRegion(String number) {
    return 'عربي — صوت $number';
  }

  @override
  String audioRegion(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'EG': 'مصر',
      'SA': 'السعودية',
      'AE': 'الإمارات',
      'JO': 'الأردن',
      'MA': 'المغرب',
      'DZ': 'الجزائر',
      'TN': 'تونس',
      'LB': 'لبنان',
      'KW': 'الكويت',
      'QA': 'قطر',
      'BH': 'البحرين',
      'OM': 'عُمان',
      'SY': 'سوريا',
      'IQ': 'العراق',
      'YE': 'اليمن',
      'LY': 'ليبيا',
      'SD': 'السودان',
      'PS': 'فلسطين',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get audioTryVoice => 'جرّب';

  @override
  String audioTryVoiceSemantics(String voice) {
    return 'جرّب $voice';
  }

  @override
  String get audioSample =>
      'قال الجاحظ: البيان اسمٌ جامعٌ لكل شيء كشف لك قناع المعنى.';

  @override
  String get audioGoToText => 'اذهب إلى النص';

  @override
  String get audioNoVoiceTitle => 'لا يوجد صوت عربي على جهازك';

  @override
  String get audioNoVoiceBody =>
      'لتستمع إلى الكتب ثبّت الصوت العربي من إعدادات الهاتف: الإعدادات ← النظام ← اللغة والإدخال ← تحويل النص إلى كلام ← محرّك Google ← تثبيت بيانات الصوت ← العربية.';

  @override
  String get audioOpenVoiceSettings => 'افتح إعدادات الصوت';

  @override
  String get later => 'لاحقاً';

  @override
  String get audioNoVoiceHelp => 'لم تجد الخيار؟';

  @override
  String get audioNoVoiceAlternative =>
      'يختلف المسار حسب الشركة المصنّعة. ابحث في إعدادات الهاتف عن «تحويل النص إلى كلام» أو «النطق»، أو ثبّت تطبيق «خدمات Google للنطق» من متجر التطبيقات، ثم نزّل بيانات اللغة العربية واخترها.';

  @override
  String get audioEngineError => 'توقّف الصوت بسبب خطأ في محرّك القراءة.';

  @override
  String get audioBookFinished => 'انتهى الكتاب';

  @override
  String get audioScreenReaderWarning =>
      'قد يتداخل صوت القراءة مع قارئ الشاشة. استخدم سماعة أو أوقف القراءة الصوتية مؤقتاً عند التنقل.';

  @override
  String get audioBackToListening => 'العودة إلى موضع الاستماع';

  @override
  String get audioNowReading => 'يُقرأ الآن';

  @override
  String get audioChannelName => 'القراءة الصوتية';

  @override
  String audioNowPlayingSubtitle(String book, String author) {
    return '$book — $author';
  }

  @override
  String get askTitle => 'اسأل الأديب';

  @override
  String askQuotaBadge(String remaining, String limit) {
    return 'باقٍ لك $remaining من $limit اليوم';
  }

  @override
  String get askQuotaExhausted => 'انتهت أسئلة اليوم';

  @override
  String get askQuotaExplainTitle => 'الأسئلة اليومية';

  @override
  String askQuotaExplain(String limit) {
    return 'لكل جهاز $limit أسئلة يومياً لإبقاء الخدمة مجانية. يتجدد الرصيد كل يوم. ويُحتسب السؤال إذا وصل إلى الأديب حتى لو لم يجد الإجابة في الكتب.';
  }

  @override
  String get askQuotaExplainClose => 'حسناً';

  @override
  String get askPrivacyBanner => 'لا تكتب معلومات شخصية في سؤالك';

  @override
  String get askHint =>
      'اسأل عن شيء في الكتب… مثل: ما تعريف البيان عند الجاحظ؟';

  @override
  String get askFieldLabel => 'سؤالك';

  @override
  String askCharCount(String count, String max) {
    return '$count / $max';
  }

  @override
  String askTooLong(String max) {
    return 'السؤال أطول من $max حرف';
  }

  @override
  String get askTooShort => 'اكتب سؤالاً أوضح';

  @override
  String get askButton => 'اسأل';

  @override
  String get askSearchTextsButton => 'ابحث في النصوص';

  @override
  String get askExamples =>
      'ما تعريف البيان عند الجاحظ؟|ماذا قال ابن المقفع عن الصديق؟|ما آداب المجالسة في أدب الدنيا والدين؟';

  @override
  String get askExamplesTitle => 'أمثلة';

  @override
  String get askArabicNote => 'الإجابات بالعربية ومقتبسة من الكتب';

  @override
  String get askStageSearching => 'يبحث في الكتب…';

  @override
  String get askStageAnswering => 'يصوغ الإجابة…';

  @override
  String get askStageVerifying => 'يتحقق من الاقتباس…';

  @override
  String get askSlow => 'يستغرق الأمر وقتاً أطول من المعتاد…';

  @override
  String get askCancelNote => 'قد يُحتسب السؤال إذا وصل إلى الخادم';

  @override
  String askYourQuestion(String question) {
    return 'سؤالك: $question';
  }

  @override
  String get askAiLabel => 'إجابة مولَّدة آلياً من نص الكتاب — راجع الاقتباس';

  @override
  String askQuoted(String quote) {
    return '«$quote»';
  }

  @override
  String askQuoteSemantics(String quote) {
    return 'اقتباس: $quote';
  }

  @override
  String askOpenSource(String book, String chapter) {
    return 'افتح المصدر: $book، $chapter';
  }

  @override
  String get askNewQuestion => 'سؤال جديد';

  @override
  String askOtherPassages(String count) {
    return 'نصوص مطابقة أخرى ($count)';
  }

  @override
  String get askAnswerArrived => 'وصلت الإجابة';

  @override
  String askCopyCitation(String quote, String book, String chapter) {
    return '«$quote»\n— $book، $chapter';
  }

  @override
  String get askNotFound => 'لم أجد هذا في الكتب المتاحة.';

  @override
  String get askNotFoundHint => 'جرّب صياغة أخرى أو اختر كتاباً محدداً.';

  @override
  String get askBooksOnly => 'يجيب الأديب عن محتوى الكتب فقط، ولا يقدّم فتاوى.';

  @override
  String get askClosestPassages => 'أقرب النصوص إلى سؤالك';

  @override
  String get askMatchingPassages => 'النصوص المطابقة';

  @override
  String get askUnverified =>
      'لم نتمكن من التحقق من الإجابة، فإليك النصوص المطابقة مباشرة.';

  @override
  String askDailyLimit(String limit) {
    return 'انتهت أسئلة اليوم ($limit من $limit). يتجدد رصيدك غداً. إليك النصوص المطابقة لسؤالك من الكتب:';
  }

  @override
  String get askOffline =>
      'أنت دون إنترنت. الإجابة الذكية تحتاج اتصالاً، وهذه النصوص المطابقة من كتبك المحمّلة:';

  @override
  String get askUnavailable =>
      'الخدمة غير متاحة الآن. حاول لاحقاً. إليك النصوص المطابقة:';

  @override
  String get askRateLimit => 'أرسلت أسئلة كثيرة بسرعة. انتظر دقيقة ثم حاول.';

  @override
  String get askUpgrade =>
      'حدّث التطبيق لتستخدم «اسأل الأديب». إليك النصوص المطابقة:';

  @override
  String get askNoBooks => 'حمّل كتاباً واحداً على الأقل ليجيبك الأديب من نصه.';

  @override
  String get askNoLocalMatches => 'ولم نجد نصوصاً مطابقة لكلمات سؤالك.';

  @override
  String get askBooksError => 'تعذّر قراءة الكتب المحمّلة.';

  @override
  String get askConsentTitle => 'قبل أن تسأل';

  @override
  String get askConsentBooks =>
      'يجيب الأديب من نصوص الكتب المحمّلة فقط، ويذكر لك الاقتباس ومصدره.';

  @override
  String get askConsentGemini =>
      'يُرسل سؤالك ومقاطع من الكتب إلى خدمة Gemini من Google لصياغة الإجابة، وقد تستخدمه Google لتحسين خدماتها.';

  @override
  String get askConsentPersonal => 'لا تكتب معلومات شخصية في سؤالك.';

  @override
  String get askConsentNoFatwa =>
      'لا يجيب الأديب عن الفتاوى ولا عن أسئلة من خارج الكتب.';

  @override
  String get askConsentAge => 'هذه الميزة لمن هم 18 سنة فأكثر.';

  @override
  String get askConsentConfirm => 'عمري 18 سنة فأكثر، فهمت';

  @override
  String get askConsentDecline => 'ليس الآن';

  @override
  String get askAboutThis => 'اسأل الأديب عن هذا';

  @override
  String get askQuoteBookNotInstalled => 'النص المقتبس:';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsGeneral => 'العامة';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get languageSystem => 'حسب الجهاز';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChanged => 'صارت الواجهة بالعربية';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get appearanceLight => 'فاتح';

  @override
  String get appearanceDark => 'داكن';

  @override
  String get appearanceSystem => 'حسب الجهاز';

  @override
  String get settingsReading => 'القراءة';

  @override
  String get settingsTextSizeAndColor => 'حجم الخط ولون الصفحة';

  @override
  String get settingsListening => 'الاستماع';

  @override
  String get settingsVoiceDefault => 'تلقائي';

  @override
  String get settingsResetAge => 'إعادة ضبط تأكيد العمر';

  @override
  String get settingsResetAgeHint =>
      'يُطلب التأكيد مرة أخرى عند فتح «اسأل الأديب»';

  @override
  String get settingsResetAgeQuestion => 'إعادة ضبط تأكيد العمر؟';

  @override
  String get settingsReset => 'إعادة الضبط';

  @override
  String get settingsResetAgeDone => 'أُعيد ضبط تأكيد العمر';

  @override
  String get settingsClearAnswer => 'مسح آخر إجابة';

  @override
  String get settingsClearAnswerHint => 'آخر إجابة فقط محفوظة على جهازك';

  @override
  String get settingsNoAnswer => 'لا إجابة محفوظة';

  @override
  String get settingsClearAnswerDone => 'مُسحت آخر إجابة';

  @override
  String get settingsAbout => 'عن التطبيق';

  @override
  String get sourcesTitle => 'المصادر والتراخيص';

  @override
  String get privacyTitle => 'سياسة الخصوصية';

  @override
  String get aboutTitle => 'عن الأديب الذكي';

  @override
  String get sourcesIntro =>
      'نصوص الكتب من الملك العام، مأخوذة من مشروع OpenITI (Open Islamicate Texts Initiative) الذي نقلها عن المكتبة الشاملة. حذفنا منها الحواشي ومقدمات المحققين المعاصرين وتعليقاتهم، ونذكر لكل كتاب طبعته وما حُذف منه.';

  @override
  String get sourcesOpenItiLicense =>
      'ملفات OpenITI منشورة بترخيص CC BY-NC-SA 4.0 (نسبة العمل إلى صاحبه، غير تجاري، المشاركة بالمثل)، ونعيد نشر الملفات المحوّلة بالترخيص نفسه.';

  @override
  String get sourcesBooks => 'الكتب';

  @override
  String get sourcesNoBooks => 'تظهر الكتب هنا بعد تحميل قائمتها.';

  @override
  String get sourcesSourceLabel => 'المصدر';

  @override
  String get sourcesOriginalLabel => 'الأصل';

  @override
  String get sourcesEditionLabel => 'الطبعة';

  @override
  String get sourcesRemovedLabel => 'ما حُذف';

  @override
  String get sourcesLicenseLabel => 'الترخيص';

  @override
  String get sourcesFileVersionLabel => 'إصدار الملف';

  @override
  String get sourcesLinkLabel => 'الرابط';

  @override
  String get sourcesDetailsAfterDownload =>
      'تظهر الطبعة وما حُذف بعد تحميل الكتاب.';

  @override
  String get sourcesCopyLink => 'انسخ الرابط';

  @override
  String sourcesCopyLinkSemantics(String book) {
    return 'انسخ رابط مصدر $book';
  }

  @override
  String get sourcesLinkCopied => 'نُسخ الرابط';

  @override
  String get sourcesFonts => 'الخطوط';

  @override
  String get fontAmiri => 'Amiri';

  @override
  String get fontIbmPlex => 'IBM Plex Sans Arabic';

  @override
  String get sourcesFontLicense => 'SIL Open Font License 1.1';

  @override
  String get sourcesViewLicense => 'عرض الترخيص';

  @override
  String sourcesViewLicenseSemantics(String font) {
    return 'عرض ترخيص خط $font';
  }

  @override
  String fontLicenseTitle(String font) {
    return 'ترخيص $font';
  }

  @override
  String get sourcesServices => 'الخدمات';

  @override
  String get sourcesServiceAi =>
      'الإجابات الذكية: Gemini من Google عبر خادم وسيط';

  @override
  String get sourcesServiceTts => 'القراءة الصوتية: محرّك الصوت في جهازك';

  @override
  String get sourcesServiceHosting => 'استضافة الكتب: GitHub';

  @override
  String get sourcesLibraries => 'المكتبات البرمجية';

  @override
  String get sourcesViewLibraries => 'عرض تراخيص المكتبات';

  @override
  String get privacyIntro =>
      'خلاصة ما يحدث لبياناتك في «الأديب الذكي»، بلغة بسيطة.';

  @override
  String get privacyAccountTitle => 'لا حساب';

  @override
  String get privacyAccountBody =>
      'لا يطلب التطبيق حساباً ولا اسماً ولا بريداً ولا رقم هاتف.';

  @override
  String get privacyLocalTitle => 'بياناتك على جهازك';

  @override
  String get privacyLocalBody =>
      'الكتب المحمّلة والمفضلة وآخر موضع قراءة وإعداداتك وآخر إجابة من «اسأل الأديب» محفوظة على جهازك فقط. القراءة والبحث والاستماع تعمل دون إنترنت، والقراءة الصوتية بمحرّك الصوت في جهازك.';

  @override
  String get privacyAskTitle => 'أسئلة «اسأل الأديب»';

  @override
  String get privacyAskBody =>
      'عندما تسأل، يُرسل سؤالك ومقاطع من الكتب المحمّلة إلى خادمنا، ثم إلى خدمة Gemini من Google لصياغة الإجابة. قد تستخدم Google ما يُرسل إليها لتحسين خدماتها، وقد يراجعه مراجعون بشريون. خادمنا لا يحفظ نص سؤالك.';

  @override
  String get privacyPersonalTitle => 'لا تكتب معلومات شخصية';

  @override
  String get privacyPersonalBody =>
      'لا تكتب في سؤالك اسمك أو بيانات تواصلك أو أي معلومة شخصية أو سرية.';

  @override
  String get privacyDeviceTitle => 'معرّف عشوائي للجهاز';

  @override
  String get privacyDeviceBody =>
      'يُنشئ التطبيق معرّفاً عشوائياً يُحفظ على جهازك، ويُرسل مع الأسئلة لحساب الحد اليومي فقط، ولا يرتبط بهويتك ولا بمعرّفات النظام. يرى خادمنا (على Cloudflare) عنوان IP لجهازك، ويحفظ منه ومن المعرّف قيمة مشفّرة لا تُعكس (HMAC) في عدّادات الحد اليومي ليوم واحد فقط، ثم تُحذف. ولا يحفظ المعرّف ولا عنوان IP كما هما.';

  @override
  String get privacyAgeTitle => '«اسأل الأديب» لمن هم 18 سنة فأكثر';

  @override
  String get privacyAgeBody =>
      'شروط خدمة Gemini تشترط 18 سنة فأكثر، فيُطلب تأكيد العمر قبل أول سؤال. القراءة والبحث والاستماع متاحة للجميع.';

  @override
  String get privacyNetworkTitle => 'الاتصالات';

  @override
  String get privacyNetworkBody =>
      'يتصل التطبيق بـ GitHub لتحميل قائمة الكتب وملفاتها، وبخادمنا عند استخدام «اسأل الأديب» فقط، وكل ذلك عبر HTTPS.';

  @override
  String get privacyAdsTitle => 'لا إعلانات ولا تتبع';

  @override
  String get privacyAdsBody =>
      'لا إعلانات ولا تحليلات ولا تقارير أعطال ولا أي تتبع.';

  @override
  String get privacyControlTitle => 'التحكم في بياناتك';

  @override
  String get privacyControlBody =>
      'من الإعدادات يمكنك مسح آخر إجابة وإعادة ضبط تأكيد العمر. وحذف التطبيق يحذف كل بياناته من جهازك.';

  @override
  String get askConsentPrivacy => 'اقرأ سياسة الخصوصية';

  @override
  String get aboutLogoLabel => 'شعار الأديب الذكي';

  @override
  String get aboutDescription =>
      'قراءة كتب الأدب العربي التراثي والبحث فيها والاستماع إليها دون إنترنت، مع «اسأل الأديب» الذي يجيب من نصوص الكتب باقتباس ومصدر.';

  @override
  String get aboutFree => 'مجاني بلا إعلانات ولا اشتراكات ولا حساب.';

  @override
  String get licenseLoadError => 'تعذّر عرض الترخيص.';

  @override
  String get sourcesOpenItiLink => 'مشروع OpenITI';

  @override
  String get sourcesLicenseLink => 'نص ترخيص CC BY-NC-SA 4.0';

  @override
  String sourcesCopyNamedLinkSemantics(String name) {
    return 'انسخ رابط $name';
  }
}
