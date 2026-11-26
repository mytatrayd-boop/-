import 'dart:io';

import 'package:bgtube/audio/playback_diagnostics.dart';
import 'package:bgtube/audio/range_fetcher.dart';
import 'package:bgtube/audio/local_stream_proxy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  group('sanitizeDetail', () {
    test('removes urls and signed googlevideo hosts', () {
      final s = sanitizeDetail('Response code: 403 https://rr1.googlevideo.com/videoplayback?sig=ABC&ip=1.2.3.4 x');
      expect(s, 'Response code: 403 <url> x');
      expect(sanitizeDetail('host rr1---sn.googlevideo.com/v?sig=Z'), 'host <url>');
    });
    test('removes urls that are not googlevideo', () {
      expect(sanitizeDetail('failed http://example.org/a?b=c and ftp://h/x'), 'failed <url> and <url>');
    });
    test('redacts signed values even without a host', () {
      final s = sanitizeDetail('bad params ip=2001:db8::1&sig=AbC123 signature=XYZ lsig=Q done');
      expect(s, 'bad params ip=<redacted>&sig=<redacted> signature=<redacted> lsig=<redacted> done');
      expect(s, isNot(contains('2001')));
      expect(s, isNot(contains('AbC123')));
      expect(s, isNot(contains('XYZ')));
    });
    test('collapses whitespace and caps the length', () {
      expect(sanitizeDetail('a \n  b'), 'a b');
      final long = sanitizeDetail('x' * 500);
      expect(long.length, maxDetailLength);
      expect(long.endsWith('…'), isTrue);
    });
  });

  group('playerErrorDetail', () {
    test('PlayerException keeps code and short message', () {
      expect(playerErrorDetail(PlayerException(0, 'Source error', null)), 'PlayerException(0) Source error');
      expect(playerErrorDetail(PlayerException(1, null, null)), 'PlayerException(1)');
    });
    test('other errors give only the type', () {
      expect(playerErrorDetail(PlayerInterruptedException('x')), 'PlayerInterrupted');
      expect(playerErrorDetail(const SocketException('secret host')), 'SocketException');
    });
  });

  group('httpStreamProbe', () {
    test('uses the player fetch with the same headers and the first real chunk (same Range as the proxy)', () async {
      final seen = <(Uri, Map<String, String>, int?, int?)>[];
      var cancelled = false;
      Future<RangeFetchResult> fetch(Uri u, Map<String, String> h, {int? start, int? end}) async {
        seen.add((u, h, start, end));
        return RangeFetchResult(
          statusCode: 403,
          offset: 0,
          contentLength: null,
          sourceLength: null,
          contentType: 'text/plain',
          body: const Stream.empty(),
          cancel: () => cancelled = true,
        );
      }

      final url = Uri.parse('https://x.googlevideo.com/v?c=ANDROID');
      final r = await httpStreamProbe(url, {'User-Agent': 'UA'}, fetch: fetch);
      expect(r, 'probe HTTP 403 bytes=0-8388607');
      final (u, h, start, end) = seen.single;
      expect(u, url);
      expect(h, {'User-Agent': 'UA'});
      expect((start, end), (0, originChunkBytes));
      expect(cancelled, isTrue);
    });

    test('player source and probe share the same fetch function by default', () {
      expect(identical(LocalStreamProxy().fetcher, defaultRangeFetch), isTrue);
      expect(identical(defaultRangeFetch, fetchRange), isTrue);
    });

    test('network error becomes a short type, never throws', () async {
      Future<RangeFetchResult> fetch(Uri u, Map<String, String> h, {int? start, int? end}) async =>
          throw const SocketException('down');
      expect(await httpStreamProbe(Uri.parse('https://x/v'), const {}, fetch: fetch), 'probe SocketException');
    });

    test('wrapped network error reports its cause type only', () async {
      Future<RangeFetchResult> fetch(Uri u, Map<String, String> h, {int? start, int? end}) async =>
          throw const RangeFetchNetworkException('HandshakeException');
      expect(await httpStreamProbe(Uri.parse('https://x/v'), const {}, fetch: fetch), 'probe HandshakeException');
    });
  });
}
