import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// أقل ما يلزم: علامة "توجد جلسة" فقط، لنعرف عند الإقلاع هل نستعيد الجلسة
/// صامتاً وهل نعرض "انتهت جلستك". لا رموز ولا بريد ولا اسم (Play Services يدير
/// الجلسة ويصدر الرموز).
abstract interface class AuthSessionStore {
  Future<bool> hasSession();
  Future<void> markSignedIn();
  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static const key = 'auth_session';

  @override
  Future<bool> hasSession() async => await _storage.read(key: key) == '1';

  @override
  Future<void> markSignedIn() => _storage.write(key: key, value: '1');

  @override
  Future<void> clear() => _storage.delete(key: key);
}
