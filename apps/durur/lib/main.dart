import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(fontLicenses);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const DururApp(),
    ),
  );
}

/// رخص الخطوط المضمّنة (SIL OFL 1.1) لصفحة الرخص في النظام.
Stream<LicenseEntry> fontLicenses() async* {
  for (final (family, file) in const [
    ('Almarai', 'assets/fonts/Almarai-OFL.txt'),
    ('Amiri', 'assets/fonts/Amiri-OFL.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks([
      family,
    ], await rootBundle.loadString(file));
  }
}
