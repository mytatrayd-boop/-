import '../models/auth_session.dart';

/// المصادقة بالبريد وكلمة المرور (D5). الأخطاء تُرمى كـ AppFailure.
abstract interface class AuthRepository {
  /// الجلسة الحالية (متاحة فوراً عند التشغيل).
  AuthSession? get currentSession;

  /// يبث كل تغيير في الجلسة (دخول، خروج، انتهاء).
  Stream<AuthSession?> sessionChanges();

  Future<AuthSession> signIn({required String email, required String password});

  Future<AuthSession> signUp({required String email, required String password});

  /// يرسل رابط الاستعادة. الرد نفسه سواء وُجد البريد أم لا.
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
