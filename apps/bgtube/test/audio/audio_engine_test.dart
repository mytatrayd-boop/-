import 'dart:io';

import 'package:bgtube/audio/audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proxiedSource (D26)', () {
    final url = Uri.parse('https://rr1.googlevideo.com/videoplayback?itag=140&c=ANDROID');

    test('always non-null headers so just_audio routes through its local proxy', () {
      final s = proxiedSource(url, const {});
      expect(s.headers, isNotNull);
      expect(s.headers, isEmpty);
      expect(s.uri, url);
    });

    test('passes our User-Agent through unchanged', () {
      final s = proxiedSource(url, const {'User-Agent': 'UA'});
      expect(s.headers, {'User-Agent': 'UA'});
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
