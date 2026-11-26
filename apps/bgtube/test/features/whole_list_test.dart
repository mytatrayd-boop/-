import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/models/youtube_content.dart';
import 'package:bgtube/domain/playback_queue_model.dart';
import 'package:bgtube/features/library/whole_list.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRef v(int i) => VideoRef(videoId: 'V${i.toString().padLeft(10, '0')}');

/// قائمة من [n] مقطعاً بصفحات من [per]، وفشل اختياري عند صفحة.
ListPageFetcher pages(int n, {int per = 50, int? failAt, List<String?>? log}) => (token) async {
      log?.add(token);
      final page = token == null ? 0 : int.parse(token);
      if (failAt == page) throw const AppFailure(FailureKind.network);
      final start = page * per;
      final end = (start + per).clamp(0, n);
      return ApiPage([for (var i = start; i < end; i++) v(i)],
          nextPageToken: end < n ? '${page + 1}' : null, total: n);
    };

void main() {
  test('fetches every page in order', () async {
    final r = await fetchAllPages(pages(120), limit: 500);
    expect(r.items, hasLength(120));
    expect(r.items.first, v(0));
    expect(r.items.last, v(119));
    expect(r.failure, isNull);
    expect(r.total, 120);
  });

  test('stops at the limit (queue room) without fetching further pages', () async {
    final log = <String?>[];
    final r = await fetchAllPages(pages(5000, log: log), limit: 501);
    expect(r.items, hasLength(501));
    expect(log, hasLength(11));
  });

  test('a failure in the middle keeps what was fetched and the page to resume from', () async {
    final r = await fetchAllPages(pages(200, failAt: 2), limit: 500);
    expect(r.items, hasLength(100));
    expect(r.failure?.kind, FailureKind.network);
    expect(r.resumeToken, '2');
    expect(r.total, 200);
    final rest = await fetchAllPages(pages(200), startToken: r.resumeToken, limit: 400);
    expect([...r.items, ...rest.items], [for (var i = 0; i < 200; i++) v(i)]);
  });

  test('an empty page ends the fetch even with a next token', () async {
    final log = <String?>[];
    final r = await fetchAllPages((t) async {
      log.add(t);
      return const ApiPage([], nextPageToken: 'again');
    }, limit: 500);
    expect(r.items, isEmpty);
    expect(log, [null]);
  });

  test('progress is reported per page', () async {
    final seen = <(int, int?)>[];
    await fetchAllPages(pages(120), limit: 500, onProgress: (n, t) => seen.add((n, t)));
    expect(seen, [(50, 120), (100, 120), (120, 120)]);
  });

  test('insertAfter keeps the order and the current; missing key appends', () {
    final s = QueueSnapshot(entries: [
      for (var i = 0; i < 3; i++) QueueEntry(key: i, ref: v(i)),
    ], currentKey: 0);
    final added = [QueueEntry(key: 10, ref: v(10)), QueueEntry(key: 11, ref: v(11))];
    expect(insertAfter(s, 1, added).entries.map((e) => e.key), [0, 1, 10, 11, 2]);
    expect(insertAfter(s, 1, added).currentKey, 0);
    expect(insertAfter(s, 42, added).entries.map((e) => e.key), [0, 1, 2, 10, 11]);
  });

  test('a page filtered to nothing (private/deleted) does not end the fetch; the 40-page cap stays', () async {
    final r = await fetchAllPages((t) async {
      final page = t == null ? 0 : int.parse(t);
      if (page == 0) return const ApiPage([], nextPageToken: '1', rawCount: 50);
      return ApiPage([v(page)], nextPageToken: page < 2 ? '${page + 1}' : null, rawCount: 50);
    }, limit: 500);
    expect(r.items, [v(1), v(2)]);
    final log = <String?>[];
    await fetchAllPages((t) async {
      log.add(t);
      return ApiPage(const [], nextPageToken: '${log.length}', rawCount: 50);
    }, limit: 500);
    expect(log, hasLength(40));
  });
}
