import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// محرك النطق عبر `flutter_tts` (D7): أصوات الجهاز، بلا إنترنت.
///
/// لا يُستخدم `awaitSpeakCompletion` لأن الإيقاف على أندرويد يترك وعده معلّقاً؛
/// بدلاً منه وعد لكل مقطع يكتمل بحدث الانتهاء أو الخطأ أو بـ [stop].
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine({FlutterTts? tts}) : _ttsOverride = tts;

  final FlutterTts? _ttsOverride;
  FlutterTts? _tts;
  Future<FlutterTts>? _ready;
  Completer<SpeakResult>? _pending;

  /// قناة صغيرة في MainActivity تفتح إعدادات «تحويل النص إلى كلام».
  static const _settings = MethodChannel('com.adeebai.adeeb/tts_settings');

  Future<FlutterTts> _init() => _ready ??= () async {
    final tts = _ttsOverride ?? FlutterTts();
    tts.setCompletionHandler(() => _complete(SpeakResult.done));
    tts.setErrorHandler((_) => _complete(SpeakResult.error));
    // أحداث الإلغاء تصل متأخرة وقد تخص مقطعاً سابقاً؛ الإيقاف نعرفه من stop().
    if (Platform.isIOS) {
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
    await tts.awaitSpeakCompletion(false);
    _tts = tts;
    return tts;
  }();

  void _complete(SpeakResult result) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  @override
  Future<List<TtsVoice>> arabicVoices() async {
    final tts = await _init();
    final raw = await tts.getVoices;
    final voices = <TtsVoice>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is! Map) continue;
        final name = v['name']?.toString();
        final locale = v['locale']?.toString();
        if (name == null || locale == null) continue;
        if (!TtsVoice.isArabicLocale(locale)) continue;
        // أصوات تحتاج الشبكة لا تعمل دون إنترنت.
        if (v['network_required']?.toString() == '1') continue;
        voices.add(TtsVoice(name: name, locale: locale));
      }
    }
    voices.sort((a, b) {
      final byLocale = a.locale.compareTo(b.locale);
      return byLocale != 0 ? byLocale : a.name.compareTo(b.name);
    });
    return voices;
  }

  @override
  Future<void> configure({TtsVoice? voice, required double speed}) async {
    final tts = await _init();
    if (voice == null) {
      await tts.setLanguage('ar');
    } else {
      await tts.setVoice({'name': voice.name, 'locale': voice.locale});
    }
    // أندرويد: القيمة × 2 هي معدّل المحرك (0.5 = العادي). iOS: 0.5 هو المعدّل
    // الافتراضي و1 أقصاه.
    await tts.setSpeechRate((speed * 0.5).clamp(0.1, 1.0));
  }

  @override
  Future<SpeakResult> speak(String text) async {
    final tts = await _init();
    _complete(SpeakResult.cancelled);
    final pending = Completer<SpeakResult>();
    _pending = pending;
    try {
      await tts.speak(text);
    } on Object {
      _complete(SpeakResult.error);
    }
    return pending.future;
  }

  @override
  Future<void> stop() async {
    _complete(SpeakResult.cancelled);
    final tts = _tts;
    if (tts == null) return;
    await tts.stop();
    _complete(SpeakResult.cancelled);
  }

  @override
  Future<bool> openInstallSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _settings.invokeMethod<bool>('open') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
