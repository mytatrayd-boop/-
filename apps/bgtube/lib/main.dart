import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'audio/audio_init.dart';
import 'core/providers.dart';
import 'data/local/app_database.dart';
import 'data/settings/prefs_locale_store.dart';
import 'data/settings/prefs_speed_store.dart';
import 'data/local/drift_position_repository.dart';
import 'data/incoming/receive_sharing_link_source.dart';
import 'data/extractor/youtube_explode_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الربط الوحيد لتنفيذ الاستخراج (D4).
  final db = AppDatabase(driftDatabase(name: 'bgtube'));
  final handler = await initAudioHandler(
    YoutubeExplodeResolver(),
    positions: DriftPositionRepository(db),
    speedStore: PrefsSpeedStore(),
  );
  final localeStore = PrefsLocaleStore();
  String? languageCode;
  try {
    languageCode = await localeStore.load();
  } catch (_) {
    // فشل القراءة: لغة الجهاز/العربية.
  }
  final info = await PackageInfo.fromPlatform();
  runApp(ProviderScope(
    overrides: [
      localeStoreProvider.overrideWithValue(localeStore),
      initialLanguageCodeProvider.overrideWithValue(languageCode),
      appVersionProvider.overrideWithValue(info.version),
      playbackControllerProvider.overrideWithValue(handler),
      incomingLinkSourceProvider.overrideWithValue(ReceiveSharingLinkSource()),
    ],
    child: const BgtubeApp(),
  ));
}
