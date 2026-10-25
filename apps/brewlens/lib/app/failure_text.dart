import '../domain/models/app_failure.dart';
import '../l10n/app_localizations.dart';

/// نص الخطأ من الترجمة حسب الرمز فقط، لا من نص الخادم أو النموذج.
String failureText(AppLocalizations l, Object error) {
  if (error is! AppFailure) return l.errorUnknown;
  return switch (error.code) {
    FailureCode.unauthorized => l.failureUnauthorized,
    FailureCode.invalidCredentials => l.failureInvalidCredentials,
    FailureCode.emailTaken => l.failureEmailTaken,
    FailureCode.limitReached => l.failureLimitReached,
    FailureCode.fairUseReached => l.failureFairUseReached,
    FailureCode.invalidImage => switch (error.reason) {
        InvalidImageReason.notCoffee => l.invalidImageNotCoffee,
        InvalidImageReason.tooDark => l.invalidImageTooDark,
        InvalidImageReason.blurry => l.invalidImageBlurry,
        InvalidImageReason.noCupVisible => l.invalidImageNoCup,
        InvalidImageReason.other || null => l.invalidImageOther,
      },
    FailureCode.analysisFailed ||
    FailureCode.timeout ||
    FailureCode.servicePaused =>
      l.failureServiceUnavailable,
    FailureCode.imageTooLarge => l.failureImageTooLarge,
    FailureCode.offline => l.failureOffline,
    FailureCode.saveFailed => l.failureSaveFailed,
    FailureCode.purchaseUnavailable => l.failurePurchaseUnavailable,
    FailureCode.purchaseFailed => l.failurePurchaseFailed,
    FailureCode.noPurchasesToRestore => l.failureNoPurchases,
    FailureCode.deleteFailed => l.failureDeleteFailed,
    FailureCode.shareFailed => l.failureShareFailed,
  };
}
