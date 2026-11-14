import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('rihla_recorder');
  final calls = <MethodCall>[];
  late MethodChannelRihlaRecorder rec;

  void mock(Future<Object?> Function(MethodCall) h) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) {
      calls.add(c);
      return h(c);
    });
  }

  setUp(() {
    calls.clear();
    rec = MethodChannelRihlaRecorder();
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null));

  test('openCamera يمرّر الجودة ويحلّل الرد', () async {
    mock((_) async => {'textureId': 7, 'width': 1920, 'height': 1080});
    final i = await rec.openCamera(quality: RecorderQuality.p1080);
    expect(calls.single.method, 'openCamera');
    expect(calls.single.arguments, {'quality': 'p1080'});
    expect((i.textureId, i.width, i.height), (7, 1920, 1080));
  });

  test('PlatformException يتحول إلى RecorderException بالرمز', () async {
    mock((_) async => throw PlatformException(code: 'permission_denied', message: 'camera'));
    await expectLater(
      rec.openCamera(),
      throwsA(isA<RecorderException>().having((e) => e.code, 'code', 'permission_denied')),
    );
  });

  test('MissingPlugin => unsupported_platform', () async {
    await expectLater(
      rec.start(const RecordingConfig()),
      throwsA(isA<RecorderException>().having((e) => e.code, 'code', 'unsupported_platform')),
    );
  });

  test('start يرسل الإعدادات كاملة', () async {
    mock((_) async => {'micAvailable': false});
    final mic = await rec.start(const RecordingConfig(quality: RecorderQuality.p1080, muted: true, segmentSeconds: 30));
    expect(mic, isFalse);
    expect(calls.single.arguments, {
      'quality': 'p1080',
      'muted': true,
      'segmentSeconds': 30,
      'warnFreeBytes': 1 << 30,
      'stopFreeBytes': 300 << 20,
    });
  });

  test('stop يحلّل النتيجة', () async {
    mock((_) async => {'path': '/a.mp4', 'durationMs': 12345, 'sizeBytes': 99, 'segments': 3, 'skippedSegments': 1, 'hasMic': false});
    final r = await rec.stop();
    expect(r.path, '/a.mp4');
    expect(r.duration, const Duration(milliseconds: 12345));
    expect((r.segments, r.skippedSegments, r.hasMic), (3, 1, false));
  });

  test('pushMapFrame يرسل RGBA بأبعاده', () async {
    mock((_) async => null);
    final f = RgbaFrame.filled(4, 2, 1, 2, 3);
    await rec.pushMapFrame(f);
    final a = calls.single.arguments as Map;
    expect(a['width'], 4);
    expect(a['height'], 2);
    expect((a['bytes'] as Uint8List).length, 32);
  });

  test('setMuted وstorageInfo وrecoverPending', () async {
    mock((c) async => switch (c.method) {
      'storageInfo' => {'freeBytes': 6000000, 'bytesPerSecond': 512000, 'bytesPer10Min': 307200000},
      'recoverPending' => [
        {'path': '/r.mp4', 'durationMs': 1000, 'sizeBytes': 5},
      ],
      _ => null,
    });
    await rec.setMuted(true);
    expect(calls.last.arguments, {'muted': true});
    final s = await rec.storageInfo(RecorderQuality.p720);
    expect(s.remaining, const Duration(seconds: 11));
    expect((await rec.recoverPending()).single.path, '/r.mp4');
  });

  test('تقدير الحجم يطابق ARCHITECTURE (~300MB/10د لـ720p، ~600MB لـ1080p)', () {
    expect(RecorderQuality.p720.bytesFor(const Duration(minutes: 10)), 307200000);
    expect(RecorderQuality.p1080.bytesFor(const Duration(minutes: 10)), 607200000);
    expect(RecorderQuality.p1080.mapWidth, 960);
  });

  group('parseEvent', () {
    test('interrupted بالنتيجة والسبب', () {
      final e = MethodChannelRihlaRecorder.parseEvent({
        'type': 'interrupted',
        'reason': 'background',
        'result': {'path': '/x.mp4', 'durationMs': 5, 'sizeBytes': 1},
      });
      expect(e, isA<RecordingInterrupted>());
      expect((e! as RecordingInterrupted).reason, InterruptReason.background);
      expect((e as RecordingInterrupted).result.path, '/x.mp4');
    });
    test('storage/تحذير/خطأ/مجهول', () {
      expect(MethodChannelRihlaRecorder.parseEvent({'type': 'storage', 'freeBytes': 5}), isA<StorageUpdate>());
      expect(MethodChannelRihlaRecorder.parseEvent({'type': 'lowStorageWarning', 'freeBytes': 5}), isA<LowStorageWarning>());
      expect(MethodChannelRihlaRecorder.parseEvent({'type': 'cameraError', 'reason': 'x'}), isA<CameraFailed>());
      expect(MethodChannelRihlaRecorder.parseEvent({'type': 'error', 'reason': 'writeError'}), isA<RecorderError>());
      expect(MethodChannelRihlaRecorder.parseEvent({'type': 'future'}), isNull);
      expect(MethodChannelRihlaRecorder.parseEvent('junk'), isNull);
      expect(MethodChannelRihlaRecorder.parseEvent({'type': 'interrupted', 'reason': 'x'}), isNull);
    });
  });

  group('FakeRihlaRecorder', () {
    test('دورة بدء/إيقاف/انقطاع', () async {
      final f = FakeRihlaRecorder();
      await expectLater(f.start(const RecordingConfig()), throwsA(isA<RecorderException>()));
      await f.openCamera();
      await f.start(const RecordingConfig(muted: true));
      expect(f.muted, isTrue);
      final evt = f.events.first;
      f.emitInterruption(InterruptReason.lowStorage);
      expect(f.recording, isFalse);
      expect(await evt, isA<RecordingInterrupted>());
      await expectLater(f.stop(), throwsA(isA<RecorderException>()));
    });
  });
}
