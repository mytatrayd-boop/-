import 'package:bgtube/app.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/models/now_playing.dart';
import 'package:bgtube/domain/ports/playback_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class FakeController implements PlaybackController {
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
  final speeds = <double>[];
  @override
  Future<void> setSpeed(double s) async {
    speeds.add(s);
    speed.value = s;
  }

  final played = <String>[];
  int retries = 0;
  int pauses = 0;

  @override
  Future<void> playVideo(String videoId) async => played.add(videoId);
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
}

Future<void> pump(WidgetTester t, FakeController c, {Locale locale = const Locale('ar')}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [playbackControllerProvider.overrideWithValue(c)],
    child: BgtubeApp(locale: locale),
  ));
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
    await pump(t, c);
    await t.enterText(find.byType(TextField), 'https://youtu.be/dQw4w9WgXcQ');
    await t.testTextInput.receiveAction(TextInputAction.go);
    await t.pumpAndSettle();
    expect(c.played, ['dQw4w9WgXcQ']);
  });

  testWidgets('invalid link shows Arabic error without crash', (t) async {
    final c = FakeController();
    await pump(t, c);
    await t.enterText(find.byType(TextField), 'not a link');
    await t.testTextInput.receiveAction(TextInputAction.go);
    await t.pumpAndSettle();
    expect(find.textContaining('الرابط غير صالح'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(c.played, isEmpty);
  });

  testWidgets('playlist link shows unsupported message', (t) async {
    final c = FakeController();
    await pump(t, c);
    await t.enterText(find.byType(TextField), 'https://www.youtube.com/playlist?list=PL1');
    await t.testTextInput.receiveAction(TextInputAction.go);
    await t.pumpAndSettle();
    expect(find.textContaining('القوائم غير مدعومة'), findsOneWidget);
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

  testWidgets('paste button plays link from clipboard', (t) async {
    final c = FakeController();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'https://youtu.be/dQw4w9WgXcQ'};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(t, c);
    await t.tap(find.text('لصق وتشغيل'));
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
    await pump(t, c);
    await t.tap(find.text('لصق وتشغيل'));
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
}
