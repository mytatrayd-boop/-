import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/incoming_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain youtu.be link', () {
    expect(parseSharedText('https://youtu.be/dQw4w9WgXcQ?si=abc').videoId, 'dQw4w9WgXcQ');
  });

  test('title text before the link (YouTube share format)', () {
    final p = parseSharedText('شاهد هذا الفيديو\nhttps://youtu.be/dQw4w9WgXcQ?si=x');
    expect(p.videoId, 'dQw4w9WgXcQ');
  });

  test('skips non-youtube urls and takes the first youtube one', () {
    final p = parseSharedText('see https://example.com/a and https://m.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(p.videoId, 'dQw4w9WgXcQ');
  });

  test('music.youtube.com watch link', () {
    expect(parseSharedText('https://music.youtube.com/watch?v=dQw4w9WgXcQ').videoId, 'dQw4w9WgXcQ');
  });

  test('playlist link has no videoId', () {
    final p = parseSharedText('https://www.youtube.com/playlist?list=PL123');
    expect(p.videoId, isNull);
    expect(p.playlistId, 'PL123');
  });

  test('no link throws invalidLink', () {
    expect(
      () => parseSharedText('hello world'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.invalidLink)),
    );
    expect(() => parseSharedText('https://example.com/x'), throwsA(isA<AppFailure>()));
    expect(() => parseSharedText(''), throwsA(isA<AppFailure>()));
  });

  group('trailing punctuation', () {
    const id = 'dQw4w9WgXcQ';
    for (final t in [
      'شاهد https://youtu.be/$id.',
      'https://youtu.be/$id!',
      '(https://www.youtube.com/watch?v=$id)',
      'https://www.youtube.com/watch?v=$id، رائع',
      'https://www.youtube.com/watch?v=$id؟',
      '"https://youtu.be/$id".',
      'https://youtu.be/$id?si=abc,',
    ]) {
      test(t, () => expect(parseSharedText(t).videoId, id));
    }

    test('playlist id is not damaged by trailing dot', () {
      expect(parseSharedText('https://www.youtube.com/playlist?list=PL123.').playlistId, 'PL123');
    });
  });
}
