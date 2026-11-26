/// الحساب عبر تسجيل الدخول الرسمي من جوجل (D7). لا كلمات مرور ولا رموز طويلة
/// الأمد في التطبيق؛ رمز الوصول قصير العمر ويُطلب عند الحاجة.
///
/// ممنوع تمرير هذا المنفذ أو أي رمز منه إلى `AudioSourceResolver` (D4).
library;

/// النطاق الوحيد المطلوب الآن (قراءة فقط).
const youtubeReadonlyScope = 'https://www.googleapis.com/auth/youtube.readonly';

enum AuthStatus {
  /// لم يُسجَّل دخول (أو خرج المستخدم).
  signedOut,

  /// جلسة قائمة؛ رمز الوصول يُطلب صامتاً عند الحاجة.
  signedIn,

  /// كانت هناك جلسة ولم تعد صالحة: يلزم تسجيل الدخول من جديد.
  expired,
}

enum SignInOutcome { signedIn, canceled }

abstract interface class AuthService {
  AuthStatus get status;
  Stream<AuthStatus> get statusChanges;

  /// عند الإقلاع: يستعيد الجلسة السابقة صامتاً إن وُجدت. لا يرمي.
  Future<void> restore();

  /// يفتح شاشة جوجل الرسمية. الإلغاء أو رفض الإذن = [SignInOutcome.canceled]
  /// (لا خطأ). غير ذلك يرمي `AppFailure`.
  Future<SignInOutcome> signIn();

  /// رمز وصول قصير العمر لـ youtube.readonly، دون واجهة. يرمي `AuthExpired`
  /// إن لم تعد الجلسة صالحة، و`AppFailure(notSignedIn)` دون جلسة.
  Future<String> accessToken();

  /// يُستدعى عندما يرفض الخادم الرمز (401) ليُحذف من ذاكرة النظام، ثم يُطلب
  /// رمز جديد بـ [accessToken].
  Future<void> invalidateAccessToken(String token);

  /// يمسح بيانات الدخول من الجهاز. يرمي `AppFailure(signOutFailed)` إن تعذّر
  /// المسح (وتبقى الحالة كما هي).
  Future<void> signOut();
}
