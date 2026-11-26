// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BGTube';

  @override
  String get emptyTitle => 'Paste a YouTube link to play it';

  @override
  String get linkHint => 'YouTube link';

  @override
  String get pasteAndPlay => 'Paste and play';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get speed => 'Playback speed';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepMinutes(String minutes) {
    return '$minutes minutes';
  }

  @override
  String get sleepCancel => 'Cancel timer';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get retry => 'Retry';

  @override
  String get resolving => 'Preparing…';

  @override
  String get clipboardEmpty => 'No YouTube link in the clipboard';

  @override
  String get errorInvalidLink =>
      'The link is not valid. Make sure it is a YouTube video link.';

  @override
  String get errorPlaylistNotSupported =>
      'Playlist links are not supported yet. Paste a single video link.';

  @override
  String get errorExtraction =>
      'Could not extract audio from this video. Try again.';

  @override
  String get errorNetwork =>
      'Could not connect to the internet. Check your network and retry.';

  @override
  String get errorRateLimited =>
      'YouTube is rate-limiting requests from your network. Wait a while and retry.';

  @override
  String get errorPlayback => 'Could not play the audio. Please retry.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'Applied immediately and remembered.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsPersonalUse =>
      'For personal use only; not for distribution.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSignedOut => 'Not signed in';

  @override
  String get accountSignedIn => 'Connected to a Google account';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'Your sign-in data will be removed from this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get loginExplain =>
      'Sign in to see your playlists, subscriptions and likes';

  @override
  String get loginContinue => 'Continue with Google';

  @override
  String get loginNotNow => 'Not now';

  @override
  String get loginNoPassword => 'The app never sees your password';

  @override
  String get sessionExpired => 'Your session has ended. Please sign in again';

  @override
  String get errorNotSignedIn => 'Sign in to see your account';

  @override
  String get errorSignIn =>
      'Couldn\'t sign in. Check your connection and try again';

  @override
  String get errorSignInUnavailable =>
      'Sign-in isn\'t enabled in this build yet';

  @override
  String get errorSignOut => 'Couldn\'t sign out. Please try again';

  @override
  String get riskTitle => 'Before your first sign-in';

  @override
  String get riskBody =>
      'This app extracts YouTube audio in an unofficial way that breaks YouTube\'s terms. This may get your network blocked or your account or Google Cloud project restricted. Extraction is kept separate from your account and never receives a sign-in token, but the risk remains.\n\nUse it personally only, ideally with an account you don\'t rely on for critical work.\n\nGoogle will show an \"unverified app\" warning: choose \"Advanced\", then \"Continue\".';

  @override
  String get riskAccept => 'I understand, continue';

  @override
  String get errorQueueStopped =>
      'Couldn\'t play the rest of the queue. Try again.';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get queueTitle => 'Queue';

  @override
  String queueNextUp(String title) {
    return 'Next: $title';
  }

  @override
  String queueRemaining(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString left',
      one: '1 left',
      zero: 'none left',
    );
    return '$_temp0';
  }

  @override
  String itemsSummary(int count, String duration) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0 · $duration';
  }

  @override
  String itemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get queueNowPlaying => 'Now playing';

  @override
  String get queueEmpty => 'The queue is empty';

  @override
  String get queueNothingAfter =>
      'Nothing after this. Tap ⋮ on any item and choose “Add to end”';

  @override
  String get queueFailedItem => 'Couldn\'t play it, skipped';

  @override
  String queueSkippedSnack(String title) {
    return 'Couldn\'t play “$title”, moved to the next';
  }

  @override
  String get queueRemoved => 'Removed from the queue';

  @override
  String get queueClear => 'Clear queue';

  @override
  String get queueClearConfirmTitle => 'Clear the queue?';

  @override
  String get queueClearConfirmBody => 'The current item keeps playing.';

  @override
  String get queueClearAction => 'Clear';

  @override
  String get queueCleared => 'Queue cleared';

  @override
  String get undo => 'Undo';

  @override
  String get delete => 'Delete';

  @override
  String get queueSaveAsPlaylist => 'Save as playlist';

  @override
  String get queueSaveAsLocalPlaylist => 'Save as local playlist';

  @override
  String queueDefaultPlaylistName(String date) {
    return 'Queue $date';
  }

  @override
  String get playlistNameLabel => 'Playlist name';

  @override
  String get save => 'Save';

  @override
  String playlistSaved(String name) {
    return 'Saved playlist “$name”';
  }

  @override
  String get open => 'Open';

  @override
  String get queueRemove => 'Remove from queue';

  @override
  String get queueMoveNext => 'Move to play next';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get actionPlayNow => 'Play now';

  @override
  String get actionPlayNext => 'Play next';

  @override
  String get actionAddToEnd => 'Add to end';

  @override
  String get actionAddToLocalPlaylist => 'Add to local playlist…';

  @override
  String snackPlayNext(String title) {
    return 'Playing next: $title';
  }

  @override
  String get snackAddedToEnd => 'Added to the end of the queue';

  @override
  String snackAddedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $countString items to the queue',
      one: 'Added 1 item to the queue',
    );
    return '$_temp0';
  }

  @override
  String queueTruncated(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The queue is full ($countString items); the rest wasn\'t added',
      one: 'The queue is full (1 item); the rest wasn\'t added',
    );
    return '$_temp0';
  }

  @override
  String get untitledVideo => 'YouTube video';

  @override
  String get localPlaylists => 'My local playlists';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get onDevice => 'On device';

  @override
  String get playlistsEmpty =>
      'No playlists yet. Save the queue or create a playlist';

  @override
  String get playlistEmpty =>
      'This playlist is empty. Add items from ⋮ on any item';

  @override
  String get playlistsLoadError => 'Couldn\'t open local playlists';

  @override
  String get rename => 'Rename';

  @override
  String deletePlaylistTitle(String name) {
    return 'Delete playlist “$name”?';
  }

  @override
  String get deletePlaylistBody => 'Nothing is deleted from YouTube.';

  @override
  String get playAll => 'Play all';

  @override
  String get addWholeList => 'Add the whole list';

  @override
  String addedToPlaylist(String name) {
    return 'Added to “$name”';
  }

  @override
  String alreadyInPlaylist(String name) {
    return 'Already in “$name”';
  }

  @override
  String get removedFromPlaylist => 'Removed from the playlist';

  @override
  String get moreActions => 'More options';

  @override
  String get saveFailed => 'Couldn\'t save. Try again';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get searchHint => 'Search or paste a link';

  @override
  String get searchAction => 'Search';

  @override
  String get homeStartHint => 'Start by searching or pasting a link';

  @override
  String get guestSignInPrompt =>
      'Sign in to see the latest videos from your subscriptions and search YouTube';

  @override
  String get searchNeedsSignIn =>
      'Sign in to search YouTube. You can paste a link without signing in.';

  @override
  String get feedTitle => 'Latest from your subscriptions';

  @override
  String get feedEmpty =>
      'Nothing here yet. Videos from channels you subscribe to appear here.';

  @override
  String searchResultsFor(String query) {
    return 'Results for “$query”';
  }

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”. Try other words';
  }

  @override
  String get closeSearch => 'Close search';

  @override
  String get staleBanner => 'This is a saved copy';

  @override
  String get errorQuotaExceeded =>
      'Today\'s search quota is used up. It renews tomorrow. You can paste a link or play from your library.';

  @override
  String get errorApi => 'Couldn\'t load data from YouTube. Try again.';

  @override
  String get pasteLinkAction => 'Paste a link';

  @override
  String get channelKind => 'Channel';

  @override
  String get channelEmpty => 'Nothing here yet';

  @override
  String get miniPlaybackFailed => 'Couldn\'t play';

  @override
  String get openPlayer => 'Open player';

  @override
  String accountSignedInAs(String name) {
    return 'Signed in: $name';
  }

  @override
  String get settingsQuota => 'Search quota';

  @override
  String quotaSearchesLeft(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString searches left today',
      one: '1 search left today',
      zero: 'No searches left today',
    );
    return '$_temp0';
  }

  @override
  String get quotaUnavailable => 'Unavailable';

  @override
  String get errorGeneralQuotaExceeded =>
      'Today\'s YouTube quota for lists and channels is used up. It renews tomorrow. You can paste a link or play from your library.';

  @override
  String get errorInsufficientPermissions =>
      'Your account hasn\'t given the app permission to read YouTube. Grant it to continue.';

  @override
  String get grantPermission => 'Grant permission';

  @override
  String get loadMore => 'More';

  @override
  String quotaSearchUsage(int used, int limit) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$usedString of $limitString searches today';
  }

  @override
  String quotaGeneralUsage(int used, int limit) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Lists and channels: $usedString of $limitString units';
  }

  @override
  String get quotaResetNote => 'Both quotas renew at midnight Pacific time';
}
