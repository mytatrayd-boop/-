import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/data/auth/auth_session_store.dart';
import 'package:bgtube/data/auth/google_auth_gateway.dart';
import 'package:bgtube/data/auth/google_auth_service.dart';
import 'package:bgtube/data/settings/prefs_risk_ack_store.dart';
import 'package:bgtube/domain/ports/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FakeGateway implements GoogleAuthGateway {
  int initCalls = 0;
  Object? initError;
  Object? interactive = 'tok-1'; // String أو استثناء
  Object? silent = 'tok-2'; // String أو null أو استثناء
  final cleared = <String>[];
  int signOutCalls = 0;
  Object? signOutError;
  List<String>? lastScopes;

  @override
  Future<void> initialize() async {
    initCalls++;
    final e = initError;
    if (e != null) throw e;
  }

  @override
  Future<String> interactiveToken(List<String> scopes) async {
    lastScopes = scopes;
    final r = interactive;
    if (r is String) return r;
    throw r!;
  }

  @override
  Future<String?> silentToken(List<String> scopes) async {
    lastScopes = scopes;
    final r = silent;
    if (r == null || r is String) return r as String?;
    throw r;
  }

  @override
  Future<void> clearToken(String token) async => cleared.add(token);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final e = signOutError;
    if (e != null) throw e;
  }
}

class MemSession implements AuthSessionStore {
  MemSession([this.has = false]);
  bool has;
  bool failClear = false;
  @override
  Future<bool> hasSession() async => has;
  @override
  Future<void> markSignedIn() async => has = true;
  @override
  Future<void> clear() async {
    if (failClear) throw StateError('keystore');
    has = false;
  }
}

GoogleSignInException gse(GoogleSignInExceptionCode code, [String? d]) =>
    GoogleSignInException(code: code, description: d);

void main() {
  late FakeGateway gw;
  late MemSession session;
  late GoogleAuthService auth;

  setUp(() {
    gw = FakeGateway();
    session = MemSession();
    auth = GoogleAuthService(gw, session);
  });

  group('signIn', () {
    test('success: signed in, session flag saved, youtube.readonly only', () async {
      final events = <AuthStatus>[];
      auth.statusChanges.listen(events.add);
      expect(await auth.signIn(), SignInOutcome.signedIn);
      expect(auth.status, AuthStatus.signedIn);
      expect(session.has, isTrue);
      expect(gw.lastScopes, ['https://www.googleapis.com/auth/youtube.readonly']);
      await pumpEventQueue();
      expect(events, [AuthStatus.signedIn]);
    });

    for (final e in [
      gse(GoogleSignInExceptionCode.canceled),
      gse(GoogleSignInExceptionCode.unknownError, 'SDK reported an exception: 16: Cancelled by user.'),
      gse(GoogleSignInExceptionCode.unknownError, 'Platform returned null unexpectedly.'),
    ]) {
      test('cancel/deny is not an error (${e.description ?? e.code.name})', () async {
        gw.interactive = e;
        expect(await auth.signIn(), SignInOutcome.canceled);
        expect(auth.status, AuthStatus.signedOut);
        expect(session.has, isFalse);
      });
    }

    final cases = <(GoogleSignInException, FailureKind)>[
      (gse(GoogleSignInExceptionCode.unknownError, 'SDK reported an exception: 7: NETWORK_ERROR'), FailureKind.network),
      (gse(GoogleSignInExceptionCode.unknownError, 'SDK reported an exception: 10: DEVELOPER_ERROR'), FailureKind.signInUnavailable),
      (gse(GoogleSignInExceptionCode.clientConfigurationError), FailureKind.signInUnavailable),
      (gse(GoogleSignInExceptionCode.uiUnavailable), FailureKind.signInFailed),
      (gse(GoogleSignInExceptionCode.unknownError, 'Authorization failed: boom'), FailureKind.signInFailed),
    ];
    for (final (e, kind) in cases) {
      test('${e.code.name} "${e.description}" -> $kind', () async {
        gw.interactive = e;
        await expectLater(auth.signIn(), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', kind)));
        expect(auth.status, AuthStatus.signedOut);
        expect(session.has, isFalse);
      });
    }

    test('non-plugin error -> signInFailed', () async {
      gw.interactive = StateError('x');
      await expectLater(auth.signIn(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.signInFailed)));
    });

    test('failure detail never contains the token', () async {
      gw.interactive = 'secret-token';
      await auth.signIn();
      gw.silent = gse(GoogleSignInExceptionCode.unknownError, 'x');
      try {
        await auth.accessToken();
        fail('should throw');
      } on AppFailure catch (f) {
        expect(f.toString(), isNot(contains('secret-token')));
      }
    });

    test('session write failure still signs in for this run', () async {
      final s = _FailingWriteSession();
      final a = GoogleAuthService(gw, s);
      expect(await a.signIn(), SignInOutcome.signedIn);
      expect(a.status, AuthStatus.signedIn);
    });
  });

  group('initialize', () {
    test('called once across calls, retried after a failure', () async {
      gw.initError = StateError('init');
      await expectLater(auth.signIn(), throwsA(isA<AppFailure>()));
      gw.initError = null;
      await auth.signIn();
      await auth.accessToken();
      expect(gw.initCalls, 2);
    });
  });

  group('restore (app restart)', () {
    test('no saved session: signed out and the plugin is not touched', () async {
      await auth.restore();
      expect(auth.status, AuthStatus.signedOut);
      expect(gw.initCalls, 0);
    });

    test('saved session + silent token: stays signed in', () async {
      session.has = true;
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
      expect(await auth.accessToken(), 'tok-2');
    });

    test('saved session but grant gone: expired, accessToken throws AuthExpired', () async {
      session.has = true;
      gw.silent = null;
      final events = <AuthStatus>[];
      auth.statusChanges.listen(events.add);
      await auth.restore();
      expect(auth.status, AuthStatus.expired);
      await expectLater(auth.accessToken(), throwsA(isA<AuthExpired>()));
      await pumpEventQueue();
      expect(events, [AuthStatus.signedIn, AuthStatus.expired]);
      // يبقى العلَم: بعد إعادة التشغيل يُعرض "انتهت جلستك" لا "غير مسجّل".
      expect(session.has, isTrue);
    });

    test('saved session + network error: keeps the session', () async {
      session.has = true;
      gw.silent = gse(GoogleSignInExceptionCode.unknownError, 'Authorization failed: 7: network');
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
    });

    test('unreadable storage: signed out, no crash', () async {
      final a = GoogleAuthService(gw, _FailingReadSession());
      await a.restore();
      expect(a.status, AuthStatus.signedOut);
    });

    test('expired then sign in again recovers', () async {
      session.has = true;
      gw.silent = null;
      await auth.restore();
      expect(auth.status, AuthStatus.expired);
      gw.silent = 'tok-3';
      await auth.signIn();
      expect(auth.status, AuthStatus.signedIn);
      expect(await auth.accessToken(), 'tok-3');
    });
  });

  group('accessToken', () {
    test('signed out -> notSignedIn', () async {
      await expectLater(auth.accessToken(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.notSignedIn)));
    });

    test('revoked later -> AuthExpired and status expired', () async {
      await auth.signIn();
      gw.silent = null;
      await expectLater(auth.accessToken(), throwsA(isA<AuthExpired>()));
      expect(auth.status, AuthStatus.expired);
    });

    test('network error -> AppFailure(network), status unchanged', () async {
      await auth.signIn();
      gw.silent = gse(GoogleSignInExceptionCode.unknownError, 'Authorization failed: 7: x');
      await expectLater(auth.accessToken(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.network)));
      expect(auth.status, AuthStatus.signedIn);
    });

    test('invalidateAccessToken clears the token in the system cache', () async {
      await auth.signIn();
      await auth.invalidateAccessToken('tok-2');
      expect(gw.cleared, ['tok-2']);
    });
  });

  group('signOut', () {
    test('wipes the session flag and token cache; restart stays signed out', () async {
      await auth.signIn();
      await auth.accessToken(); // tok-2
      await auth.signOut();
      expect(auth.status, AuthStatus.signedOut);
      expect(session.has, isFalse);
      expect(gw.cleared, ['tok-2']);
      expect(gw.signOutCalls, 1);
      await expectLater(auth.accessToken(), throwsA(isA<AppFailure>()));

      final restarted = GoogleAuthService(FakeGateway(), session);
      await restarted.restore();
      expect(restarted.status, AuthStatus.signedOut);
    });

    test('storage failure -> signOutFailed and still signed in', () async {
      await auth.signIn();
      session.failClear = true;
      await expectLater(auth.signOut(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.signOutFailed)));
      expect(auth.status, AuthStatus.signedIn);
    });

    test('plugin sign-out failure is best effort (local session gone)', () async {
      await auth.signIn();
      gw.signOutError = StateError('x');
      await auth.signOut();
      expect(auth.status, AuthStatus.signedOut);
      expect(session.has, isFalse);
    });
  });

  group('classifySignInError', () {
    test('does not mistake other status numbers', () {
      expect(classifySignInError(gse(GoogleSignInExceptionCode.unknownError, 'exception: 116: x')),
          FailureKind.signInFailed);
    });
  });

  group('SecureAuthSessionStore', () {
    test('stores only a flag under a single key and clears it', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final s = SecureAuthSessionStore(storage);
      expect(await s.hasSession(), isFalse);
      await s.markSignedIn();
      expect(await s.hasSession(), isTrue);
      expect(await storage.readAll(), {'auth_session': '1'});
      await s.clear();
      expect(await s.hasSession(), isFalse);
      expect(await storage.readAll(), isEmpty);
    });
  });

  group('PrefsRiskAckStore', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());
    test('round-trips', () async {
      final s = PrefsRiskAckStore(SharedPreferencesAsync());
      expect(await s.isAcknowledged(), isFalse);
      await s.acknowledge();
      expect(await PrefsRiskAckStore(SharedPreferencesAsync()).isAcknowledged(), isTrue);
    });
  });
}

class _FailingWriteSession extends MemSession {
  @override
  Future<void> markSignedIn() async => throw StateError('keystore');
}

class _FailingReadSession extends MemSession {
  @override
  Future<bool> hasSession() async => throw StateError('keystore');
}
