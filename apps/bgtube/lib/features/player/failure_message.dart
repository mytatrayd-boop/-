import '../../core/app_failure.dart';
import '../../l10n/gen/app_localizations.dart';

String failureMessage(AppLocalizations l, AppFailure f) => switch (f.kind) {
      FailureKind.invalidLink => l.errorInvalidLink,
      FailureKind.playlistNotSupported => l.errorPlaylistNotSupported,
      FailureKind.extractionFailed => l.errorExtraction,
      FailureKind.network => l.errorNetwork,
      FailureKind.playbackFailed => l.errorPlayback,
    };
