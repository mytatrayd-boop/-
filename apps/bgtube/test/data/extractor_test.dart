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

    test('only data/settings imports shared_preferences (main.dart may)', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/settings') ||
            f.path.endsWith('lib/main.dart')) {
          continue;
        }
        expect(
          f.readAsStringSync(),
          isNot(contains('package:shared_preferences')),
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

    test('only main.dart (and the API layer) imports data/auth', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/auth') ||
            f.path.contains('data/youtube_api') ||
            f.path.endsWith('lib/main.dart')) {
          continue;
        }
        expect(f.readAsStringSync(), isNot(contains('data/auth')), reason: f.path);
      }
    });

    test('only main.dart imports data/youtube_api (D29)', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/youtube_api') || f.path.endsWith('lib/main.dart')) continue;
        expect(f.readAsStringSync(), isNot(contains('youtube_api/')), reason: f.path);
      }
    });

    test('the API layer uses the AuthService port, not the auth implementation, and logs no token', () {
      for (final f in dartFiles('lib/data/youtube_api')) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('data/auth')), reason: f.path);
        expect(src, isNot(contains('/auth/')), reason: f.path);
        expect(src, isNot(contains('package:google_sign_in')), reason: f.path);
        expect(src, isNot(contains('data/extractor')), reason: f.path);
        for (final line in src.split('\n')) {
          if (line.contains('debugPrint') || line.contains('print(') || line.contains('AppFailure(')) {
            expect(line.toLowerCase(), isNot(contains('token')), reason: '${f.path}: $line');
          }
        }
        // لا مفتاح API ولا طلبات خارج googleapis.com.
        expect(src, isNot(contains("'key'")), reason: f.path);
        expect(RegExp(r'https?://(?!www\.googleapis\.com)').hasMatch(src), isFalse, reason: f.path);
      }
    });

    test('extractor and audio know nothing about the Data API', () {
      for (final f in [...dartFiles('lib/data/extractor'), ...dartFiles('lib/audio')]) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('youtube_api')), reason: f.path);
        expect(src, isNot(contains('YouTubeApi')), reason: f.path);
      }
    });

    test('only data/auth imports google_sign_in and flutter_secure_storage', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('data/auth')) continue;
        final src = f.readAsStringSync();
        expect(src, isNot(contains('package:google_sign_in')), reason: f.path);
        expect(src, isNot(contains('package:flutter_secure_storage')), reason: f.path);
      }
    });

    test('audio playback layer does not know the account', () {
      for (final f in [
        ...dartFiles('lib/audio'),
        File('lib/domain/ports/audio_source_resolver.dart'),
        File('lib/domain/ports/playback_controller.dart'),
        File('lib/domain/ports/playback_queue.dart'),
        File('lib/domain/ports/queue_repository.dart'),
        File('lib/domain/playback_queue_model.dart'),
      ]) {
        final src = f.readAsStringSync();
        expect(src, isNot(matches(RegExp(r"import\s+'[^']*auth"))), reason: f.path);
        expect(src, isNot(contains('AuthService')), reason: f.path);
        expect(src, isNot(contains('accessToken')), reason: f.path);
      }
    });

    test('extractor does not depend on auth or account code', () {
      for (final f in dartFiles('lib/data/extractor')) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('/auth/')), reason: f.path);
        expect(src, isNot(contains('auth_service')), reason: f.path);
        expect(src, isNot(contains('AuthService')), reason: f.path);
        expect(src, isNot(contains('accessToken')), reason: f.path);
        expect(src, isNot(contains('google_sign_in')), reason: f.path);
        expect(src, isNot(contains('flutter_secure_storage')), reason: f.path);
      }
    });

    test('extractor and audio do not use riverpod or core/providers.dart', () {
      for (final f in [
        ...dartFiles('lib/data/extractor'),
        ...dartFiles('lib/audio'),
      ]) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('flutter_riverpod')), reason: f.path);
        expect(src, isNot(contains('package:riverpod')), reason: f.path);
        expect(src, isNot(contains('core/providers.dart')), reason: f.path);
      }
    });

    test('extractor and audio never mention the auth service (any case)', () {
      for (final f in [
        ...dartFiles('lib/data/extractor'),
        ...dartFiles('lib/audio'),
      ]) {
        expect(
          f.readAsStringSync().toLowerCase(),
          isNot(contains('authservice')),
          reason: f.path,
        );
      }
    });

    test('playback ports carry no token, bearer or Authorization', () {
      for (final path in [
        'lib/domain/ports/audio_source_resolver.dart',
        'lib/domain/ports/playback_controller.dart',
        'lib/domain/ports/playback_queue.dart',
        'lib/domain/ports/queue_repository.dart',
        'lib/domain/ports/local_playlist_repository.dart',
      ]) {
        final src = File(path).readAsStringSync().toLowerCase();
        for (final word in ['token', 'bearer', 'authorization']) {
          expect(src, isNot(contains(word)), reason: '$path: $word');
        }
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

    test('audio_service is used inside lib/audio only (D27)', () {
      for (final f in dartFiles('lib')) {
        if (f.path.contains('lib/audio/')) continue;
        expect(f.readAsStringSync(), isNot(contains('package:audio_service')), reason: f.path);
      }
    });

    test('the queue model and ports in domain are pure (no flutter widgets, packages or data layer)', () {
      for (final path in [
        'lib/domain/playback_queue_model.dart',
        'lib/domain/models/video_ref.dart',
        'lib/domain/models/local_playlist.dart',
        'lib/domain/ports/queue_repository.dart',
        'lib/domain/ports/local_playlist_repository.dart',
        'lib/domain/models/youtube_content.dart',
        'lib/domain/ports/youtube_api.dart',
        'lib/domain/ports/api_cache_store.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('package:')), reason: path);
        expect(src, isNot(contains('/data/')), reason: path);
      }
    });
  });
}
