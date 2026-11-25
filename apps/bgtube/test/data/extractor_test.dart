import 'dart:io';

import 'package:bgtube/data/extractor/youtube_explode_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expiryFromUrl', () {
    test('reads expire seconds', () {
      final d = expiryFromUrl(
        Uri.parse(
          'https://x.googlevideo.com/videoplayback?expire=1700000000&a=b',
        ),
      );
      expect(
        d,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });
    test('null when missing or malformed', () {
      expect(expiryFromUrl(Uri.parse('https://x/y')), isNull);
      expect(expiryFromUrl(Uri.parse('https://x/y?expire=abc')), isNull);
    });
  });

  group('architecture rules', () {
    List<File> dartFiles(String dir) =>
        Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

    test('only main.dart imports data/extractor', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/extractor') ||
            f.path.endsWith('lib/main.dart')) {
          continue;
        }
        expect(
          f.readAsStringSync(),
          isNot(contains('data/extractor')),
          reason: f.path,
        );
      }
    });

    test('only data/extractor imports youtube_explode_dart', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/extractor')) continue;
        expect(
          f.readAsStringSync(),
          isNot(contains('youtube_explode_dart')),
          reason: f.path,
        );
      }
    });

    test('only data/local imports drift (main.dart may use drift_flutter)', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/local') || f.path.endsWith('lib/main.dart')) {
          continue;
        }
        expect(
          f.readAsStringSync(),
          isNot(contains('package:drift')),
          reason: f.path,
        );
      }
    });

    test('only data/incoming imports receive_sharing_intent', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/incoming')) continue;
        expect(
          f.readAsStringSync(),
          isNot(contains('receive_sharing_intent')),
          reason: f.path,
        );
      }
    });

    test('only main.dart imports data/incoming', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/incoming') ||
            f.path.endsWith('lib/main.dart')) {
          continue;
        }
        expect(
          f.readAsStringSync(),
          isNot(contains('data/incoming')),
          reason: f.path,
        );
      }
    });

    test('extractor does not depend on auth or account code', () {
      for (final f in dartFiles('lib/data/extractor')) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('/auth/')), reason: f.path);
        expect(src, isNot(contains('google_sign_in')), reason: f.path);
        expect(src, isNot(contains('flutter_secure_storage')), reason: f.path);
      }
    });

    test('features and audio do not import data layer', () {
      for (final f in [
        ...dartFiles('lib/features'),
        ...dartFiles('lib/audio'),
      ]) {
        expect(f.readAsStringSync(), isNot(contains('/data/')), reason: f.path);
      }
    });
  });
}
