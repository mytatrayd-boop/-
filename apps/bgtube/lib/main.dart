import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'audio/audio_init.dart';
import 'core/providers.dart';
import 'data/local/app_database.dart';
import 'data/auth/auth_session_store.dart';
import 'data/auth/google_auth_gateway.dart';
import 'data/auth/google_auth_service.dart';
import 'data/settings/prefs_locale_store.dart';
import 'data/settings/prefs_risk_ack_store.dart';
import 'data/settings/prefs_speed_store.dart';
import 'data/local/drift_api_cache_store.dart';
import 'data/local/drift_local_playlist_repository.dart';
import 'data/local/drift_position_repository.dart';
import 'data/local/drift_queue_repository.dart';
import 'data/incoming/receive_sharing_link_source.dart';
import 'data/extractor/youtube_explode_resolver.dart';
import 'data/youtube_api/quota_meter.dart';
import 'data/youtube_api/youtube_data_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الربط الوحيد لتنفيذ الاستخراج (D4).
  final db = AppDatabase(driftDatabase(name: 'bgtube'));
  final handler = await initAudioHandler(
    YoutubeExplodeResolver(),
    positions: DriftPositionRepository(db),
    speedStore: PrefsSpeedStore(),
    queueRepository: DriftQueueRepository(db),
  );
  // الطابور المحفوظ يظهر دون استخراج ولا تشغيل تلقائي (D27)، ولا يؤخر الإقلاع.
  unawaited(handler.restoreQueue());
  final localeStore = PrefsLocaleStore();
  String? languageCode;
  try {
    languageCode = await localeStore.load();
  } catch (_) {
    // فشل القراءة: لغة الجهاز/العربية.
  }
  final info = await PackageInfo.fromPlatform();
  // الحساب (D7/D22): لا يُمرَّر إلى المستخرج أبداً. الاستعادة صامتة ولا تؤخر الإقلاع.
  final auth = GoogleAuthService(PluginGoogleAuthGateway(), SecureAuthSessionStore());
  // الواجهة الرسمية (D29): رمز الحساب يمر هنا فقط، لا إلى المستخرج.
  final api = YouTubeDataApi(
    auth: auth,
    client: http.Client(),
    cache: DriftApiCacheStore(db),
    quota: QuotaMeter(DriftQuotaStore(db)),
  );
  // بعد الاستعادة: دون جلسة يُمسح كاش الواجهة كله (خصوصية، D29).
  unawaited(auth.restore().then((_) => api.clearIfSignedOut()));
  runApp(ProviderScope(
    overrides: [
      localeStoreProvider.overrideWithValue(localeStore),
      initialLanguageCodeProvider.overrideWithValue(languageCode),
      appVersionProvider.overrideWithValue(info.version),
      playbackControllerProvider.overrideWithValue(handler),
      playbackQueueProvider.overrideWithValue(handler),
      localPlaylistRepositoryProvider.overrideWithValue(DriftLocalPlaylistRepository(db)),
      incomingLinkSourceProvider.overrideWithValue(ReceiveSharingLinkSource()),
      authServiceProvider.overrideWithValue(auth),
      youTubeApiProvider.overrideWithValue(api),
      riskAckStoreProvider.overrideWithValue(PrefsRiskAckStore()),
    ],
    child: const BgtubeApp(),
  ));
}
