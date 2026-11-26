import 'dart:io';

import 'package:bgtube/audio/playback_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    test('sends the player headers and a tiny range, reports the status', () async {
      late http.BaseRequest seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response('', 403);
      });
      final r = await httpStreamProbe(
        Uri.parse('https://x.googlevideo.com/v?c=ANDROID'),
        {'User-Agent': 'UA'},
        client: client,
      );
      expect(r, 'probe HTTP 403');
      expect(seen.headers['User-Agent'], 'UA');
      expect(seen.headers['Range'], 'bytes=0-1');
    });
    test('network error becomes a short type, never throws', () async {
      final client = MockClient((_) async => throw const SocketException('down'));
      expect(await httpStreamProbe(Uri.parse('https://x/v'), const {}, client: client), 'probe SocketException');
    });
  });
}
