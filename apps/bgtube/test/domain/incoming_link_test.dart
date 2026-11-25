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
}
