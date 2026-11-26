import 'dart:async';

import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/ports/auth_service.dart';
import 'package:bgtube/domain/ports/risk_ack_store.dart';

/// تنفيذ وهمي للمنفذ (لا google_sign_in).
class FakeAuthService implements AuthService {
  FakeAuthService([this._status = AuthStatus.signedOut]);

  AuthStatus _status;
  final _changes = StreamController<AuthStatus>.broadcast();

  /// نتيجة signIn التالية: SignInOutcome أو AppFailure يُرمى.
  Object nextSignIn = SignInOutcome.signedIn;
  Completer<void>? signInGate;
  AppFailure? signOutError;
  int signInCalls = 0;
  int signOutCalls = 0;

  void emit(AuthStatus s) {
    _status = s;
    _changes.add(s);
  }

  @override
  AuthStatus get status => _status;
  @override
  Stream<AuthStatus> get statusChanges => _changes.stream;
  @override
  Future<void> restore() async {}

  @override
  Future<SignInOutcome> signIn() async {
    signInCalls++;
    await signInGate?.future;
    final r = nextSignIn;
    if (r is AppFailure) throw r;
    if (r == SignInOutcome.signedIn) emit(AuthStatus.signedIn);
    return r as SignInOutcome;
  }

  @override
  Future<String> accessToken() async => 'fake-token';
  @override
  Future<void> invalidateAccessToken(String token) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final e = signOutError;
    if (e != null) throw e;
    emit(AuthStatus.signedOut);
  }
}

class MemRiskAckStore implements RiskAckStore {
  MemRiskAckStore([this.value = false]);
  bool value;
  @override
  Future<bool> isAcknowledged() async => value;
  @override
  Future<void> acknowledge() async => value = true;
}
