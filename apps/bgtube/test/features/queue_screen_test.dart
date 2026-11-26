import 'dart:async';

import 'package:bgtube/app.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/models/local_playlist.dart';
import 'package:bgtube/domain/models/now_playing.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/playback_queue_model.dart';
import 'package:bgtube/domain/ports/local_playlist_repository.dart';
import 'package:bgtube/domain/ports/playback_queue.dart';
import 'package:bgtube/features/queue/queue_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';

import 'player_screen_test.dart' show FakeController;

/// قوائم محلية في الذاكرة.
class FakePlaylists implements LocalPlaylistRepository {
  final names = <int, String>{};
  final items_ = <int, List<VideoRef>>{};
  int _id = 1;
  bool failing = false;
  final _changes = StreamController<void>.broadcast();

  List<LocalPlaylist> _snapshot() => [
        for (final id in names.keys.toList().reversed)
          LocalPlaylist(
            id: id,
            name: names[id]!,
            itemCount: items_[id]!.length,
            totalDuration: totalDuration(items_[id]!),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
      ];

  Stream<T> _watch<T>(T Function() read) async* {
    if (failing) throw StateError('db');
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  void _changed() => _changes.add(null);

  @override
  Stream<List<LocalPlaylist>> watchAll() => _watch(_snapshot);
  @override
  Future<List<LocalPlaylist>> list() async => _snapshot();
  @override
  Future<int> create(String name, List<VideoRef> refs) async {
    final id = _id++;
    names[id] = name;
    items_[id] = [...refs];
    _changed();
    return id;
  }

  @override
  Future<void> rename(int id, String name) async {
    names[id] = name;
    _changed();
  }

  @override
  Future<void> delete(int id) async {
    names.remove(id);
    items_.remove(id);
    _changed();
  }

  @override
  Future<List<VideoRef>> items(int id) async => [...items_[id]!];
  @override
  Stream<List<VideoRef>> watchItems(int id) => _watch(() => [...items_[id] ?? const <VideoRef>[]]);
  @override
  Future<void> setItems(int id, List<VideoRef> refs) async {
    items_[id] = [...refs];
    _changed();
  }
}

VideoRef v(int i, {Duration? d}) => VideoRef(
      videoId: 'V${i.toString().padLeft(10, '0')}',
      title: 'Song $i',
      author: 'Ch$i',
      duration: d ?? const Duration(minutes: 3),
    );

String formatCountFor(String locale, int n) => NumberFormat.decimalPattern(locale).format(n);

Future<void> pumpApp(WidgetTester t, FakeController c, FakePlaylists p, {Locale locale = const Locale('ar')}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      playbackControllerProvider.overrideWithValue(c),
      localPlaylistRepositoryProvider.overrideWithValue(p),
    ],
    child: BgtubeApp(locale: locale),
  ));
  await t.pumpAndSettle();
}

/// يملأ الطابور ويعرض المشغّل للحالي.
void playing(FakeController c, int n, {int current = 0}) {
  c.seed([for (var i = 0; i < n; i++) v(i)], current: current);
  final cur = v(current);
  c.nowPlaying.value = NowPlaying(videoId: cur.videoId, title: cur.title!, author: cur.author, duration: cur.duration);
}

Future<void> openQueue(WidgetTester t) async {
  await t.tap(find.byKey(const Key('queueButton')));
  await t.pumpAndSettle();
}

void main() {
  late FakeController c;
  late FakePlaylists p;
  setUp(() {
    c = FakeController();
    p = FakePlaylists();
  });

  group('player with a queue', () {
    testWidgets('shows next-up line, remaining badge, and previous/next in fixed LTR order', (t) async {
      playing(c, 4, current: 1);
      await pumpApp(t, c, p);
      expect(find.text('التالي: Song 2'), findsOneWidget);
      expect(find.text(formatCountFor('ar', 2)), findsOneWidget); // شارة المتبقي بأرقام اللغة
      final prev = t.getCenter(find.byKey(const Key('previousButton')));
      final next = t.getCenter(find.byKey(const Key('nextButton')));
      expect(prev.dx, lessThan(next.dx)); // السابق يسار حتى في RTL
      await t.tap(find.byKey(const Key('nextButton')));
      await t.tap(find.byKey(const Key('previousButton')));
      expect(c.nexts, 1);
      expect(c.previouses, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('next is disabled at the end of the queue, and no next-up line', (t) async {
      playing(c, 2, current: 1);
      await pumpApp(t, c, p);
      final next = t.widget<IconButton>(find.byKey(const Key('nextButton')));
      expect(next.onPressed, isNull);
      expect(find.byKey(const Key('nextUpLine')), findsNothing);
    });

    testWidgets('a skipped failure shows a short message', (t) async {
      playing(c, 2);
      await pumpApp(t, c, p);
      c.skipped.add(v(7));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('تعذّر تشغيل «Song 7»، تم الانتقال للتالي'), findsOneWidget);
    });
  });

  group('paste / share with a queue', () {
    void clipboard(WidgetTester t, String text) {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': text};
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    }

    testWidgets('empty queue: plays directly, no sheet', (t) async {
      clipboard(t, 'https://youtu.be/dQw4w9WgXcQ');
      await pumpApp(t, c, p);
      await t.tap(find.text('لصق وتشغيل'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('placement_playNow')), findsNothing);
      expect(c.played, ['dQw4w9WgXcQ']);
    });

    testWidgets('queue not empty: three choices; play next shows a confirmation with undo', (t) async {
      clipboard(t, 'https://youtu.be/dQw4w9WgXcQ');
      playing(c, 2);
      await pumpApp(t, c, p);
      await t.tap(find.text('لصق وتشغيل'));
      await t.pumpAndSettle();
      expect(find.text('شغّل الآن'), findsOneWidget);
      expect(find.text('شغّل التالي'), findsOneWidget);
      expect(find.text('أضف للنهاية'), findsOneWidget);
      await t.tap(find.byKey(const Key('placement_playNext')));
      await t.pumpAndSettle();
      expect(c.enqueued.last.placement, QueuePlacement.playNext);
      expect(c.queueState.value.entries[1].ref.videoId, 'dQw4w9WgXcQ');
      expect(find.text('سيُشغَّل التالي: مقطع من يوتيوب'), findsOneWidget);
      await t.tap(find.text('تراجع'));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.videoId), [v(0).videoId, v(1).videoId]);
    });

    testWidgets('add to end and play now choices', (t) async {
      clipboard(t, 'https://youtu.be/dQw4w9WgXcQ');
      playing(c, 2);
      await pumpApp(t, c, p);
      await t.tap(find.text('لصق وتشغيل'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('placement_addToEnd')));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.last.ref.videoId, 'dQw4w9WgXcQ');
      expect(find.text('أُضيف إلى نهاية الطابور'), findsOneWidget);
      await t.pump(const Duration(seconds: 5)); // تختفي الرسالة (٤ ث)
      await t.pumpAndSettle();
      await t.tap(find.text('لصق وتشغيل'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('placement_playNow')));
      await t.pumpAndSettle();
      expect(c.played, ['dQw4w9WgXcQ']);
    });
  });

  group('queue sheet', () {
    testWidgets('current is highlighted with a text label; rows have the drag handle at the end side (RTL)', (t) async {
      playing(c, 3, current: 1);
      await pumpApp(t, c, p);
      await openQueue(t);
      expect(find.text('الطابور'), findsOneWidget);
      expect(find.textContaining('يعمل الآن'), findsOneWidget);
      expect(find.byKey(const Key('queueSummary')), findsOneWidget);
      final row = find.ancestor(of: find.text('Song 2'), matching: find.byType(InkWell)).first;
      final handle = find.descendant(of: row, matching: find.byIcon(Icons.drag_handle));
      expect(t.getCenter(handle).dx, lessThan(t.getCenter(find.text('Song 2')).dx)); // يسار في RTL
      // الحالي لا مقبض له.
      expect(find.descendant(of: find.byKey(const Key('queueCurrentRow')), matching: find.byIcon(Icons.drag_handle)),
          findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('drag handle is on the right in English (LTR)', (t) async {
      playing(c, 2);
      await pumpApp(t, c, p, locale: const Locale('en'));
      await openQueue(t);
      final handle = find.byIcon(Icons.drag_handle);
      expect(t.getCenter(handle).dx, greaterThan(t.getCenter(find.text('Song 1')).dx));
    });

    testWidgets('tap jumps to the item', (t) async {
      playing(c, 3);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.tap(find.text('Song 2'));
      await t.pumpAndSettle();
      expect(c.jumps, [c.queueState.value.entries[2].key]);
    });

    testWidgets('swipe deletes with undo that restores the position', (t) async {
      playing(c, 3);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.drag(find.text('Song 1'), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.title), ['Song 0', 'Song 2']);
      expect(find.text('حُذف من الطابور'), findsOneWidget);
      await t.tap(find.text('تراجع'));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.title), ['Song 0', 'Song 1', 'Song 2']);
    });

    testWidgets('the current row cannot be swiped away', (t) async {
      playing(c, 2);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.drag(find.text('Song 0').last, const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries, hasLength(2));
    });

    testWidgets('reorder by dragging the handle', (t) async {
      playing(c, 3);
      await pumpApp(t, c, p);
      await openQueue(t);
      final handle = find.descendant(
          of: find.ancestor(of: find.text('Song 2'), matching: find.byType(InkWell)).first,
          matching: find.byIcon(Icons.drag_handle));
      final g = await t.startGesture(t.getCenter(handle));
      await t.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 50));
      }
      await g.up();
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.title), ['Song 0', 'Song 2', 'Song 1']);
      expect(c.queueState.value.current!.ref.title, 'Song 0');
    });

    testWidgets('long press menu: move to play next', (t) async {
      playing(c, 4);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.longPress(find.text('Song 3'));
      await t.pumpAndSettle();
      expect(find.text('إزالة من الطابور'), findsOneWidget);
      await t.tap(find.byKey(const Key('queueRowMoveNext')));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.title), ['Song 0', 'Song 3', 'Song 1', 'Song 2']);
    });

    testWidgets('clear asks for confirmation, keeps the current, and can be undone', (t) async {
      playing(c, 3, current: 1);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.tap(find.byKey(const Key('queueClear')));
      await t.pumpAndSettle();
      expect(find.text('مسح الطابور؟'), findsOneWidget);
      expect(find.text('سيبقى المقطع الحالي يعمل.'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirmDestructive')));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.title), ['Song 1']);
      expect(find.byKey(const Key('queueNothingAfter')), findsOneWidget);
      expect(find.text('مُسح الطابور'), findsOneWidget);
      await t.tap(find.text('تراجع'));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries.map((e) => e.ref.title), ['Song 0', 'Song 1', 'Song 2']);
    });

    testWidgets('cancel on the clear dialog changes nothing', (t) async {
      playing(c, 3);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.tap(find.byKey(const Key('queueClear')));
      await t.pumpAndSettle();
      await t.tap(find.text('إلغاء'));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries, hasLength(3));
    });

    testWidgets('failed item shows a warning icon and text', (t) async {
      playing(c, 3);
      final failedKey = c.queueState.value.entries[1].key;
      c.queueState.value = markFailed(c.queueState.value, failedKey, true);
      await pumpApp(t, c, p);
      await openQueue(t);
      expect(find.byKey(Key('queueFailed_$failedKey')), findsOneWidget);
      expect(find.text('تعذّر تشغيله، تم تخطّيه'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('empty queue shows a friendly text and hides save/clear', (t) async {
      await pumpApp(t, c, p);
      c.nowPlaying.value = const NowPlaying(videoId: 'dQw4w9WgXcQ', title: 'T');
      await t.pumpAndSettle();
      await openQueue(t);
      expect(find.text('الطابور فارغ'), findsOneWidget);
      expect(find.byKey(const Key('queueSave')), findsNothing);
      expect(find.byKey(const Key('queueClear')), findsNothing);
    });

    testWidgets('200 items open lazily without errors and scroll to the current', (t) async {
      playing(c, 200, current: 150);
      await pumpApp(t, c, p);
      await openQueue(t);
      expect(find.byKey(const Key('queueCurrentRow')), findsOneWidget);
      expect(find.text('Song 0'), findsNothing); // لم تُبنَ كل الصفوف
      expect(t.takeException(), isNull);
    });

    testWidgets('save as playlist: prefilled name, saved as a local copy, confirmation', (t) async {
      playing(c, 3);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.tap(find.byKey(const Key('queueSave')));
      await t.pumpAndSettle();
      final field = t.widget<TextField>(find.byKey(const Key('playlistNameField')));
      expect(field.controller!.text, startsWith('طابور '));
      await t.enterText(find.byKey(const Key('playlistNameField')), '');
      await t.pump();
      expect(t.widget<FilledButton>(find.byKey(const Key('playlistNameSave'))).onPressed, isNull);
      await t.enterText(find.byKey(const Key('playlistNameField')), 'صباحي');
      await t.pump();
      await t.tap(find.byKey(const Key('playlistNameSave')));
      await t.pumpAndSettle();
      expect(p.names.values, ['صباحي']);
      expect(p.items_.values.single.map((r) => r.title), ['Song 0', 'Song 1', 'Song 2']);
      expect(find.text('حُفظت قائمة «صباحي»'), findsOneWidget);
      expect(find.text('فتح'), findsOneWidget);
    });
  });

  group('local playlists', () {
    Future<void> openPlaylists(WidgetTester t) async {
      await t.tap(find.byKey(const Key('openLocalPlaylists')));
      await t.pumpAndSettle();
    }

    testWidgets('reachable from the player bar; empty state; create a new playlist', (t) async {
      await pumpApp(t, c, p);
      await openPlaylists(t);
      expect(find.text('قوائمي المحلية'), findsOneWidget);
      expect(find.text('لم تنشئ قوائم بعد. احفظ الطابور أو أنشئ قائمة'), findsOneWidget);
      await t.tap(find.byKey(const Key('emptyNewPlaylist')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('playlistNameField')), 'جديدة');
      await t.pump();
      await t.tap(find.byKey(const Key('playlistNameSave')));
      await t.pumpAndSettle();
      expect(find.text('جديدة'), findsOneWidget);
      expect(find.text('على الجهاز'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('row menu: play next / add to end go through enqueue; rename; delete with confirm', (t) async {
      await p.create('قائمتي', [v(5), v(6)]);
      playing(c, 1);
      await pumpApp(t, c, p);
      await openPlaylists(t);
      expect(find.textContaining('${formatCountFor('ar', 2)} مقاطع'), findsOneWidget);
      final id = p.names.keys.single;
      await t.tap(find.byKey(Key('playlistMenu_$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('playlistMenuPlayNext')));
      await t.pumpAndSettle();
      expect(c.enqueued.last.placement, QueuePlacement.playNext);
      expect(c.enqueued.last.ids, [v(5).videoId, v(6).videoId]);
      expect(find.text('أُضيف ${formatCountFor('ar', 2)} مقطعاً إلى الطابور'), findsOneWidget);

      await t.tap(find.byKey(Key('playlistMenu_$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('playlistMenuRename')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('playlistNameField')), 'اسم آخر');
      await t.pump();
      await t.tap(find.byKey(const Key('playlistNameSave')));
      await t.pumpAndSettle();
      expect(p.names[id], 'اسم آخر');

      await t.tap(find.byKey(Key('playlistMenu_$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('playlistMenuDelete')));
      await t.pumpAndSettle();
      expect(find.text('لن تُحذف المقاطع من يوتيوب.'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirmDestructive')));
      await t.pumpAndSettle();
      expect(p.names, isEmpty);
    });

    testWidgets('storage error shows a retry card', (t) async {
      p.failing = true;
      await pumpApp(t, c, p);
      await openPlaylists(t);
      expect(find.text('تعذّر فتح القوائم المحلية'), findsOneWidget);
      p.failing = false;
      await t.tap(find.text('إعادة المحاولة'));
      await t.pumpAndSettle();
      expect(find.text('لم تنشئ قوائم بعد. احفظ الطابور أو أنشئ قائمة'), findsOneWidget);
    });

    testWidgets('playlist detail: play all, add whole list with two choices, swipe delete with undo', (t) async {
      await p.create('قائمتي', [v(5), v(6), v(7)]);
      await pumpApp(t, c, p);
      await openPlaylists(t);
      await t.tap(find.text('قائمتي'));
      await t.pumpAndSettle();
      expect(find.text('Song 6'), findsOneWidget);

      await t.drag(find.text('Song 6'), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(p.items_.values.single.map((r) => r.title), ['Song 5', 'Song 7']);
      await t.tap(find.text('تراجع'));
      await t.pumpAndSettle();
      expect(p.items_.values.single.map((r) => r.title), ['Song 5', 'Song 6', 'Song 7']);

      await t.tap(find.byKey(const Key('playAll')));
      await t.pumpAndSettle();
      expect(c.played, [v(5).videoId]);
      expect(c.enqueued.last.ids, hasLength(3));

      await t.tap(find.byKey(const Key('addWholeList')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('placement_playNow')), findsNothing);
      await t.tap(find.byKey(const Key('placement_addToEnd')));
      await t.pumpAndSettle();
      expect(c.enqueued.last.placement, QueuePlacement.addToEnd);
      expect(t.takeException(), isNull);
    });

    testWidgets('empty playlist shows a friendly text', (t) async {
      await p.create('فارغة', []);
      await pumpApp(t, c, p);
      await openPlaylists(t);
      await t.tap(find.text('فارغة'));
      await t.pumpAndSettle();
      expect(find.text('القائمة فارغة. أضف مقاطع من ⋮ على أي مقطع'), findsOneWidget);
      expect(find.byKey(const Key('playAll')), findsNothing);
    });

    testWidgets('add a queue item to a local playlist; duplicates are reported', (t) async {
      await p.create('أ', [v(9)]);
      playing(c, 2);
      await pumpApp(t, c, p);
      await openQueue(t);
      await t.longPress(find.text('Song 1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('queueRowAddToPlaylist')));
      await t.pumpAndSettle();
      await t.tap(find.text('أ'));
      await t.pumpAndSettle();
      expect(p.items_.values.single.map((r) => r.title), ['Song 9', 'Song 1']);
      expect(find.text('أُضيف إلى «أ»'), findsOneWidget);
      await t.longPress(find.text('Song 1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('queueRowAddToPlaylist')));
      await t.pumpAndSettle();
      await t.tap(find.text('أ'));
      await t.pumpAndSettle();
      expect(find.text('موجود في «أ» بالفعل'), findsOneWidget);
    });
  });
}
