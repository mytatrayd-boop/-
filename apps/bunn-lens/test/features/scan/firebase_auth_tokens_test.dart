import 'package:bunn_lens/data/services/firebase_auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

class _G implements AuthGateway {
  _G({this.id = 'ID', this.ac = 'AC', this.idThrows = false, this.acThrows = false});
  final String? id;
  final String? ac;
  final bool idThrows;
  final bool acThrows;
  @override
  Future<String?> idToken() async => idThrows ? throw StateError('x') : id;
  @override
  Future<String?> appCheckToken() async => acThrows ? throw StateError('x') : ac;
}

void main() {
  test('توكنان صالحان', () async {
    final h = await FirebaseAuthTokens(_G()).headers();
    expect((h!.idToken, h.appCheck), ('ID', 'AC'));
  });

  test('فشل App Check لا يمنع الإرسال (الوسيط يقرر)', () async {
    final h = await FirebaseAuthTokens(_G(acThrows: true)).headers();
    expect(h!.idToken, 'ID');
    expect(h.appCheck, isNull);
    final empty = await FirebaseAuthTokens(_G(ac: '')).headers();
    expect(empty!.appCheck, isNull);
  });

  test('بلا توكن هوية أو فشله = null (unauthorized)', () async {
    expect(await FirebaseAuthTokens(_G(id: null)).headers(), isNull);
    expect(await FirebaseAuthTokens(_G(id: '')).headers(), isNull);
    expect(await FirebaseAuthTokens(_G(idThrows: true)).headers(), isNull);
  });
}
