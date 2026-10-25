import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_failure.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/auth_repository.dart';

/// حذف الحساب في وضع العرض: يمسح كل بيانات العرض المحلية (التقييمات، المقاهي،
/// المفضلة، العدّاد، المحاكاة، الجلسة) ومجلد الصور، ثم يخرج. تُبقى اللغة فقط
/// لأنها تفضيل للجهاز لا بيانات حساب.
class DemoAccountRepository implements AccountRepository {
  DemoAccountRepository(this._prefs, this._imagesDir, this._auth);

  static const keptKeys = {'locale'};

  final SharedPreferences _prefs;
  final Future<Directory> Function() _imagesDir;
  final AuthRepository _auth;

  @override
  Future<void> deleteAccount() async {
    try {
      final dir = await _imagesDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      throw const AppFailure(FailureCode.deleteFailed);
    }
    for (final key in _prefs.getKeys().toList()) {
      if (!keptKeys.contains(key)) await _prefs.remove(key);
    }
    await _auth.signOut();
  }
}
