// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Adeeb AI';

  @override
  String get libraryTitle => 'Library';

  @override
  String get download => 'Download';

  @override
  String downloadingPercent(String percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get redownload => 'Download again';

  @override
  String get open => 'Open';

  @override
  String get installed => 'Downloaded';

  @override
  String get notInstalled => 'Not downloaded';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get update => 'Update';

  @override
  String get preparing => 'Preparing for search…';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadInterrupted => 'Connection lost during download';

  @override
  String get fileCorrupt => 'The file is damaged. Download it again.';

  @override
  String get needsConnection => 'Needs a connection';

  @override
  String get offlineBanner =>
      'You\'re offline — downloaded books are available';

  @override
  String get staleCatalogBanner => 'The list may not be up to date';

  @override
  String get updateAppBanner =>
      'The book list uses a newer format than this version. Update the app to see new books.';

  @override
  String get offlineFirstRunTitle => 'You need a connection to download books';

  @override
  String get offlineFirstRunBody =>
      'Connect to the internet once to load the book list. After that you can read, search and listen offline.';

  @override
  String get catalogError =>
      'Couldn\'t load the book list. Check your connection and try again.';

  @override
  String get emptyLibrary => 'No books are available yet.';

  @override
  String get loading => 'Loading';

  @override
  String get deleteFromDevice => 'Remove from device';

  @override
  String get deleteDialogTitle => 'Remove book from device?';

  @override
  String deleteDialogBody(String title, String size) {
    return '“$title” will be removed from your device, freeing $size. Your favorites and last position are kept, and you can download it again at any time.';
  }

  @override
  String get delete => 'Remove';

  @override
  String get bookDeleted => 'Book removed';

  @override
  String get deleteFailed => 'Couldn\'t remove the book';

  @override
  String get bookUpdated => 'Book updated';

  @override
  String sizeMb(String size) {
    return '$size MB';
  }

  @override
  String sizeKb(String size) {
    return '$size KB';
  }

  @override
  String sizeMbSpoken(String size) {
    return '$size megabytes';
  }

  @override
  String sizeKbSpoken(String size) {
    return '$size kilobytes';
  }

  @override
  String deathHijri(String year) {
    return 'd. $year AH';
  }

  @override
  String deathHijriSpoken(String year) {
    return 'died $year AH';
  }

  @override
  String authorWithDeath(String author, String death) {
    return '$author ($death)';
  }

  @override
  String bookCardSemantics(String title, String author, String details) {
    return '$title, $author, $details';
  }

  @override
  String get moreOptions => 'More options';

  @override
  String sourceLine(String source, String license) {
    return 'Source: $source — $license';
  }

  @override
  String get licensePublicDomain => 'Public domain';

  @override
  String downloadBook(String size) {
    return 'Download book ($size)';
  }

  @override
  String get chapters => 'Chapters';

  @override
  String get downloadToSeeChapters => 'Download the book to see its chapters';

  @override
  String get bookOpenError => 'Couldn\'t open the book. Download it again.';

  @override
  String chapterSemantics(String number, String total, String title) {
    return 'Chapter $number of $total: $title';
  }

  @override
  String get bookNotFound => 'This book isn\'t in the library.';

  @override
  String get downloading => 'Downloading…';

  @override
  String get listSeparator => ', ';

  @override
  String downloadAnnouncement(String title, String percent) {
    return '“$title”: downloading… $percent%';
  }

  @override
  String get startReading => 'Start reading';

  @override
  String get continueReading => 'Continue reading';

  @override
  String reachedPosition(String chapter, String percent) {
    return 'You reached: $chapter — $percent%';
  }

  @override
  String get youAreHere => 'You are here';

  @override
  String chapterHereSemantics(String chapter) {
    return '$chapter, you are here';
  }

  @override
  String get booksTab => 'Books';

  @override
  String get favoritesTab => 'Favorites';

  @override
  String get favoritesEmptyTitle => 'No favorite passages yet.';

  @override
  String get favoritesEmptyHint =>
      'Long-press any passage while reading and choose “Add to favorites”.';

  @override
  String get favoritesError => 'Couldn\'t show your favorites.';

  @override
  String get remove => 'Remove';

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get undo => 'Undo';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get inFavorites => 'In favorites';

  @override
  String get bookNotInstalledShort => 'Book not downloaded';

  @override
  String get bookNotInstalledReader =>
      'This book isn\'t downloaded on your device.';

  @override
  String downloadWithSize(String size) {
    return 'Download ($size)';
  }

  @override
  String get unavailableBook => 'Unavailable book';

  @override
  String breadcrumb(String book, String chapter) {
    return '$book › $chapter';
  }

  @override
  String passageSemantics(String source, String text) {
    return '$source: $text';
  }

  @override
  String get contents => 'Contents';

  @override
  String get displaySettings => 'Display settings';

  @override
  String get textSize => 'Text size';

  @override
  String get decreaseTextLabel => 'A−';

  @override
  String get increaseTextLabel => 'A+';

  @override
  String get decreaseText => 'Decrease text size';

  @override
  String get increaseText => 'Increase text size';

  @override
  String textSizeLevel(String level, String total) {
    return 'Level $level of $total';
  }

  @override
  String get textPreview => 'هكذا يظهر نص الكتاب بهذا الحجم.';

  @override
  String get pageColor => 'Page color';

  @override
  String get themeLight => 'Light';

  @override
  String get themePaper => 'Paper';

  @override
  String get themeDark => 'Dark';

  @override
  String readerProgress(String chapter, String total, String percent) {
    return 'Chapter $chapter of $total · $percent%';
  }

  @override
  String get resumedHere => 'Picked up where you left off';

  @override
  String get fromStart => 'From the beginning';

  @override
  String get paragraphNotFound =>
      'We couldn\'t find that passage, so we opened its chapter';

  @override
  String continueReadingSemantics(String source, String text) {
    return 'Continue reading: $source. $text';
  }

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get textCopied => 'Text copied';

  @override
  String passageCitation(
    String text,
    String book,
    String author,
    String chapter,
  ) {
    return '$text\n— $book, $author, $chapter';
  }

  @override
  String get saveFailed => 'Couldn\'t save, please try again';

  @override
  String get paragraphMissing => 'This passage is no longer in the book';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search books…';

  @override
  String get clearSearch => 'Clear';

  @override
  String get searchAllBooks => 'All downloaded books';

  @override
  String get searchHelper => 'Search ignores diacritics and hamza variations';

  @override
  String get searchMinChars => 'Type at least two letters';

  @override
  String searchNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchNoResultsHint =>
      'Try a shorter word or a synonym, or search all books.';

  @override
  String get searchEverywhere => 'Search all books';

  @override
  String get searchNoBooks => 'There are no books on your device to search.';

  @override
  String get goToLibrary => 'Go to library';

  @override
  String get searchError => 'Something went wrong while searching.';

  @override
  String searchResultCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String searchBookCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String searchSummary(String results, String books) {
    return '$results in $books';
  }

  @override
  String get searchSuggestionsTitle => 'Suggestions';

  @override
  String get searchSuggestionWords => 'الحكمة|البيان|الصديق|الأسد';

  @override
  String get searchShowMore => 'Show more';

  @override
  String searchResultSemantics(
    String chapter,
    String book,
    String snippet,
    String words,
  ) {
    return '$chapter, $book. $snippet. Matched word: $words';
  }

  @override
  String searchGroupHeader(String book, String count) {
    return '$book, $count';
  }

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get searchInBook => 'Search in this book';

  @override
  String get listen => 'Listen';

  @override
  String get listenFromHere => 'Listen from here';

  @override
  String get audioPlay => 'Play read-aloud';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioNext => 'Next paragraph';

  @override
  String get audioPrevious => 'Previous paragraph';

  @override
  String get audioStop => 'Stop listening';

  @override
  String get audioMinimize => 'Minimize';

  @override
  String get audioOpenPlayer => 'Open audio player';

  @override
  String get audioPlayerTitle => 'Audio player';

  @override
  String get audioPreparing => 'Preparing audio…';

  @override
  String get audioSpeed => 'Speed';

  @override
  String audioSpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String audioSpeedSemantics(String speed) {
    return 'Speed ${speed}x';
  }

  @override
  String get audioVoice => 'Voice';

  @override
  String audioVoiceRow(String voice) {
    return 'Voice: $voice';
  }

  @override
  String audioVoiceWithRegion(String region, String number) {
    return 'Arabic ($region) — voice $number';
  }

  @override
  String audioVoiceNoRegion(String number) {
    return 'Arabic — voice $number';
  }

  @override
  String audioRegion(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'EG': 'Egypt',
      'SA': 'Saudi Arabia',
      'AE': 'UAE',
      'JO': 'Jordan',
      'MA': 'Morocco',
      'DZ': 'Algeria',
      'TN': 'Tunisia',
      'LB': 'Lebanon',
      'KW': 'Kuwait',
      'QA': 'Qatar',
      'BH': 'Bahrain',
      'OM': 'Oman',
      'SY': 'Syria',
      'IQ': 'Iraq',
      'YE': 'Yemen',
      'LY': 'Libya',
      'SD': 'Sudan',
      'PS': 'Palestine',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get audioTryVoice => 'Try';

  @override
  String audioTryVoiceSemantics(String voice) {
    return 'Try $voice';
  }

  @override
  String get audioSample =>
      'قال الجاحظ: البيان اسمٌ جامعٌ لكل شيء كشف لك قناع المعنى.';

  @override
  String get audioGoToText => 'Go to text';

  @override
  String get audioNoVoiceTitle => 'No Arabic voice on your device';

  @override
  String get audioNoVoiceBody =>
      'To listen to books, install the Google speech engine: tap “Install Google voice from the store” and install “Speech Recognition & Synthesis from Google”, then open voice settings: Settings → System → Languages & input → Text-to-speech output → Google engine → Install voice data → Arabic.';

  @override
  String get audioInstallGoogleVoice => 'Install Google voice from the store';

  @override
  String get audioOpenVoiceSettings => 'Open voice settings';

  @override
  String get later => 'Later';

  @override
  String get audioNoVoiceHelp => 'Can\'t find the option?';

  @override
  String get audioNoVoiceAlternative =>
      'The path differs by manufacturer. Search your phone settings for “Text-to-speech” or “Speech”, or install “Speech Services by Google” from the app store, then download the Arabic language data and select it.';

  @override
  String get audioEngineError =>
      'Audio stopped because of a speech engine error.';

  @override
  String get audioBookFinished => 'End of book';

  @override
  String get audioScreenReaderWarning =>
      'Read-aloud may overlap with your screen reader. Use headphones, or pause read-aloud while navigating.';

  @override
  String get audioBackToListening => 'Back to listening position';

  @override
  String get audioNowReading => 'Now reading';

  @override
  String get audioChannelName => 'Read-aloud';

  @override
  String audioNowPlayingSubtitle(String book, String author) {
    return '$book — $author';
  }

  @override
  String get askTitle => 'Ask Adeeb';

  @override
  String askQuotaBadge(String remaining, String limit) {
    return '$remaining of $limit left today';
  }

  @override
  String get askQuotaExhausted => 'No questions left today';

  @override
  String get askQuotaExplainTitle => 'Daily questions';

  @override
  String askQuotaExplain(String limit) {
    return 'Each device gets $limit questions a day to keep the service free. Your balance renews every day. A question counts once it reaches Adeeb, even if the answer isn\'t found in the books.';
  }

  @override
  String get askQuotaExplainClose => 'OK';

  @override
  String get askPrivacyBanner =>
      'Don\'t include personal information in your question';

  @override
  String get askHint =>
      'Ask about something in the books… e.g. ما تعريف البيان عند الجاحظ؟';

  @override
  String get askFieldLabel => 'Your question';

  @override
  String askCharCount(String count, String max) {
    return '$count / $max';
  }

  @override
  String askTooLong(String max) {
    return 'The question is longer than $max characters';
  }

  @override
  String get askTooShort => 'Write a clearer question';

  @override
  String get askButton => 'Ask';

  @override
  String get askSearchTextsButton => 'Search the texts';

  @override
  String get askExamples =>
      'ما تعريف البيان عند الجاحظ؟|ماذا قال ابن المقفع عن الصديق؟|ما آداب المجالسة في أدب الدنيا والدين؟';

  @override
  String get askExamplesTitle => 'Examples';

  @override
  String get askArabicNote => 'Answers are in Arabic, quoted from the books';

  @override
  String get askStageSearching => 'Searching the books…';

  @override
  String get askStageAnswering => 'Writing the answer…';

  @override
  String get askStageVerifying => 'Verifying the quote…';

  @override
  String get askSlow => 'This is taking longer than usual…';

  @override
  String get askCancelNote => 'The question may count if it reached the server';

  @override
  String askYourQuestion(String question) {
    return 'Your question: $question';
  }

  @override
  String get askAiLabel => 'AI-generated from the book text — check the quote';

  @override
  String askQuoted(String quote) {
    return '«$quote»';
  }

  @override
  String askQuoteSemantics(String quote) {
    return 'Quote: $quote';
  }

  @override
  String askOpenSource(String book, String chapter) {
    return 'Open source: $book, $chapter';
  }

  @override
  String get askNewQuestion => 'New question';

  @override
  String askOtherPassages(String count) {
    return 'Other matching passages ($count)';
  }

  @override
  String get askAnswerArrived => 'The answer has arrived';

  @override
  String askCopyCitation(String quote, String book, String chapter) {
    return '«$quote»\n— $book, $chapter';
  }

  @override
  String get askNotFound => 'I couldn\'t find this in the available books.';

  @override
  String get askNotFoundHint => 'Try rephrasing or choose a specific book.';

  @override
  String get askBooksOnly =>
      'Adeeb only answers about the books\' content and doesn\'t give religious rulings.';

  @override
  String get askClosestPassages => 'Passages closest to your question';

  @override
  String get askMatchingPassages => 'Matching passages';

  @override
  String get askUnverified =>
      'We couldn\'t verify the answer, so here are the matching passages directly.';

  @override
  String askDailyLimit(String limit) {
    return 'Today\'s questions are used up ($limit of $limit). Your balance renews tomorrow. Here are matching passages:';
  }

  @override
  String get askOffline =>
      'You\'re offline. The AI answer needs a connection; here are matching passages from your downloaded books:';

  @override
  String get askUnavailable =>
      'The service isn\'t available right now. Try later. Here are matching passages:';

  @override
  String get askRateLimit =>
      'You sent many questions quickly. Wait a minute and try again.';

  @override
  String get askUpgrade =>
      'Update the app to use Ask Adeeb. Here are matching passages:';

  @override
  String get askNoBooks =>
      'Download at least one book so Adeeb can answer from its text.';

  @override
  String get askNoLocalMatches =>
      'And we found no passages matching the words of your question.';

  @override
  String get askBooksError => 'Couldn\'t read the downloaded books.';

  @override
  String get askConsentTitle => 'Before you ask';

  @override
  String get askConsentBooks =>
      'Adeeb answers only from the text of your downloaded books, and shows you the quote and its source.';

  @override
  String get askConsentGemini =>
      'Your question and excerpts from the books are sent to Google\'s Gemini service to write the answer, and Google may use them to improve its services.';

  @override
  String get askConsentPersonal =>
      'Don\'t include personal information in your question.';

  @override
  String get askConsentNoFatwa =>
      'Adeeb doesn\'t answer religious rulings or questions outside the books.';

  @override
  String get askConsentAge => 'This feature is for people aged 18 or over.';

  @override
  String get askConsentConfirm => 'I\'m 18 or over — got it';

  @override
  String get askConsentDecline => 'Not now';

  @override
  String get askAboutThis => 'Ask Adeeb about this';

  @override
  String get askQuoteBookNotInstalled => 'Quoted text:';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChanged => 'The app is now in English';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceSystem => 'System';

  @override
  String get settingsReading => 'Reading';

  @override
  String get settingsTextSizeAndColor => 'Text size and page color';

  @override
  String get settingsListening => 'Listening';

  @override
  String get settingsVoiceDefault => 'Automatic';

  @override
  String get settingsResetAge => 'Reset age confirmation';

  @override
  String get settingsResetAgeHint =>
      'You\'ll be asked to confirm again when you open Ask Adeeb';

  @override
  String get settingsResetAgeQuestion => 'Reset age confirmation?';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsResetAgeDone => 'Age confirmation was reset';

  @override
  String get settingsClearAnswer => 'Clear last answer';

  @override
  String get settingsClearAnswerHint =>
      'Only the last answer is kept on your device';

  @override
  String get settingsNoAnswer => 'No saved answer';

  @override
  String get settingsClearAnswerDone => 'Last answer cleared';

  @override
  String get settingsAbout => 'About';

  @override
  String get sourcesTitle => 'Sources & licenses';

  @override
  String get privacyTitle => 'Privacy policy';

  @override
  String get aboutTitle => 'About Adeeb AI';

  @override
  String get sourcesIntro =>
      'The book texts are in the public domain, taken from the OpenITI project (Open Islamicate Texts Initiative), which transcribed them from al-Maktaba al-Shamela. We removed the footnotes, introductions and comments of modern editors, and list each book\'s edition and what was removed.';

  @override
  String get sourcesOpenItiLicense =>
      'OpenITI files are published under CC BY-NC-SA 4.0 (Attribution, NonCommercial, ShareAlike), and we republish the converted files under the same license.';

  @override
  String get sourcesBooks => 'Books';

  @override
  String get sourcesNoBooks =>
      'Books appear here once the book list has loaded.';

  @override
  String get sourcesSourceLabel => 'Source';

  @override
  String get sourcesOriginalLabel => 'Original';

  @override
  String get sourcesEditionLabel => 'Edition';

  @override
  String get sourcesRemovedLabel => 'Removed';

  @override
  String get sourcesLicenseLabel => 'License';

  @override
  String get sourcesFileVersionLabel => 'File version';

  @override
  String get sourcesLinkLabel => 'Link';

  @override
  String get sourcesDetailsAfterDownload =>
      'The edition and what was removed appear after you download the book.';

  @override
  String get sourcesCopyLink => 'Copy link';

  @override
  String sourcesCopyLinkSemantics(String book) {
    return 'Copy the source link for $book';
  }

  @override
  String get sourcesLinkCopied => 'Link copied';

  @override
  String get sourcesFonts => 'Fonts';

  @override
  String get fontAmiri => 'Amiri';

  @override
  String get fontIbmPlex => 'IBM Plex Sans Arabic';

  @override
  String get sourcesFontLicense => 'SIL Open Font License 1.1';

  @override
  String get sourcesViewLicense => 'View license';

  @override
  String sourcesViewLicenseSemantics(String font) {
    return 'View the license for the $font font';
  }

  @override
  String fontLicenseTitle(String font) {
    return '$font license';
  }

  @override
  String get sourcesServices => 'Services';

  @override
  String get sourcesServiceAi =>
      'AI answers: Google Gemini through our proxy server';

  @override
  String get sourcesServiceTts =>
      'Listening: your device\'s text-to-speech engine';

  @override
  String get sourcesServiceHosting => 'Book hosting: GitHub';

  @override
  String get sourcesLibraries => 'Open-source libraries';

  @override
  String get sourcesViewLibraries => 'View library licenses';

  @override
  String get privacyIntro =>
      'A plain-language summary of what happens to your data in Adeeb AI.';

  @override
  String get privacyAccountTitle => 'No account';

  @override
  String get privacyAccountBody =>
      'The app asks for no account, name, email or phone number.';

  @override
  String get privacyLocalTitle => 'Your data stays on your device';

  @override
  String get privacyLocalBody =>
      'Downloaded books, favorites, your last reading position, your settings and the last Ask Adeeb answer are stored only on your device. Reading, search and listening work offline, and listening uses your device\'s text-to-speech engine.';

  @override
  String get privacyAskTitle => 'Ask Adeeb questions';

  @override
  String get privacyAskBody =>
      'When you ask, your question and excerpts from your downloaded books are sent to our server and then to Google\'s Gemini service to write the answer. Google may use what it receives to improve its services, and human reviewers may read it. Our server doesn\'t store the text of your question.';

  @override
  String get privacyPersonalTitle => 'Don\'t share personal information';

  @override
  String get privacyPersonalBody =>
      'Don\'t include your name, contact details or any personal or confidential information in your question.';

  @override
  String get privacyDeviceTitle => 'A random device identifier';

  @override
  String get privacyDeviceBody =>
      'The app creates a random identifier stored on your device and sends it with questions only to count the daily limit; it isn\'t linked to your identity or to system identifiers. Our server (on Cloudflare) sees your device\'s IP address, and from it and the identifier stores an irreversible encrypted value (HMAC) in the daily-limit counters for one day only, after which it is deleted. It never stores the identifier or the IP address as is.';

  @override
  String get privacyAgeTitle => 'Ask Adeeb is for people aged 18 or over';

  @override
  String get privacyAgeBody =>
      'Gemini\'s terms require users to be 18 or over, so you\'re asked to confirm your age before your first question. Reading, search and listening are available to everyone.';

  @override
  String get privacyNetworkTitle => 'Connections';

  @override
  String get privacyNetworkBody =>
      'The app connects to GitHub to download the book list and book files, and to our server only when you use Ask Adeeb, always over HTTPS.';

  @override
  String get privacyAdsTitle => 'No ads, no tracking';

  @override
  String get privacyAdsBody =>
      'No ads, no analytics, no crash reports and no tracking of any kind.';

  @override
  String get privacyControlTitle => 'Controlling your data';

  @override
  String get privacyControlBody =>
      'In Settings you can clear the last answer and reset the age confirmation. Uninstalling the app deletes all of its data from your device.';

  @override
  String get askConsentPrivacy => 'Read the privacy policy';

  @override
  String get aboutLogoLabel => 'Adeeb AI logo';

  @override
  String get aboutDescription =>
      'Read, search and listen to classical Arabic literature offline, with Ask Adeeb answering from the books\' text with a quote and its source.';

  @override
  String get aboutFree => 'Free, with no ads, no subscriptions and no account.';

  @override
  String get licenseLoadError => 'Couldn\'t show the license.';

  @override
  String get sourcesOpenItiLink => 'The OpenITI project';

  @override
  String get sourcesLicenseLink => 'CC BY-NC-SA 4.0 license text';

  @override
  String sourcesCopyNamedLinkSemantics(String name) {
    return 'Copy the link: $name';
  }

  @override
  String get downloadedTab => 'Downloaded';

  @override
  String get catalogSearchHint => 'Search by title or author';

  @override
  String get catalogFilterAll => 'All';

  @override
  String get catalogCategoryLabel => 'Category';

  @override
  String get catalogEraLabel => 'Era';

  @override
  String catalogSortValue(String sort) {
    return 'Sort: $sort';
  }

  @override
  String get catalogSortDeath => 'Year of death';

  @override
  String get catalogSortTitle => 'Title';

  @override
  String get catalogSortSize => 'Size';

  @override
  String get catalogNoMatches => 'No books match your search or filters.';

  @override
  String catalogCategory(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'ayyam': 'Days of the Arabs & genealogy',
      'poetry': 'Poetry & diwans',
      'lexicon': 'Language & lexicons',
      'grammar': 'Grammar, morphology & prosody',
      'rhetoric': 'Rhetoric & criticism',
      'adab': 'Adab, reports & anecdotes',
      'history': 'History',
      'biography': 'Biographies & generations',
      'travel': 'Geography & travel',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String catalogEra(String era) {
    String _temp0 = intl.Intl.selectLogic(era, {
      'jahili': 'Pre-Islamic & early Islam',
      'umayyad': 'Umayyad',
      'abbasid': 'Abbasid',
      'late': 'Mamluk & later',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String get noDownloadedBooks =>
      'You haven\'t downloaded any books yet. Download one from the Books tab to read and search it offline.';

  @override
  String get settingsBooks => 'Books';

  @override
  String get manageBooks => 'Manage downloaded books';

  @override
  String booksUsage(String size) {
    return 'Books use $size';
  }

  @override
  String deleteBookSemantics(String title) {
    return 'Remove “$title” from device';
  }
}
