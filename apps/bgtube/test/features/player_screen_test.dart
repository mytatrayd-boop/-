import 'package:bgtube/app.dart';
import 'package:bgtube/features/player/player_screen.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/models/now_playing.dart';
import 'package:bgtube/features/player/format_duration.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/playback_queue_model.dart';
import 'package:bgtube/domain/ports/playback_controller.dart';
import 'package:bgtube/domain/ports/playback_queue.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// متحكم وهمي ينفّذ المنفذين معاً (كالمعالج الحقيقي)، والطابور بنموذجه الصرف.
class FakeController implements PlaybackController, PlaybackQueue {
  @override
  final ValueNotifier<AppFailure?> failure = ValueNotifier(null);
  @override
  final ValueNotifier<bool> resolving = ValueNotifier(false);
  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);
  @override
  final ValueNotifier<NowPlaying?> nowPlaying = ValueNotifier(null);
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  final ValueNotifier<double> speed = ValueNotifier(1.0);
  @override
  final ValueNotifier<Duration?> sleepRemaining = ValueNotifier(null);
  final sleeps = <Duration>[];
  @override
  void startSleepTimer(Duration d) {
    sleeps.add(d);
    sleepRemaining.value = d;
  }

  @override
  void cancelSleepTimer() => sleepRemaining.value = null;
  final speeds = <double>[];
  @override
  Future<void> setSpeed(double s) async {
    speeds.add(s);
    speed.value = s;
  }

  /// المعرّفات التي طُلب تشغيلها الآن (playVideo أو enqueue بـplayNow أو طابور فارغ).
  final played = <String>[];
  final enqueued = <({List<String> ids, QueuePlacement placement})>[];
  int retries = 0;
  int pauses = 0;
  int nexts = 0;
  int previouses = 0;
  final jumps = <int>[];

  @override
  Future<void> playVideo(String videoId) async => enqueue([VideoRef(videoId: videoId)], QueuePlacement.playNow);
  @override
  Future<void> retry() async => retries++;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}

  // ── الطابور ──
  @override
  final ValueNotifier<QueueSnapshot> queueState = ValueNotifier(QueueSnapshot.empty);
  int _key = 1;
  final skipped = StreamController<VideoRef>.broadcast();
  @override
  Stream<VideoRef> get skippedFailures => skipped.stream;

  @override
  Future<EnqueueResult> enqueue(List<VideoRef> refs, QueuePlacement placement) async {
    final wasEmpty = queueState.value.isEmpty;
    final room = PlaybackQueue.maxLength - queueState.value.entries.length;
    final take = refs.take(room).toList();
    final added = [for (final r in take) QueueEntry(key: _key++, ref: r)];
    enqueued.add((ids: [for (final r in take) r.videoId], placement: placement));
    queueState.value = placement == QueuePlacement.addToEnd
        ? append(queueState.value, added)
        : insertNext(queueState.value, added);
    if (added.isNotEmpty && (placement == QueuePlacement.playNow || wasEmpty)) {
      queueState.value = setCurrent(queueState.value, added.first.key);
      played.add(added.first.ref.videoId);
    }
    return EnqueueResult([for (final e in added) e.key], truncated: take.length < refs.length);
  }

  @override
  Future<EnqueueResult> enqueueAfter(int afterKey, List<VideoRef> refs) async {
    if (queueState.value.indexOfKey(afterKey) < 0) return enqueue(refs, QueuePlacement.addToEnd);
    final room = PlaybackQueue.maxLength - queueState.value.entries.length;
    final take = refs.take(room).toList();
    final added = [for (final r in take) QueueEntry(key: _key++, ref: r)];
    enqueuedAfter.add((after: afterKey, ids: [for (final r in take) r.videoId]));
    queueState.value = insertAfter(queueState.value, afterKey, added);
    return EnqueueResult([for (final e in added) e.key], truncated: take.length < refs.length);
  }

  final enqueuedAfter = <({int after, List<String> ids})>[];

  @override
  Future<void> skipToNext() async => nexts++;
  @override
  Future<void> skipToPrevious() async => previouses++;
  @override
  Future<void> jumpTo(int key) async {
    jumps.add(key);
    queueState.value = setCurrent(queueState.value, key);
  }

  @override
  Future<void> removeEntry(int key) async => queueState.value = remove(queueState.value, key);
  @override
  Future<void> moveEntry(int key, int toIndex) async => queueState.value = move(queueState.value, key, toIndex);
  @override
  Future<void> clearUpcoming() async => queueState.value = clearUpcomingOf(queueState.value);
  @override
  Future<void> removeEntries(List<int> keys) async {
    for (final k in keys) {
      queueState.value = remove(queueState.value, k);
    }
  }

  @override
  Future<void> restoreEntries(List<IndexedEntry> removed) async =>
      queueState.value = reinsert(queueState.value, removed);

  /// يملأ الطابور مباشرة للاختبار.
  void seed(List<VideoRef> refs, {int current = 0}) {
    final entries = [for (final r in refs) QueueEntry(key: _key++, ref: r)];
    queueState.value = QueueSnapshot(entries: entries, currentKey: entries.isEmpty ? null : entries[current].key);
  }
}

QueueSnapshot clearUpcomingOf(QueueSnapshot s) => clearUpcoming(s);

Future<void> pump(WidgetTester t, FakeController c, {Locale locale = const Locale('ar')}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [playbackControllerProvider.overrideWithValue(c)],
    child: BgtubeApp(locale: locale, home: const PlayerScreen()),
  ));
  await t.pumpAndSettle();
}

/// الهيكل الكامل: حقل البحث/الرابط وزر اللصق في الرئيسية (D29).
Future<void> pumpShell(WidgetTester t, FakeController c, {Locale locale = const Locale('ar')}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [playbackControllerProvider.overrideWithValue(c)],
    child: BgtubeApp(locale: locale),
  ));
  await t.pumpAndSettle();
}

Future<void> submitText(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const Key('searchField')), text);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Arabic is RTL and shows empty state', (t) async {
    await pump(t, FakeController());
    expect(find.text('الصق رابط يوتيوب لتشغيله'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold))), TextDirection.rtl);
    expect(t.takeException(), isNull);
  });

  testWidgets('English is LTR', (t) async {
    await pump(t, FakeController(), locale: const Locale('en'));
    expect(find.text('Paste a YouTube link to play it'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold))), TextDirection.ltr);
  });

  testWidgets('valid link submitted starts playback', (t) async {
    final c = FakeController();
    await pumpShell(t, c);
    await submitText(t, 'https://youtu.be/dQw4w9WgXcQ');
    expect(c.played, ['dQw4w9WgXcQ']);
  });

  testWidgets('invalid link shows Arabic error without crash', (t) async {
    final c = FakeController();
    await pumpShell(t, c);
    // يبدو رابطاً لكنه ليس من يوتيوب (النص العادي يصير بحثاً).
    await submitText(t, 'https://example.com/watch?v=x');
    expect(find.textContaining('الرابط غير صالح'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(c.played, isEmpty);
  });

  testWidgets('playlist link shows the sign-in message when signed out (D30)', (t) async {
    final c = FakeController();
    await pumpShell(t, c);
    await submitText(t, 'https://www.youtube.com/playlist?list=PL1');
    expect(find.textContaining('سجّل الدخول لإضافة قوائم يوتيوب'), findsOneWidget);
    expect(c.played, isEmpty);
  });

  testWidgets('extraction failure shows message and retry button', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.failure.value = const AppFailure(FailureKind.extractionFailed);
    await t.pumpAndSettle();
    expect(find.textContaining('تعذّر استخراج الصوت'), findsOneWidget);
    await t.tap(find.text('إعادة المحاولة'));
    expect(c.retries, 1);
  });

  testWidgets('playback failure shows the technical detail small and LTR under the message', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.failure.value = const AppFailure(FailureKind.playbackFailed, 'PlayerException(0) Source error · probe HTTP 403');
    await t.pumpAndSettle();
    expect(find.textContaining('تعذّر تشغيل الصوت'), findsOneWidget);
    final detail = t.widget<SelectableText>(find.byKey(const Key('failureDetail')));
    expect(detail.data, 'PlayerException(0) Source error · probe HTTP 403');
    expect(detail.textDirection, TextDirection.ltr);
    // داخل واجهة عربية RTL، والسطر نفسه LTR.
    expect(Directionality.of(t.element(find.byKey(const Key('failureDetail')))), TextDirection.rtl);
    expect(detail.style?.fontSize, 11);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('failure without detail shows no detail line', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.failure.value = const AppFailure(FailureKind.network);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('failureDetail')), findsNothing);
  });

  testWidgets('paste button plays link from clipboard', (t) async {
    final c = FakeController();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'https://youtu.be/dQw4w9WgXcQ'};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpShell(t, c);
    await t.tap(find.byTooltip('لصق وتشغيل'));
    await t.pumpAndSettle();
    expect(c.played, ['dQw4w9WgXcQ']);
  });

  testWidgets('empty clipboard shows message', (t) async {
    final c = FakeController();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return null;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpShell(t, c);
    await t.tap(find.byTooltip('لصق وتشغيل'));
    await t.pumpAndSettle();
    expect(find.text('لا يوجد رابط يوتيوب في الحافظة'), findsOneWidget);
  });

  testWidgets('now playing panel shows title and pause control', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.nowPlaying.value = const NowPlaying(
        videoId: 'dQw4w9WgXcQ', title: 'Some Title', author: 'Chan', duration: Duration(minutes: 3, seconds: 5));
    c.playing.value = true;
    await t.pumpAndSettle();
    expect(find.text('Some Title'), findsOneWidget);
    await t.tap(find.byTooltip('إيقاف مؤقت'));
    expect(c.pauses, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('title and channel get automatic text direction', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.nowPlaying.value = const NowPlaying(
        videoId: 'dQw4w9WgXcQ', title: 'English Title', author: 'قناة عربية', duration: Duration(minutes: 1));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.text('English Title')).textDirection, TextDirection.ltr);
    expect(t.widget<Text>(find.text('قناة عربية')).textDirection, TextDirection.rtl);
  });

  testWidgets('rate limit failure has its own message', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.failure.value = const AppFailure(FailureKind.rateLimited);
    await t.pumpAndSettle();
    expect(find.textContaining('يقيّد الطلبات'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('speed sheet lists the five options and applies the choice', (t) async {
    final c = FakeController();
    await pump(t, c, locale: const Locale('en'));
    c.nowPlaying.value = const NowPlaying(
        videoId: 'dQw4w9WgXcQ', title: 'T', duration: Duration(minutes: 1));
    await t.pumpAndSettle();
    expect(find.text('1×'), findsOneWidget);
    await t.tap(find.byKey(const Key('speedButton')));
    await t.pumpAndSettle();
    for (final label in ['0.75×', '1×', '1.25×', '1.5×', '2×']) {
      expect(find.text(label), findsWidgets);
    }
    await t.tap(find.byKey(const Key('speed_1.5')));
    await t.pumpAndSettle();
    expect(c.speeds, [1.5]);
    expect(find.text('1.5×'), findsOneWidget); // الزر يعرض القيمة الحالية
    expect(t.takeException(), isNull);
  });

  testWidgets('speed sheet works in Arabic RTL without errors', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.nowPlaying.value = const NowPlaying(
        videoId: 'dQw4w9WgXcQ', title: 'T', duration: Duration(minutes: 1));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('speedButton')));
    await t.pumpAndSettle();
    expect(find.text('سرعة التشغيل'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sleep timer: choose, see remaining, cancel (Arabic RTL)', (t) async {
    final c = FakeController();
    await pump(t, c);
    c.nowPlaying.value = const NowPlaying(
        videoId: 'dQw4w9WgXcQ', title: 'T', duration: Duration(minutes: 1));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('sleepButton')));
    await t.pumpAndSettle();
    expect(find.text('مؤقت النوم'), findsOneWidget);
    expect(find.byKey(const Key('sleepCancel')), findsNothing);
    for (final m in [15, 30, 60]) {
      expect(find.byKey(Key('sleep_$m')), findsOneWidget);
    }
    await t.tap(find.byKey(const Key('sleep_30')));
    await t.pumpAndSettle();
    expect(c.sleeps, [const Duration(minutes: 30)]);
    expect(find.text(formatDuration(const Duration(minutes: 30), 'ar')), findsOneWidget); // العدّاد ظاهر على الزر
    await t.tap(find.byKey(const Key('sleepButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('sleepCancel')));
    await t.pumpAndSettle();
    expect(c.sleepRemaining.value, isNull);
    expect(find.text(formatDuration(const Duration(minutes: 30), 'ar')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
