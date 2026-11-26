import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/app_failure.dart';
import '../../domain/ports/auth_service.dart';
import 'auth_session_store.dart';
import 'google_auth_gateway.dart';

/// تنفيذ [AuthService]. الرمز في الذاكرة فقط (لمسحه من ذاكرة Play Services عند
/// الخروج)؛ لا يُسجَّل ولا يُخزَّن.
class GoogleAuthService implements AuthService {
  GoogleAuthService(
    this._gateway,
    this._session, {
    this.interactiveTimeout = const Duration(minutes: 3),
    this.silentTimeout = const Duration(seconds: 20),
  });

  /// مهلة شاشة الدخول (يتضمّن وقت المستخدم)؛ تجاوزها = signInFailed.
  final Duration interactiveTimeout;

  /// مهلة الرمز الصامت؛ تجاوزها = network.
  final Duration silentTimeout;

  final GoogleAuthGateway _gateway;
  final AuthSessionStore _session;
  final _changes = StreamController<AuthStatus>.broadcast();

  static const scopes = [youtubeReadonlyScope];

  AuthStatus _status = AuthStatus.signedOut;
  Future<void>? _init;
  String? _lastToken;

  @override
  AuthStatus get status => _status;

  @override
  Stream<AuthStatus> get statusChanges => _changes.stream;

  void _set(AuthStatus s) {
    if (s == _status) return;
    _status = s;
    _changes.add(s);
  }

  /// `initialize` مرة واحدة فقط؛ إن فشل يُعاد في المحاولة التالية.
  Future<void> _ensureInit() {
    return _init ??= _gateway.initialize().catchError((Object e) {
      _init = null;
      throw e;
    });
  }

  @override
  Future<void> restore() async {
    bool had;
    try {
      had = await _session.hasSession();
    } catch (e) {
      debugPrint('auth session read failed: ${e.runtimeType}');
      had = false;
    }
    if (!had) {
      _set(AuthStatus.signedOut);
      return;
    }
    _set(AuthStatus.signedIn);
    try {
      await accessToken();
    } on AuthExpired {
      // الحالة صارت expired.
    } catch (e) {
      // شبكة أو غيرها: تبقى الجلسة، ويُعاد الطلب عند أول استخدام.
      debugPrint('auth restore deferred: ${e.runtimeType}');
    }
  }

  @override
  Future<SignInOutcome> signIn() async {
    final String token;
    try {
      await _ensureInit();
      token = await _gateway.interactiveToken(scopes).timeout(interactiveTimeout);
    } on TimeoutException {
      throw const AppFailure(FailureKind.signInFailed, 'timeout');
    } on GoogleSignInException catch (e) {
      final kind = classifySignInError(e);
      if (kind == null) return SignInOutcome.canceled;
      throw AppFailure(kind, e.code.name);
    } catch (e) {
      throw AppFailure(FailureKind.signInFailed, e.runtimeType.toString());
    }
    _lastToken = token;
    try {
      await _session.markSignedIn();
    } catch (e) {
      // الجلسة تعمل الآن، لكنها لن تُستعاد بعد إعادة التشغيل.
      debugPrint('auth session write failed: ${e.runtimeType}');
    }
    _set(AuthStatus.signedIn);
    return SignInOutcome.signedIn;
  }

  @override
  Future<String> accessToken() async {
    if (_status == AuthStatus.signedOut) {
      throw const AppFailure(FailureKind.notSignedIn);
    }
    if (_status == AuthStatus.expired) throw const AuthExpired();
    final String? token;
    try {
      await _ensureInit();
      token = await _gateway.silentToken(scopes).timeout(silentTimeout);
    } on TimeoutException {
      throw const AppFailure(FailureKind.network, 'timeout');
    } on GoogleSignInException catch (e) {
      final kind = classifySignInError(e);
      throw AppFailure(
        kind == FailureKind.network ? FailureKind.network : FailureKind.signInFailed,
        e.code.name,
      );
    } catch (e) {
      throw AppFailure(FailureKind.signInFailed, e.runtimeType.toString());
    }
    // خرج المستخدم أثناء الطلب.
    if (_status == AuthStatus.signedOut) {
      throw const AppFailure(FailureKind.notSignedIn);
    }
    if (token == null) {
      _lastToken = null;
      _set(AuthStatus.expired);
      throw const AuthExpired();
    }
    _lastToken = token;
    return token;
  }

  @override
  Future<void> invalidateAccessToken(String token) async {
    if (_lastToken == token) _lastToken = null;
    try {
      await _ensureInit();
      await _gateway.clearToken(token);
    } catch (e) {
      debugPrint('clear token failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> signOut() async {
    // أولاً العلامة: إن بقيت لاستُعيدت الجلسة بعد إعادة التشغيل.
    try {
      await _session.clear();
    } catch (e) {
      throw AppFailure(FailureKind.signOutFailed, e.runtimeType.toString());
    }
    final token = _lastToken;
    _lastToken = null;
    _set(AuthStatus.signedOut);
    try {
      await _ensureInit();
      if (token != null) await _gateway.clearToken(token);
      await _gateway.signOut();
    } catch (e) {
      // أفضل جهد: الجلسة المحلية مُسحت ولن تُستعاد.
      debugPrint('plugin sign-out failed: ${e.runtimeType}');
    }
  }
}

/// يحوّل خطأ google_sign_in إلى نوع فشل، أو null للإلغاء/الرفض (لا خطأ).
///
/// على أندرويد يصل إلغاء شاشة التفويض غالباً كـ `unknownError` بوصف ApiException
/// "16: ..." (CANCELED)، والشبكة "7: ..." وخطأ الإعداد (بصمة/حزمة) "10: ...".
/// الرفض يعيد رمزاً فارغاً فيرمي المكوّن "Platform returned null unexpectedly".
@visibleForTesting
FailureKind? classifySignInError(GoogleSignInException e) {
  final d = (e.description ?? '').toLowerCase();
  bool status(int code) => RegExp('(^|\\D)$code:').hasMatch(d);
  switch (e.code) {
    case GoogleSignInExceptionCode.canceled:
      return null;
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return FailureKind.signInUnavailable;
    default:
      break;
  }
  if (status(16) || d.contains('cancel') || d.contains('returned null')) return null;
  if (status(7) || d.contains('network')) return FailureKind.network;
  if (status(10) || d.contains('developer_error')) return FailureKind.signInUnavailable;
  return FailureKind.signInFailed;
}
