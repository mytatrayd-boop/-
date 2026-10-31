import 'package:firebase_core/firebase_core.dart';

// معرّفات Firebase العامة (ليست أسراراً) تُمرَّر عبر --dart-define-from-file=.env
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _apiKeyAndroid = String.fromEnvironment('FIREBASE_API_KEY_ANDROID');
const _apiKeyIos = String.fromEnvironment('FIREBASE_API_KEY_IOS');
const _appIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
const _appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

/// خيارات Firebase للمنصة، أو null إن لم تُضبط القيم (فيعمل التطبيق بلا هوية).
FirebaseOptions? firebaseOptionsFor({required bool isIos}) {
  final apiKey = isIos ? _apiKeyIos : _apiKeyAndroid;
  final appId = isIos ? _appIdIos : _appIdAndroid;
  if (_projectId.isEmpty || apiKey.isEmpty || appId.isEmpty || _senderId.isEmpty) return null;
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
    iosBundleId: isIos ? 'com.bunnlens.bunnLens' : null,
  );
}
