import 'package:bgtube/data/youtube_api/pacific_time.dart';
import 'package:bgtube/data/youtube_api/youtube_data_api.dart';
import 'package:bgtube/data/youtube_api/youtube_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pacificDayKey (quota resets at midnight Pacific time)', () {
    test('winter (PST, UTC-8)', () {
      expect(pacificDayKey(DateTime.utc(2026, 1, 15, 7, 59)), '2026-01-14');
      expect(pacificDayKey(DateTime.utc(2026, 1, 15, 8, 0)), '2026-01-15');
    });

    test('summer (PDT, UTC-7)', () {
      expect(pacificDayKey(DateTime.utc(2026, 7, 4, 6, 59)), '2026-07-03');
      expect(pacificDayKey(DateTime.utc(2026, 7, 4, 7, 0)), '2026-07-04');
    });

    test('DST starts on the second Sunday of March at 02:00 local (2026-03-08)', () {
      expect(pacificOffset(DateTime.utc(2026, 3, 8, 9, 59)), const Duration(hours: -8));
      expect(pacificOffset(DateTime.utc(2026, 3, 8, 10, 0)), const Duration(hours: -7));
    });

    test('DST ends on the first Sunday of November at 02:00 local (2026-11-01)', () {
      expect(pacificOffset(DateTime.utc(2026, 11, 1, 8, 59)), const Duration(hours: -7));
      expect(pacificOffset(DateTime.utc(2026, 11, 1, 9, 0)), const Duration(hours: -8));
    });

    test('year boundary and local DateTime input', () {
      expect(pacificDayKey(DateTime.utc(2027, 1, 1, 5)), '2026-12-31');
      final local = DateTime.utc(2026, 11, 26, 20).toLocal();
      expect(pacificDayKey(local), '2026-11-26');
    });
  });

  group('parsing', () {
    test('ISO 8601 durations; zero (live) is unknown', () {
      expect(parseIsoDuration('PT4M13S'), const Duration(minutes: 4, seconds: 13));
      expect(parseIsoDuration('PT1H'), const Duration(hours: 1));
      expect(parseIsoDuration('P1DT2H'), const Duration(days: 1, hours: 2));
      expect(parseIsoDuration('PT45S'), const Duration(seconds: 45));
      expect(parseIsoDuration('P0D'), isNull);
      expect(parseIsoDuration('nonsense'), isNull);
      expect(parseIsoDuration(null), isNull);
    });

    test('HTML entities in titles', () {
      expect(unescapeHtml('Tom &amp; Jerry &quot;1&quot; &#39;x&#39; &lt;b&gt; &#x41;'), 'Tom & Jerry "1" \'x\' <b> A');
      expect(unescapeHtml('&#0; &bogus;'), '&#0; &bogus;');
    });

    test('error reasons', () {
      expect(errorReasons({
        'error': {
          'errors': [
            {'reason': 'quotaExceeded'},
          ],
        },
      }), {'quotaExceeded'});
      expect(errorReasons('x'), isEmpty);
      expect(errorReasons(null), isEmpty);
    });

    test('missing fields are tolerated', () {
      expect(parseSearchItems({'items': [{}, {'id': {'kind': 'youtube#video'}}]}), isEmpty);
      expect(parsePlaylistItems({}), isEmpty);
      expect(parseDurations({'items': [{'id': 'a'}]}), isEmpty);
      expect(parseMyChannelTitle({'items': []}), isNull);
    });
  });

  test('cache keys are stable regardless of parameter order and hold no token', () {
    final a = YouTubeDataApi.cacheKey('search', {'q': 'x y', 'part': 'snippet'});
    final b = YouTubeDataApi.cacheKey('search', {'part': 'snippet', 'q': 'x y'});
    expect(a, b);
    expect(a, 'search?part=snippet&q=x+y');
  });
}
