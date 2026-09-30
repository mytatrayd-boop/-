import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/firebase_backend.dart';
import 'config.dart';
import 'ui/app.dart';
import 'ui/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  var firebaseReady = false;
  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      const host = AppConfig.emulatorHost;
      if (host.isNotEmpty) {
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      }
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init failed, running demo only: $e');
    }
  }

  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      if (firebaseReady) realBackendFactoryProvider.overrideWithValue(FirebaseBackend.new),
    ],
    child: const AsratyApp(),
  ));
}
