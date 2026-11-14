import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/core/config/env.dart';
import 'package:rihla/data/map/fake_map_frame_source.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

const camCode = FrameCounterCode();
const mapCode = FakeMapFrameSource.code;

void main() {
  group('FakeMapFrameSource', () {
    test('works without key or network, deterministic', () async {
      expect(Env.hasMapsKey, isFalse);
      final a = await FakeMapFrameSource(count: 4).frames().toList();
      final b = await FakeMapFrameSource(count: 4).frames().toList();
      expect(a.length, 4);
      for (var i = 0; i < 4; i++) {
        expect(a[i].rgba, b[i].rgba);
        expect(a[i].timestamp, Duration(milliseconds: 500 * i));
        expect(a[i].width, 640);
        expect(a[i].height, 720);
      }
      expect(a[0].rgba, isNot(a[3].rgba));
    });

    test('counter code decodes to frame index', () {
      final f = FakeMapFrameSource().frame(5);
      final v = mapCode.decode((b) => f.pixel(b * 40 + 20, 24).$1);
      expect(v, 5);
    });
  });

  group('DualCompositor', () {
    final cam = const SyntheticCameraSource();
    final src = FakeMapFrameSource();

    test('output is 16:9 with camera left and map right', () {
      final c = DualCompositor();
      final out = c.compose(cam.frame(7), map: src.frame(3));
      expect(out.width * 9, out.height * 16);
      final camV = camCode.decode((b) => out.pixel(b * 40 + 20, 24).$1);
      final mapV = mapCode.decode((b) => out.pixel(640 + b * 40 + 20, 24).$1);
      expect(camV, 7);
      expect(mapV, 3);
    });

    test('repeats last map frame until a new one arrives', () {
      final c = DualCompositor();
      c.compose(cam.frame(0), map: src.frame(1));
      final out = c.compose(cam.frame(1));
      expect(c.mapRepeats, 1);
      expect(mapCode.decode((b) => out.pixel(640 + b * 40 + 20, 24).$1), 1);
    });

    test('attribution marker stays visible (not cropped or covered)', () {
      final c = DualCompositor();
      final out = c.compose(cam.frame(0), map: src.frame(0));
      final y = src.attributionY + FakeMapFrameSource.attributionH ~/ 2;
      for (final dx in [0, FakeMapFrameSource.attributionW - 1]) {
        expect(out.pixel(640 + FakeMapFrameSource.attributionX + dx, y),
            FakeMapFrameSource.attributionColor);
      }
    });

    test('map of different size is letterboxed, never cropped', () {
      final c = DualCompositor();
      final wide = RgbaFrame.filled(1000, 500, 255, 0, 255);
      final out = c.compose(cam.frame(0), map: wide);
      // يمسّ الحافتين الأفقيتين للنصف الأيمن، ومحاط بخلفية في الأعلى والأسفل.
      expect(out.pixel(640, 360), (255, 0, 255));
      expect(out.pixel(1279, 360), (255, 0, 255));
      expect(out.pixel(900, 5), isNot((255, 0, 255)));
    });
  });

  test('synthetic audio: click each second, muted gives same-length silence', () {
    const a = SyntheticAudioSource();
    final s = a.samples(const Duration(seconds: 3));
    expect(s.length, 144000);
    expect(s[48000].abs(), greaterThan(20000));
    expect(s[24000], 0);
    final m = const SyntheticAudioSource(muted: true).samples(const Duration(seconds: 3));
    expect(m.length, s.length);
    expect(m.every((e) => e == 0), isTrue);
  });

  final hasTools = HostFfmpegEncoder.isAvailable();
  test('encoded file: 16:9, duration, 30fps, audio track, A/V + map sync',
      () async {
    const fps = 30;
    const dur = Duration(seconds: 3);
    final cam = const SyntheticCameraSource();
    final map = FakeMapFrameSource(count: 6); // 2 fps
    final pipe = DualPipeline(camera: cam, compositor: DualCompositor());
    final audioSrc = pipe.audio;
    final dir = await Directory.systemTemp.createTemp('rihla_f0a_');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/out.mp4';

    await const HostFfmpegEncoder().encode(
      outPath: out,
      frames: pipe.run(dur, map.generate().toList()),
      width: 1280,
      height: 720,
      fps: fps,
      wavAudio: audioSrc.toWav(pipe.audioFor(dur)),
    );

    final probe = jsonDecode(Process.runSync('ffprobe', [
      '-v', 'error', '-count_frames', '-show_streams', '-show_format',
      '-of', 'json', out,
    ]).stdout as String) as Map<String, dynamic>;
    final streams = (probe['streams'] as List).cast<Map<String, dynamic>>();
    final v = streams.firstWhere((s) => s['codec_type'] == 'video');
    final a = streams.firstWhere((s) => s['codec_type'] == 'audio');
    expect(v['codec_name'], 'h264');
    expect(v['width'], 1280);
    expect(v['height'], 720);
    expect(v['r_frame_rate'], '30/1');
    expect(v['nb_read_frames'], '90');
    expect(a['codec_name'], 'aac');
    final duration = double.parse(probe['format']['duration'] as String);
    expect(duration, closeTo(3.0, 0.1));
    expect(double.parse(a['duration'] as String), closeTo(3.0, 0.1));

    // عدّاد الكاميرا (يسار) وعدّاد الخريطة (يمين) من الصورة المفكوكة.
    Uint8List rows(int x) => Uint8List.fromList(Process.runSync(
          'ffmpeg',
          ['-v', 'error', '-i', out, '-vf', 'format=gray,crop=640:1:$x:24',
           '-f', 'rawvideo', '-'],
          stdoutEncoding: null,
        ).stdout as List<int>);
    final camRows = rows(0), mapRows = rows(640);
    expect(camRows.length, 640 * 90);
    final camIdx = [
      for (var f = 0; f < 90; f++)
        camCode.decode((b) => camRows[f * 640 + b * 40 + 20])
    ];
    final mapIdx = [
      for (var f = 0; f < 90; f++)
        mapCode.decode((b) => mapRows[f * 640 + 640 * 0 + b * 40 + 20])
    ];
    expect(camIdx, List.generate(90, (i) => i));
    // الخريطة: الإطار k يظهر عند k*0.5ث؛ يُكرَّر حتى يصل الجديد.
    expect(mapIdx, List.generate(90, (i) => i ~/ 15));

    // الصوت: أول عينة قوية في كل ثانية تقابل إطار الكاميرا ذي الرقم نفسه (±3 إطارات = 100ms).
    final pcm = Process.runSync('ffmpeg', [
      '-v', 'error', '-i', out, '-vn', '-f', 's16le', '-ac', '1', '-ar', '48000', '-',
    ], stdoutEncoding: null).stdout as List<int>;
    final s = Int16List.view(Uint8List.fromList(pcm).buffer);
    for (final sec in [1, 2]) {
      var idx = -1;
      for (var i = (sec - 0.2) * 48000 ~/ 1; i < s.length; i++) {
        if (s[i].abs() > 8000) {
          idx = i;
          break;
        }
      }
      expect(idx, greaterThan(0), reason: 'click at $sec s not found');
      final t = idx / 48000;
      final frameAtClick = camIdx[(t * fps).floor()];
      expect((frameAtClick - sec * fps).abs(), lessThanOrEqualTo(3),
          reason: 'click at ${t}s sees frame $frameAtClick');
    }
  }, skip: hasTools ? false : 'ffmpeg/ffprobe not available');
}
