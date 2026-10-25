import 'package:brewlens/backend/demo/demo_auth_repository.dart';
import 'package:brewlens/domain/models/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DemoAuthRepository repo() => DemoAuthRepository(prefs, latency: Duration.zero);

  test('starts without a session', () {
    expect(repo().currentSession, isNull);
  });

  test('sign in accepts any valid email with 6+ chars and persists session', () async {
    final r = repo();
    final emitted = <String?>[];
    final sub = r.sessionChanges().listen((s) => emitted.add(s?.email));
    final s = await r.signIn(email: ' User@Example.com ', password: '123456');
    expect(s.email, 'user@example.com');
    expect(r.currentSession?.email, 'user@example.com');
    await Future<void>.delayed(Duration.zero);
    expect(emitted, ['user@example.com']);
    // جلسة باقية بعد إعادة التشغيل (F2 معيار 5).
    expect(repo().currentSession?.email, 'user@example.com');
    await sub.cancel();
  });

  test('sign up works the same in demo mode', () async {
    final s = await repo().signUp(email: 'a@b.co', password: 'abcdef');
    expect(s.userId, isNotEmpty);
  });

  test('rejects invalid email or short password', () async {
    final r = repo();
    await expectLater(
      r.signIn(email: 'not-an-email', password: '123456'),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', FailureCode.invalidCredentials)),
    );
    await expectLater(
      r.signIn(email: 'a@b.co', password: '12345'),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', FailureCode.invalidCredentials)),
    );
    expect(r.currentSession, isNull);
  });

  test('sign out clears the stored session and emits null', () async {
    final r = repo();
    await r.signIn(email: 'a@b.co', password: '123456');
    final next = r.sessionChanges().first;
    await r.signOut();
    expect(await next, isNull);
    expect(r.currentSession, isNull);
    expect(repo().currentSession, isNull);
  });

  test('password reset is a no-op that completes', () async {
    await expectLater(repo().sendPasswordReset('a@b.co'), completes);
  });
}
