/// رموز الأخطاء الموحّدة (ARCHITECTURE §3). الشاشات تعرض النص من الترجمة حسب
/// الرمز فقط، لا من نص الخادم أو النموذج.
enum FailureCode {
  unauthorized,
  invalidCredentials,
  emailTaken,
  limitReached,
  fairUseReached,
  invalidImage,
  analysisFailed,
  timeout,
  servicePaused,
  imageTooLarge,
  offline,
  saveFailed,
  purchaseUnavailable,
  purchaseFailed,
  noPurchasesToRestore,
  deleteFailed,
  shareFailed,
}

/// أسباب رفض الصورة (SPEC §3.1).
enum InvalidImageReason {
  notCoffee('not_coffee'),
  tooDark('too_dark'),
  blurry('blurry'),
  noCupVisible('no_cup_visible'),
  other('other');

  const InvalidImageReason(this.wire);

  /// القيمة كما تصل من الخادم.
  final String wire;

  static InvalidImageReason? fromWire(String? value) {
    for (final r in values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}

class AppFailure implements Exception {
  const AppFailure(this.code, {this.reason});

  const AppFailure.invalidImage(InvalidImageReason this.reason)
      : code = FailureCode.invalidImage;

  final FailureCode code;

  /// يُملأ فقط عند [FailureCode.invalidImage].
  final InvalidImageReason? reason;

  @override
  String toString() => 'AppFailure($code${reason == null ? '' : ', $reason'})';
}
