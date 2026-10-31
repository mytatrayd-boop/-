import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'data/db/app_database.dart';
import 'data/db/connection.dart';
import 'data/providers.dart';
import 'data/repositories/cafe_repository.dart';
import 'core/firebase_config.dart';
import 'data/repositories/scan_repository.dart';
import 'data/services/firebase_auth_tokens.dart';
import 'features/scan/scan_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final db = AppDatabase(openDeviceConnection());
  final repo = DriftScanRepository(
    db,
    imagesDir: Directory(p.join(docs.path, 'scan_images')),
  );
  final options = firebaseOptionsFor(isIos: defaultTargetPlatform == TargetPlatform.iOS);
  var firebaseReady = false;
  if (options != null) {
    try {
      await Firebase.initializeApp(options: options);
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
      );
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false; // بلا هوية: الفحص يفشل بـ«تعذّر التحقق» ولا يتعطل التطبيق
    }
  }
  runApp(ProviderScope(
    overrides: [
      if (firebaseReady) authTokensProvider.overrideWithValue(FirebaseAuthTokens(FirebaseAuthGateway())),
      scanRepositoryProvider.overrideWithValue(repo),
      cafeRepositoryProvider.overrideWithValue(DriftCafeRepository(db)),
    ],
    child: const BunnLensApp(),
  ));
}
