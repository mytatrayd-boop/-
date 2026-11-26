/// أنواع الفشل الموحّدة. الواجهة تحوّل النوع إلى رسالة مترجمة (لا نص هنا).
enum FailureKind {
  invalidLink,
  /// رابط قائمة يوتيوب دون دخول (الإضافة عبر الواجهة الرسمية فقط، D30).
  playlistNeedsSignIn,
  extractionFailed,
  network,
  rateLimited,
  playbackFailed,
  // الطابور (الميزة 10): توقف بعد فشلات متتالية
  queueStopped,
  // الحساب (الميزة 4)
  authExpired,
  notSignedIn,
  signInFailed,
  signInUnavailable,
  signOutFailed,
  // YouTube Data API (الميزة 3، D29)
  /// وعاء البحث (100 طلب يومياً) نفد.
  searchQuotaExceeded,
  /// الوعاء العام (10,000 وحدة) نفد.
  quotaExceeded,
  /// الإذن الممنوح لا يغطي قراءة الحساب: يلزم منحه من جديد.
  insufficientPermissions,
  apiFailed,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, [this.debugDetail]);

  final FailureKind kind;

  /// تشخيص تقني قصير (نوع الاستثناء، رمز HTTP، العميل/itag) يُعرض بخط صغير
  /// تحت رسالة الخطأ لتفيد لقطة الشاشة. منقّى: بلا روابط ولا رموز ولا قيم موقّعة.
  final String? debugDetail;

  @override
  String toString() => 'AppFailure($kind${debugDetail == null ? '' : ': $debugDetail'})';
}

/// الجلسة لم تعد صالحة (سحب الإذن، تغيير كلمة المرور، خمول طويل): الواجهة تعرض
/// "سجّل الدخول من جديد".
class AuthExpired extends AppFailure {
  const AuthExpired() : super(FailureKind.authExpired);
}
