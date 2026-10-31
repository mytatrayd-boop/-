import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analysis_service.dart';

/// واجهة رفيعة فوق Firebase ليسهل اختبار [FirebaseAuthTokens].
abstract class AuthGateway {
  /// يضمن وجود مستخدم (ضيف مجهول إن لم يوجد) ويعيد توكن الهوية.
  Future<String?> idToken();
  Future<String?> appCheckToken();
}

class FirebaseAuthGateway implements AuthGateway {
  @override
  Future<String?> idToken() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    return user?.getIdToken();
  }

  @override
  Future<String?> appCheckToken() => FirebaseAppCheck.instance.getToken();
}

class FirebaseAuthTokens implements AuthTokens {
  FirebaseAuthTokens(this._gateway);
  final AuthGateway _gateway;

  @override
  Future<AuthHeaders?> headers() async {
    try {
      final id = await _gateway.idToken();
      if (id == null || id.isEmpty) return null;
      String? ac;
      try {
        ac = await _gateway.appCheckToken();
      } catch (_) {
        ac = null; // الوسيط يقرر قبوله بدونه
      }
      return AuthHeaders(idToken: id, appCheck: ac == null || ac.isEmpty ? null : ac);
    } catch (_) {
      return null;
    }
  }
}
