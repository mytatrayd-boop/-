import 'package:bgtube/core/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgtube/domain/youtube_link_parser.dart';

void main() {
  const id = 'dQw4w9WgXcQ';

  group('valid links', () {
    final cases = {
      'watch': 'https://www.youtube.com/watch?v=$id',
      'watch with extras': 'https://www.youtube.com/watch?feature=share&v=$id&t=42',
      'mobile': 'https://m.youtube.com/watch?v=$id',
      'music': 'https://music.youtube.com/watch?v=$id',
      'no scheme': 'youtube.com/watch?v=$id',
      'youtu.be': 'https://youtu.be/$id',
      'youtu.be with query': 'https://youtu.be/$id?si=abc',
      'shorts': 'https://www.youtube.com/shorts/$id',
      'embed': 'https://www.youtube.com/embed/$id',
      'live': 'https://www.youtube.com/live/$id',
      'surrounding spaces': '  https://youtu.be/$id \n',
    };
    cases.forEach((name, url) {
      test(name, () => expect(parseYoutubeLink(url).videoId, id));
    });
  });

  test('watch with list gives both ids', () {
    final p = parseYoutubeLink('https://www.youtube.com/watch?v=$id&list=PL123');
    expect(p.videoId, id);
    expect(p.playlistId, 'PL123');
  });

  test('playlist-only link has no videoId', () {
    final p = parseYoutubeLink('https://www.youtube.com/playlist?list=PL123');
    expect(p.videoId, isNull);
    expect(p.playlistId, 'PL123');
  });

  group('invalid links', () {
    final bad = [
      '',
      '   ',
      'hello',
      'https://example.com/watch?v=$id',
      'https://evilyoutube.com/watch?v=$id',
      'https://www.youtube.com/watch?v=short',
      'https://www.youtube.com/watch',
      'https://www.youtube.com/',
      'https://youtu.be/',
      'ftp://youtube.com/watch?v=$id',
      'https://www.youtube.com/playlist',
    ];
    for (final url in bad) {
      test('"$url"', () {
        expect(
          () => parseYoutubeLink(url),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.invalidLink)),
        );
      });
    }
  });
}
