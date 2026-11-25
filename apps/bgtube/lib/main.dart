import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'audio/audio_init.dart';
import 'core/providers.dart';
import 'data/extractor/youtube_explode_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الربط الوحيد لتنفيذ الاستخراج (D4).
  final handler = await initAudioHandler(YoutubeExplodeResolver());
  runApp(ProviderScope(
    overrides: [playbackControllerProvider.overrideWithValue(handler)],
    child: const BgtubeApp(),
  ));
}
