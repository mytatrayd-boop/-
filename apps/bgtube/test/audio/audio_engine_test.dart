import 'dart:async';
import 'dart:io';

import 'package:bgtube/audio/audio_engine.dart';
import 'package:bgtube/audio/local_stream_proxy.dart';
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

  group('JustAudioEngine (D26, own local proxy)', () {
    late LocalStreamProxy proxy;
    setUp(() => proxy = LocalStreamProxy());
    tearDown(() => proxy.close());

    test('loads a plain UriAudioSource on our 127.0.0.1 proxy: no headers, no signed url', () async {
      final e = JustAudioEngine(player: player, proxy: proxy);
      await e.setUrl(url, initialPosition: const Duration(seconds: 7), headers: ua);
      final call = verify(() => player.setAudioSource(captureAny(), initialPosition: captureAny(named: 'initialPosition')));
      call.called(1);
      expect(call.captured[1], const Duration(seconds: 7));
      final s = call.captured[0] as UriAudioSource;
      expect(s.uri.scheme, 'http');
      expect(s.uri.host, '127.0.0.1');
      expect(s.uri.port, proxy.port);
      expect(s.uri.hasQuery, isFalse);
      expect(s.uri.toString(), isNot(contains('googlevideo')));
      // بلا ترويسات: لا يُفعَّل وكيل just_audio. UA يُرسل من وكيلنا إلى الأصل.
      expect(s.headers, isNull);
      expect(e.currentStream!.localUri, s.uri);
      expect(e.currentStream!.url, url);
      expect(e.currentStream!.headers, ua);
    });

    test('switching source closes the previous one; stop keeps it; dispose closes it and the proxy', () async {
      final e = JustAudioEngine(player: player, proxy: proxy);
      await e.setUrl(url, initialPosition: Duration.zero, headers: ua);
      final first = e.currentStream!;
      await e.setUrl(url.replace(path: '/b'), initialPosition: Duration.zero, headers: ua);
      final second = e.currentStream!;
      expect(first.isClosed, isTrue);
      expect(second.isClosed, isFalse);
      expect(proxy.registeredCount, 1);
      expect((loadedSource() as UriAudioSource).uri, second.localUri);
      expect(second.localUri, isNot(first.localUri));
      await e.stop(); // stop لا يغلق (قد يُستأنف)
      expect(second.isClosed, isFalse);
      await e.dispose();
      expect(second.isClosed, isTrue);
      expect(proxy.registeredCount, 0);
    });

    test('concurrent setUrl calls leave exactly one registered source', () async {
      final e = JustAudioEngine(player: player, proxy: proxy);
      await Future.wait([
        e.setUrl(url, initialPosition: Duration.zero, headers: ua),
        e.setUrl(url.replace(path: '/b'), initialPosition: Duration.zero, headers: ua),
      ]);
      expect(proxy.registeredCount, 1);
      expect(e.currentStream!.url.path, '/b');
    });

    test('end to end with a real origin: bytes via the local uri; switching cuts the old request', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seenUa = <String?>[];
      var open = 0;
      server.listen((req) async {
        seenUa.add(req.headers.value(HttpHeaders.userAgentHeader));
        final res = req.response
          ..bufferOutput = false
          ..statusCode = 206
          ..contentLength = 100000000;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-99999999/100000000');
        open++;
        var gone = false;
        unawaited(res.done.then((_) {}, onError: (Object _) {}).whenComplete(() {
          gone = true;
          open--;
        }));
        while (!gone) {
          res.add(List<int>.filled(100, 1));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      addTearDown(() => server.close(force: true));
      final e = JustAudioEngine(player: player, proxy: proxy);
      final origin = Uri.parse('http://127.0.0.1:${server.port}/a?sig=X');
      await e.setUrl(origin, initialPosition: Duration.zero, headers: ua);
      final local = (loadedSource() as UriAudioSource).uri;
      final c = HttpClient();
      addTearDown(() => c.close(force: true));
      final req = await c.getUrl(local);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final res = await req.close();
      expect(res.statusCode, 206);
      final ended = res.drain<void>().catchError((Object _) {});
      expect(seenUa.single, ua['User-Agent']);
      expect(open, 1);
      await e.setUrl(origin.replace(path: '/b'), initialPosition: Duration.zero, headers: ua);
      await ended.timeout(const Duration(seconds: 5));
      final sw = Stopwatch()..start();
      while (open != 0 && sw.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(open, 0);
      final again = await (await c.getUrl(local)).close();
      expect(again.statusCode, 404);
      await again.drain<void>();
      await e.dispose();
    });

    test('durationStream comes from the player', () async {
      final ctl = StreamController<Duration?>.broadcast();
      when(() => player.durationStream).thenAnswer((_) => ctl.stream);
      final e = JustAudioEngine(player: player, proxy: proxy);
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
