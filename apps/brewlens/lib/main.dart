import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicense);
  final config = resolveAppConfig(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
    revenueCatKey:
        Platform.isIOS ? Env.revenueCatAppleKey : Env.revenueCatGoogleKey,
  );
  if (!config.isDemo) {
    // تنفيذات Supabase تُضاف في الدفعة د (ARCHITECTURE §13). لا نعرض بيانات
    // نموذجية في بناء حقيقي (F1 معيار 6).
    throw UnsupportedError('Supabase backend is not implemented yet');
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: demoOverrides(prefs),
      child: const BrewLensApp(),
    ),
  );
}

Stream<LicenseEntry> _fontLicense() async* {
  yield LicenseEntryWithLineBreaks(
    const ['Tajawal'],
    await rootBundle.loadString('assets/fonts/OFL-Tajawal.txt'),
  );
}
