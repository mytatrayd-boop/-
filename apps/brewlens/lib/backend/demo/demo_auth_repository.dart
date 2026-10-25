import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_failure.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators.dart';

/// مصادقة وضع العرض: تقبل أي بريد صالح وكلمة مرور 6 أحرف فأكثر، والجلسة
/// محفوظة في shared_preferences. لا اتصال بأي خادم.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._prefs, {this.latency = const Duration(milliseconds: 600)})
      : _session = _read(_prefs);

  static const sessionKey = 'demo_auth_session';

  final SharedPreferences _prefs;
  final Duration latency;
  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;

  static AuthSession? _read(SharedPreferences prefs) {
    final raw = prefs.getString(sessionKey);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> sessionChanges() => _controller.stream;

  Future<AuthSession> _start(String email, String password) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    if (!isValidEmail(normalized) || password.length < demoMinPasswordLength) {
      throw const AppFailure(FailureCode.invalidCredentials);
    }
    final session = AuthSession(userId: 'demo-$normalized', email: normalized);
    await _prefs.setString(sessionKey, jsonEncode(session.toJson()));
    _session = session;
    _controller.add(session);
    return session;
  }

  @override
  Future<AuthSession> signIn({required String email, required String password}) =>
      _start(email, password);

  @override
  Future<AuthSession> signUp({required String email, required String password}) =>
      _start(email, password);

  @override
  Future<void> sendPasswordReset(String email) async {
    // شكلية في وضع العرض: لا يُرسل أي بريد.
    await Future<void>.delayed(latency);
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(sessionKey);
    _session = null;
    _controller.add(null);
  }
}
