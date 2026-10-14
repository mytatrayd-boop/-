import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/client_info.dart';
import '../core/device_id.dart';
import '../library/library_providers.dart';
import '../reader/reader_settings.dart';
import '../storage/passage_retriever.dart';
import 'ask_api.dart';
import 'ask_service.dart';
import 'last_answer.dart';

/// مفاتيح shared_preferences.
const deviceIdKey = 'ask.device_id';
const ageConfirmedKey = 'ask.age_confirmed';
const lastAnswerKey = 'ask.last_answer';

/// عميل HTTP للخادم الوسيط (منفصل عن عميل المكتبة ليُستبدل في الاختبار).
final askHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// معرّف الجهاز العشوائي (D11)، يُولَّد مرة ويُحفظ محلياً.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return loadOrCreateDeviceId(
    read: () => prefs.getString(deviceIdKey),
    write: (id) => prefs.setString(deviceIdKey, id),
  );
});

final askApiProvider = Provider<AskApi>(
  (ref) => HttpAskApi(
    client: ref.watch(askHttpClientProvider),
    baseUri: ref.watch(appConfigProvider).askApiBaseUri,
    deviceId: () => ref.read(deviceIdProvider.future),
    clientHeader: clientHeader(
      ios: defaultTargetPlatform == TargetPlatform.iOS,
    ),
  ),
);

final passageRetrieverProvider = Provider<PassageRetriever>(
  (ref) => SqlitePassageRetriever(
    '${ref.watch(storageDirectoryProvider).path}/adeeb.db',
  ),
);

final askServiceProvider = Provider<AskService>(
  (ref) => AskService(
    retriever: ref.watch(passageRetrieverProvider),
    api: ref.watch(askApiProvider),
  ),
);

/// تأكيد العمر 18+ وقراءة تنبيه أول استخدام (D13، DESIGN §12.1)، مرة واحدة.
final ageConfirmedProvider = AsyncNotifierProvider<AgeConfirmed, bool>(
  AgeConfirmed.new,
);

class AgeConfirmed extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(ageConfirmedKey) ?? false;
  }

  Future<void> confirm() async {
    state = const AsyncData(true);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(ageConfirmedKey, true);
  }

  /// من الإعدادات: يعود تنبيه أول استخدام وتأكيد العمر عند الفتح التالي.
  Future<void> reset() async {
    state = const AsyncData(false);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.remove(ageConfirmedKey);
  }
}

/// آخر إجابة فقط (لا سجل): تُعرض عند العودة إلى الشاشة.
final lastAnswerProvider = AsyncNotifierProvider<LastAnswer, AskAnswer?>(
  LastAnswer.new,
);

class LastAnswer extends AsyncNotifier<AskAnswer?> {
  @override
  Future<AskAnswer?> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return decodeLastAnswer(prefs.getString(lastAnswerKey));
  }

  /// يستبدل المحفوظ بـ [answer]، أو يحذفه إن كان null.
  Future<void> set(AskAnswer? answer) async {
    state = AsyncData(answer);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (answer == null) {
      await prefs.remove(lastAnswerKey);
    } else {
      await prefs.setString(lastAnswerKey, encodeLastAnswer(answer));
    }
  }
}
