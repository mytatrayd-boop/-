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
      'To listen to books, install the Arabic voice from your phone settings: Settings → System → Languages & input → Text-to-speech output → Google engine → Install voice data → Arabic.';

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
}
