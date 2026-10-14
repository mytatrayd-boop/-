import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'library/library_providers.dart';
import 'settings/sources_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final storage = await getApplicationSupportDirectory();
  runApp(
    ProviderScope(
      overrides: [storageDirectoryProvider.overrideWithValue(storage)],
      child: const AdeebApp(),
    ),
  );
}
