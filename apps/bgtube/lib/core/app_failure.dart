/// أنواع الفشل الموحّدة. الواجهة تحوّل النوع إلى رسالة مترجمة (لا نص هنا).
enum FailureKind {
  invalidLink,
  playlistNotSupported,
  extractionFailed,
  network,
  rateLimited,
  playbackFailed,
  // الحساب (الميزة 4)
  authExpired,
  notSignedIn,
  signInFailed,
  signInUnavailable,
  signOutFailed,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, [this.debugDetail]);

  final FailureKind kind;

  /// للتشخيص فقط؛ لا يُعرض للمستخدم ولا يجوز أن يحوي رموزاً.
  final String? debugDetail;

  @override
  String toString() => 'AppFailure($kind${debugDetail == null ? '' : ': $debugDetail'})';
}

/// الجلسة لم تعد صالحة (سحب الإذن، تغيير كلمة المرور، خمول طويل): الواجهة تعرض
/// "سجّل الدخول من جديد".
class AuthExpired extends AppFailure {
  const AuthExpired() : super(FailureKind.authExpired);
}
