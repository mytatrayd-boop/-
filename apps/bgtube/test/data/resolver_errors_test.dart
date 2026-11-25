import 'dart:async';
import 'dart:io';

import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/data/extractor/youtube_explode_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MockYt extends Mock implements YoutubeExplode {}

class MockVideos extends Mock implements VideoClient {}

class MockStreams extends Mock implements StreamClient {}

void main() {
  late MockYt yt;
  late MockVideos videos;
  late MockStreams streams;

  setUp(() {
    yt = MockYt();
    videos = MockVideos();
    streams = MockStreams();
    when(() => yt.videos).thenReturn(videos);
    when(() => videos.streamsClient).thenReturn(streams);
    when(() => yt.close()).thenReturn(null);
  });

  Future<void> expectKind(Object error, FailureKind kind) async {
    when(() => videos.get(any())).thenAnswer((_) async => throw error);
    final r = YoutubeExplodeResolver(client: yt);
    await expectLater(
      r.resolve('dQw4w9WgXcQ'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', kind)),
    );
  }

  test('RequestLimitExceeded -> rateLimited (own message)', () {
    return expectKind(
      RequestLimitExceededException('429'),
      FailureKind.rateLimited,
    );
  });
  test(
    'SocketException -> network',
    () => expectKind(const SocketException('x'), FailureKind.network),
  );
  test(
    'http ClientException -> network',
    () => expectKind(ClientException('x'), FailureKind.network),
  );
  test(
    'TimeoutException -> network',
    () => expectKind(TimeoutException('x'), FailureKind.network),
  );
  test('VideoUnavailable -> extractionFailed', () {
    return expectKind(
      VideoUnavailableException('gone'),
      FailureKind.extractionFailed,
    );
  });
  test(
    'unknown error -> extractionFailed',
    () => expectKind(StateError('x'), FailureKind.extractionFailed),
  );

  test('slow extractor times out as network failure', () async {
    when(() => videos.get(any())).thenAnswer((_) => Completer<Video>().future);
    final r = YoutubeExplodeResolver(
      client: yt,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      r.resolve('dQw4w9WgXcQ'),
      throwsA(
        isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.network),
      ),
    );
  });
}
