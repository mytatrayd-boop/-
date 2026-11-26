import 'package:google_sign_in/google_sign_in.dart';

/// غلاف رفيع حول google_sign_in 7.x (قابل للاستبدال في الاختبارات).
///
/// نستخدم التفويض (authorization) فقط عبر `authorizationClient` بلا مصادقة
/// (`authenticate`)، لأن المصادقة على أندرويد تتطلب serverClientId (عميل ويب)
/// غير موجود لدينا. عميل OAuth من نوع Android يُعرَّف بالحزمة وبصمة SHA-1، فلا
/// clientId ولا serverClientId ولا سرّ في الكود.
abstract interface class GoogleAuthGateway {
  Future<void> initialize();

  /// بلا واجهة؛ null إن احتاج المستخدم للتفاعل (لا إذن أو سُحب).
  Future<String?> silentToken(List<String> scopes);

  /// اختيار الحساب والموافقة في شاشة جوجل. يرمي [GoogleSignInException].
  Future<String> interactiveToken(List<String> scopes);

  Future<void> clearToken(String token);

  Future<void> signOut();
}

class PluginGoogleAuthGateway implements GoogleAuthGateway {
  GoogleSignIn get _g => GoogleSignIn.instance;

  @override
  Future<void> initialize() => _g.initialize();

  @override
  Future<String?> silentToken(List<String> scopes) async =>
      (await _g.authorizationClient.authorizationForScopes(scopes))?.accessToken;

  @override
  Future<String> interactiveToken(List<String> scopes) async =>
      (await _g.authorizationClient.authorizeScopes(scopes)).accessToken;

  @override
  Future<void> clearToken(String token) =>
      _g.authorizationClient.clearAuthorizationToken(accessToken: token);

  @override
  Future<void> signOut() => _g.signOut();
}
