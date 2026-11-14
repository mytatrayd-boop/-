import 'dart:async';

import 'package:flutter/services.dart';

import 'rgba_frame.dart';

/// جودة التسجيل. الأرقام تطابق QualityProfile في Kotlin (4 و8 ميغابت/ث + AAC 96 كيلوبت).
enum RecorderQuality {
  p720('p720', 1280, 720, 4000000),
  p1080('p1080', 1920, 1080, 8000000);

  const RecorderQuality(this.key, this.width, this.height, this.videoBitrate);
  final String key;
  final int width;
  final int height;
  final int videoBitrate;

  static const audioBitrate = 96000;

  /// نصف اللوحة للخريطة (640x720 أو 960x1080).
  int get mapWidth => width ~/ 2;
  int get bytesPerSecond => (videoBitrate + audioBitrate) ~/ 8;
  int bytesFor(Duration d) => bytesPerSecond * d.inSeconds;
}

class RecorderException implements Exception {
  const RecorderException(this.code, [this.message]);
  final String code;
  final String? message;
  @override
  String toString() => 'RecorderException($code${message == null ? '' : ': $message'})';
}

class CameraInfo {
  const CameraInfo({required this.textureId, required this.width, required this.height});
  final int textureId;
  final int width;
  final int height;
}

class StorageInfo {
  const StorageInfo({required this.freeBytes, required this.bytesPerSecond, required this.bytesPer10Min});
  final int freeBytes;
  final int bytesPerSecond;
  final int bytesPer10Min;

  /// كم يتسع من التسجيل بالمساحة الحرة.
  Duration get remaining => Duration(seconds: bytesPerSecond == 0 ? 0 : freeBytes ~/ bytesPerSecond);
}

class RecordingConfig {
  const RecordingConfig({
    this.quality = RecorderQuality.p720,
    this.muted = false,
    this.segmentSeconds = 60,
    this.warnFreeBytes = 1 << 30,
    this.stopFreeBytes = 300 << 20,
  });
  final RecorderQuality quality;
  final bool muted;

  /// طول مقطع الحماية (يُغلق كل مقطع بسليم فلا يضيع ما قبله إن قُتلت العملية).
  final int segmentSeconds;
  final int warnFreeBytes;
  final int stopFreeBytes;
}

class RecordingResult {
  const RecordingResult({
    required this.path,
    required this.duration,
    required this.sizeBytes,
    this.segments = 1,
    this.skippedSegments = 0,
    this.hasMic = true,
  });
  final String path;
  final Duration duration;
  final int sizeBytes;
  final int segments;
  final int skippedSegments;
  final bool hasMic;

  factory RecordingResult.fromMap(Map<Object?, Object?> m) => RecordingResult(
    path: m['path']! as String,
    duration: Duration(milliseconds: (m['durationMs']! as num).toInt()),
    sizeBytes: (m['sizeBytes']! as num).toInt(),
    segments: (m['segments'] as num?)?.toInt() ?? 1,
    skippedSegments: (m['skippedSegments'] as num?)?.toInt() ?? 0,
    hasMic: m['hasMic'] as bool? ?? true,
  );
}

enum InterruptReason { background, cameraError, writeError, lowStorage, other }

sealed class RecorderEvent {
  const RecorderEvent();
}

/// توقّف التسجيل من الجانب الأصلي وحُفظ ما صُوِّر في [result] (SPEC F4).
class RecordingInterrupted extends RecorderEvent {
  const RecordingInterrupted(this.reason, this.result);
  final InterruptReason reason;
  final RecordingResult result;
}

class StorageUpdate extends RecorderEvent {
  const StorageUpdate(this.freeBytes);
  final int freeBytes;
}

/// المساحة تحت حد التنبيه (قبل الإيقاف التلقائي).
class LowStorageWarning extends RecorderEvent {
  const LowStorageWarning(this.freeBytes);
  final int freeBytes;
}

class CameraFailed extends RecorderEvent {
  const CameraFailed(this.reason);
  final String? reason;
}

class RecorderError extends RecorderEvent {
  const RecorderError(this.reason, this.message);
  final String reason;
  final String? message;
}

/// واجهة المُسجِّل (الكاميرا + الصوت + الترميز). features تستعملها عبر data/ فقط.
abstract class RihlaRecorder {
  /// يفتح الكاميرا الخلفية ويعيد نسيج المعاينة. يرمي [RecorderException].
  Future<CameraInfo> openCamera({RecorderQuality quality = RecorderQuality.p720});
  Future<void> closeCamera();

  /// يبدأ التسجيل (الكاميرا مفتوحة). يعيد هل الميكروفون متاح.
  Future<bool> start(RecordingConfig config);

  /// يوقف ويدمج المقاطع ويعيد الملف النهائي.
  Future<RecordingResult> stop();
  Future<void> setMuted(bool muted);

  /// إطار خريطة RGBA (D16: يُرسم يسار الفيديو). الزمن يُختم أصلياً بساعة التسجيل.
  Future<void> pushMapFrame(RgbaFrame frame);
  Future<StorageInfo> storageInfo(RecorderQuality quality);

  /// يدمج جلسات انقطعت بقتل العملية (مقاطع بلا ملف نهائي).
  Future<List<RecordingResult>> recoverPending();
  Stream<RecorderEvent> get events;
}

/// التنفيذ الحقيقي عبر القناة (أندرويد الآن؛ iOS لاحقاً بالقناة نفسها).
class MethodChannelRihlaRecorder implements RihlaRecorder {
  MethodChannelRihlaRecorder({
    MethodChannel? methods,
    EventChannel? eventChannel,
  }) : _m = methods ?? const MethodChannel('rihla_recorder'),
       _e = eventChannel ?? const EventChannel('rihla_recorder/events');

  final MethodChannel _m;
  final EventChannel _e;
  Stream<RecorderEvent>? _events;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _m.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw RecorderException(e.code, e.message);
    } on MissingPluginException {
      throw const RecorderException('unsupported_platform');
    }
  }

  @override
  Future<CameraInfo> openCamera({RecorderQuality quality = RecorderQuality.p720}) async {
    final r = await _call<Map<Object?, Object?>>('openCamera', {'quality': quality.key});
    if (r == null) throw const RecorderException('camera_unavailable');
    return CameraInfo(
      textureId: (r['textureId']! as num).toInt(),
      width: (r['width']! as num).toInt(),
      height: (r['height']! as num).toInt(),
    );
  }

  @override
  Future<void> closeCamera() => _call<void>('closeCamera');

  @override
  Future<bool> start(RecordingConfig c) async {
    final r = await _call<Map<Object?, Object?>>('start', {
      'quality': c.quality.key,
      'muted': c.muted,
      'segmentSeconds': c.segmentSeconds,
      'warnFreeBytes': c.warnFreeBytes,
      'stopFreeBytes': c.stopFreeBytes,
    });
    return r?['micAvailable'] as bool? ?? false;
  }

  @override
  Future<RecordingResult> stop() async {
    final r = await _call<Map<Object?, Object?>>('stop');
    if (r == null) throw const RecorderException('native_error', 'empty stop result');
    return RecordingResult.fromMap(r);
  }

  @override
  Future<void> setMuted(bool muted) => _call<void>('setMuted', {'muted': muted});

  @override
  Future<void> pushMapFrame(RgbaFrame f) =>
      _call<void>('pushMapFrame', {'width': f.width, 'height': f.height, 'bytes': f.rgba});

  @override
  Future<StorageInfo> storageInfo(RecorderQuality quality) async {
    final r = await _call<Map<Object?, Object?>>('storageInfo', {'quality': quality.key});
    if (r == null) throw const RecorderException('native_error', 'empty storage info');
    return StorageInfo(
      freeBytes: (r['freeBytes']! as num).toInt(),
      bytesPerSecond: (r['bytesPerSecond']! as num).toInt(),
      bytesPer10Min: (r['bytesPer10Min']! as num).toInt(),
    );
  }

  @override
  Future<List<RecordingResult>> recoverPending() async {
    final r = await _call<List<Object?>>('recoverPending');
    return [for (final m in r ?? const []) RecordingResult.fromMap(m! as Map<Object?, Object?>)];
  }

  @override
  Stream<RecorderEvent> get events => _events ??= _e
      .receiveBroadcastStream()
      .map(parseEvent)
      .where((e) => e != null)
      .cast<RecorderEvent>()
      .asBroadcastStream();

  /// يحوّل حدثاً خاماً من القناة. يعيد null لنوع مجهول (توافق مستقبلي).
  static RecorderEvent? parseEvent(Object? raw) {
    if (raw is! Map) return null;
    switch (raw['type']) {
      case 'interrupted':
        final res = raw['result'];
        if (res is! Map) return null;
        return RecordingInterrupted(
          switch (raw['reason']) {
            'background' => InterruptReason.background,
            'cameraError' => InterruptReason.cameraError,
            'writeError' => InterruptReason.writeError,
            'lowStorage' => InterruptReason.lowStorage,
            _ => InterruptReason.other,
          },
          RecordingResult.fromMap(res),
        );
      case 'storage':
        return StorageUpdate((raw['freeBytes']! as num).toInt());
      case 'lowStorageWarning':
        return LowStorageWarning((raw['freeBytes']! as num).toInt());
      case 'cameraError':
        return CameraFailed(raw['reason'] as String?);
      case 'error':
        return RecorderError(raw['reason'] as String? ?? '', raw['message'] as String?);
    }
    return null;
  }
}

/// نسخة مزيّفة للاختبار: لا كاميرا ولا ترميز، تسجّل الاستدعاءات.
class FakeRihlaRecorder implements RihlaRecorder {
  FakeRihlaRecorder({this.openFailure, this.freeBytes = 10 << 30});

  RecorderException? openFailure;
  int freeBytes;
  bool cameraOpen = false;
  bool recording = false;
  bool muted = false;
  RecorderQuality? openedQuality;
  RecordingConfig? lastConfig;
  final List<RgbaFrame> mapFrames = [];
  final _events = StreamController<RecorderEvent>.broadcast();
  int _n = 0;

  @override
  Future<CameraInfo> openCamera({RecorderQuality quality = RecorderQuality.p720}) async {
    final f = openFailure;
    if (f != null) throw f;
    cameraOpen = true;
    openedQuality = quality;
    return CameraInfo(textureId: 1, width: quality.width, height: quality.height);
  }

  @override
  Future<void> closeCamera() async => cameraOpen = false;

  @override
  Future<bool> start(RecordingConfig config) async {
    if (!cameraOpen) throw const RecorderException('camera_not_open');
    if (recording) throw const RecorderException('already_recording');
    recording = true;
    lastConfig = config;
    muted = config.muted;
    return true;
  }

  @override
  Future<RecordingResult> stop() async {
    if (!recording) throw const RecorderException('not_recording');
    recording = false;
    return RecordingResult(path: '/fake/rihla_${++_n}.mp4', duration: const Duration(seconds: 1), sizeBytes: 1000);
  }

  @override
  Future<void> setMuted(bool m) async => muted = m;

  @override
  Future<void> pushMapFrame(RgbaFrame frame) async => mapFrames.add(frame);

  @override
  Future<StorageInfo> storageInfo(RecorderQuality q) async =>
      StorageInfo(freeBytes: freeBytes, bytesPerSecond: q.bytesPerSecond, bytesPer10Min: q.bytesFor(const Duration(minutes: 10)));

  @override
  Future<List<RecordingResult>> recoverPending() async => const [];

  @override
  Stream<RecorderEvent> get events => _events.stream;

  /// يحاكي انقطاعاً أصلياً: يتوقف التسجيل ويصل الحدث بالنتيجة.
  void emitInterruption(InterruptReason reason) {
    recording = false;
    _events.add(RecordingInterrupted(reason, RecordingResult(path: '/fake/rihla_${++_n}.mp4', duration: const Duration(seconds: 5), sizeBytes: 5000)));
  }

  void emit(RecorderEvent e) => _events.add(e);
}
