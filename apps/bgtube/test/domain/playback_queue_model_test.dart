import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/playback_queue_model.dart';
import 'package:flutter_test/flutter_test.dart';

QueueEntry e(int key, [String? id]) => QueueEntry(key: key, ref: VideoRef(videoId: id ?? 'v$key'));
QueueSnapshot q(List<int> keys, int? current) => QueueSnapshot(entries: [for (final k in keys) e(k)], currentKey: current);
List<int> keys(QueueSnapshot s) => [for (final x in s.entries) x.key];

void main() {
  group('insertNext / append', () {
    test('insertNext puts items right after the current, in order', () {
      final s = insertNext(q([1, 2, 3], 1), [e(10), e(11)]);
      expect(keys(s), [1, 10, 11, 2, 3]);
      expect(s.currentKey, 1);
    });

    test('append adds at the end', () {
      final s = append(q([1, 2], 2), [e(10)]);
      expect(keys(s), [1, 2, 10]);
      expect(s.currentKey, 2);
    });

    test('on an empty queue the first added becomes current', () {
      expect(insertNext(QueueSnapshot.empty, [e(5), e(6)]).currentKey, 5);
      expect(append(QueueSnapshot.empty, [e(5)]).currentKey, 5);
    });

    test('the same video can appear twice under different keys', () {
      final s = append(q([1], 1), [e(2, 'v1')]);
      expect(s.entries.map((x) => x.ref.videoId), ['v1', 'v1']);
    });
  });

  group('remove', () {
    test('removing another item keeps the current by key', () {
      final s = remove(q([1, 2, 3], 3), 1);
      expect(keys(s), [2, 3]);
      expect(s.currentKey, 3);
      expect(s.currentIndex, 1);
    });

    test('removing the current makes the next current, or the previous at the end', () {
      expect(remove(q([1, 2, 3], 2), 2).currentKey, 3);
      expect(remove(q([1, 2, 3], 3), 3).currentKey, 2);
      final empty = remove(q([1], 1), 1);
      expect(empty.isEmpty, isTrue);
      expect(empty.currentKey, isNull);
    });

    test('unknown key is a no-op', () {
      expect(keys(remove(q([1, 2], 1), 9)), [1, 2]);
    });
  });

  group('move', () {
    test('moves an item and tracks the current by key, not index', () {
      final s = move(q([1, 2, 3, 4], 2), 4, 0);
      expect(keys(s), [4, 1, 2, 3]);
      expect(s.currentKey, 2);
      expect(s.currentIndex, 2);
    });

    test('moving the current keeps it current; index is clamped', () {
      final s = move(q([1, 2, 3], 1), 1, 99);
      expect(keys(s), [2, 3, 1]);
      expect(s.current!.key, 1);
      expect(s.next, isNull);
    });
  });

  group('clear and restore', () {
    test('clearUpcoming keeps only the current', () {
      final s = clearUpcoming(q([1, 2, 3, 4], 2));
      expect(keys(s), [2]);
      expect(s.currentKey, 2);
    });

    test('reinsert after clear restores the exact order', () {
      final before = q([1, 2, 3, 4], 2);
      final removed = clearedEntries(before);
      expect(removed.map((r) => r.index), [0, 2, 3]);
      expect(reinsert(clearUpcoming(before), removed), before);
    });

    test('reinsert after removing one item puts it back at its index; duplicates ignored', () {
      final before = q([1, 2, 3], 1);
      final s = reinsert(remove(before, 2), [IndexedEntry(1, e(2))]);
      expect(keys(s), [1, 2, 3]);
      expect(keys(reinsert(s, [IndexedEntry(0, e(2))])), [1, 2, 3]);
    });
  });

  group('navigation', () {
    test('next / previous / upcoming / remaining', () {
      final s = q([1, 2, 3], 2);
      expect(s.next!.key, 3);
      expect(s.previous!.key, 1);
      expect(s.upcoming.map((x) => x.key), [3]);
      expect(s.remainingCount, 1);
      expect(q([1], 1).next, isNull);
      expect(q([1], 1).previous, isNull);
    });

    test('previous after 3s restarts, before 3s goes back, at the first item always restarts', () {
      final s = q([1, 2], 2);
      expect(previousAction(s, const Duration(seconds: 4)), PreviousAction.restart);
      expect(previousAction(s, const Duration(seconds: 3)), PreviousAction.goPrevious);
      expect(previousAction(s, const Duration(seconds: 1)), PreviousAction.goPrevious);
      expect(previousAction(q([1, 2], 1), Duration.zero), PreviousAction.restart);
    });

    test('setCurrent ignores unknown keys', () {
      expect(setCurrent(q([1, 2], 1), 2).currentKey, 2);
      expect(setCurrent(q([1, 2], 1), 9).currentKey, 1);
    });
  });

  group('marks and metadata', () {
    test('markFailed sets and clears the flag for one item', () {
      final s = markFailed(q([1, 2], 1), 2, true);
      expect(s.entries[1].failed, isTrue);
      expect(markFailed(s, 2, false).entries[1].failed, isFalse);
    });

    test('enrichRef fills unknown fields but never replaces a known title with the id', () {
      const bare = VideoRef(videoId: 'abc');
      final r = enrichRef(bare, title: 'Real', author: 'Ch', duration: const Duration(minutes: 2), thumbUrl: 't');
      expect(r, const VideoRef(videoId: 'abc', title: 'Real', author: 'Ch', duration: Duration(minutes: 2), thumbUrl: 't'));
      expect(enrichRef(bare, title: 'abc').title, isNull); // المعرّف ليس عنواناً
      expect(enrichRef(r, title: 'abc').title, 'Real');
      expect(enrichRef(r, title: 'Other').title, 'Real'); // المعروف لا يُستبدل
    });

    test('snapshots are immutable values', () {
      final s = q([1, 2], 1);
      expect(() => s.entries.add(e(3)), throwsUnsupportedError);
      expect(q([1, 2], 1), s);
      expect(q([1, 2], 2) == s, isFalse);
    });
  });
}
