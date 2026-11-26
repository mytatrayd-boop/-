import 'dart:async';
import 'dart:io';

import 'package:bgtube/audio/audio_engine.dart';
import 'package:bgtube/audio/yt_stream_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

class MockPlayer extends Mock implements AudioPlayer {}

class FakeSource extends Fake implements AudioSource {}

void main() {
  setUpAll(() => registerFallbackValue(FakeSource()));

  late MockPlayer player;
  final url = Uri.parse('https://rr1.googlevideo.com/videoplayback?itag=140&c=ANDROID');
  const ua = {'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip'};

  setUp(() {
    player = MockPlayer();
    when(() => player.setAudioSource(any(), initialPosition: any(named: 'initialPosition')))
        .thenAnswer((_) async => null);
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
  });

  AudioSource loadedSource() =>
      verify(() => player.setAudioSource(captureAny(), initialPosition: any(named: 'initialPosition')))
          .captured
          .last as AudioSource;

  group('JustAudioEngine (D26)', () {
    test('default: loads our Dart-fetching source, never a plain/proxied UriAudioSource', () async {
      final e = JustAudioEngine(player: player);
      await e.setUrl(url, initialPosition: const Duration(seconds: 7), headers: ua);
      final call = verify(() => player.setAudioSource(captureAny(), initialPosition: captureAny(named: 'initialPosition')));
      call.called(1);
      expect(call.captured[1], const Duration(seconds: 7));
      final s = call.captured[0] as AudioSource;
      expect(s, isA<YtStreamAudioSource>());
      expect(s, isNot(isA<UriAudioSource>()));
      s as YtStreamAudioSource;
      expect(s.url, url);
      expect(s.headers, ua);
    });

    test('uses the injected factory with the exact url and headers', () async {
      final made = <YtStreamAudioSource>[];
      final e = JustAudioEngine(
        player: player,
        sourceFactory: (u, h) {
          final s = YtStreamAudioSource(u, h);
          made.add(s);
          return s;
        },
      );
      await e.setUrl(url, initialPosition: Duration.zero, headers: ua);
      expect(made.single.url, url);
      expect(made.single.headers, ua);
      expect(identical(loadedSource(), made.single), isTrue);
    });

    test('switching source closes the previous one (its requests are cancelled)', () async {
      final sources = <YtStreamAudioSource>[];
      final e = JustAudioEngine(
        player: player,
        sourceFactory: (u, h) {
          final s = YtStreamAudioSource(u, h);
          sources.add(s);
          return s;
        },
      );
      await e.setUrl(url, initialPosition: Duration.zero, headers: ua);
      expect(sources.single.isClosed, isFalse);
      await e.setUrl(url.replace(path: '/b'), initialPosition: Duration.zero, headers: ua);
      expect(sources.first.isClosed, isTrue);
      expect(sources.last.isClosed, isFalse);
      await e.stop(); // stop لا يغلق (قد يُستأنف)
      expect(sources.last.isClosed, isFalse);
      await e.dispose();
      expect(sources.last.isClosed, isTrue);
    });

    test('durationStream comes from the player', () async {
      final ctl = StreamController<Duration?>.broadcast();
      when(() => player.durationStream).thenAnswer((_) => ctl.stream);
      final e = JustAudioEngine(player: player);
      final got = <Duration?>[];
      final sub = e.durationStream.listen(got.add);
      ctl.add(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
      expect(got, [const Duration(minutes: 3)]);
      await sub.cancel();
    });
  });

  group('android cleartext is limited to the local proxy', () {
    test('manifest references the network security config', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
      expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
    });

    test('config allows cleartext only for 127.0.0.1 and localhost', () {
      final xml = File('android/app/src/main/res/xml/network_security_config.xml').readAsStringSync();
      expect(xml, contains('<base-config cleartextTrafficPermitted="false"'));
      final domains = RegExp(r'<domain[^>]*>([^<]+)</domain>').allMatches(xml).map((m) => m[1]).toList();
      expect(domains, unorderedEquals(['127.0.0.1', 'localhost']));
      expect(xml, isNot(contains('includeSubdomains="true"')));
    });
  });
}
