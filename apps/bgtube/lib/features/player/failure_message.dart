import '../../core/app_failure.dart';
import '../../l10n/gen/app_localizations.dart';

String failureMessage(AppLocalizations l, AppFailure f) => switch (f.kind) {
      FailureKind.invalidLink => l.errorInvalidLink,
      FailureKind.playlistNotSupported => l.errorPlaylistNotSupported,
      FailureKind.extractionFailed => l.errorExtraction,
      FailureKind.network => l.errorNetwork,
      FailureKind.rateLimited => l.errorRateLimited,
      FailureKind.playbackFailed => l.errorPlayback,
      FailureKind.queueStopped => l.errorQueueStopped,
      FailureKind.authExpired => l.sessionExpired,
      FailureKind.notSignedIn => l.errorNotSignedIn,
      FailureKind.signInFailed => l.errorSignIn,
      FailureKind.signInUnavailable => l.errorSignInUnavailable,
      FailureKind.signOutFailed => l.errorSignOut,
      FailureKind.quotaExceeded => l.errorQuotaExceeded,
      FailureKind.apiFailed => l.errorApi,
    };
