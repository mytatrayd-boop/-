import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration, passed with `--dart-define-from-file=env.json`
/// (see env.example.json). Without Firebase values the app runs in local
/// demo mode only, which is handy before the Firebase project exists.
class AppConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: 'sa.asraty.app');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');

  /// Must match REGION in functions/src/config.ts.
  static const functionsRegion = String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'me-central2');

  /// Base URL of the API server (Vercel), e.g. https://asraty-server.vercel.app.
  /// With EMULATOR_HOST it defaults to the local dev server (functions: npm run dev).
  static String get serverUrl {
    const url = String.fromEnvironment('SERVER_URL');
    if (url.isNotEmpty) return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return emulatorHost.isEmpty ? '' : 'http://$emulatorHost:5055';
  }

  /// Host of the Firebase Emulator Suite (e.g. 10.0.2.2 for the Android emulator). Empty = production.
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST');

  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');

  static String? get _appId {
    if (kIsWeb) return _webAppId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId,
      TargetPlatform.iOS => _iosAppId,
      _ => null,
    };
  }

  static bool get firebaseConfigured => _apiKey.isNotEmpty && _projectId.isNotEmpty && (_appId ?? '').isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId!,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _bucket.isEmpty ? '$_projectId.firebasestorage.app' : _bucket,
        iosBundleId: _iosBundleId,
      );
}
