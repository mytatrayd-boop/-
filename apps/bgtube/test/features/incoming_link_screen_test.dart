import 'dart:async';

import 'package:bgtube/app.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/ports/incoming_link_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player_screen_test.dart' show FakeController;

class FakeSource implements IncomingLinkSource {
  FakeSource(this.initial, {this.initialError});
  final String? initial;
  final Object? initialError;
  int initialCalls = 0;
  final stream = StreamController<String>.broadcast();
  @override
  Future<String?> initialText() async {
    initialCalls++;
    if (initialError != null) throw initialError!;
    return initial;
  }
  @override
  Stream<String> get texts => stream.stream;
}

Future<void> pumpWith(WidgetTester t, FakeController c, FakeSource s) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      playbackControllerProvider.overrideWithValue(c),
      incomingLinkSourceProvider.overrideWithValue(s),
    ],
    child: const BgtubeApp(locale: Locale('ar')),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('cold start with shared text plays the video', (t) async {
    final c = FakeController();
    await pumpWith(t, c, FakeSource('عنوان\nhttps://youtu.be/dQw4w9WgXcQ?si=x'));
    expect(c.played, ['dQw4w9WgXcQ']);
  });

  testWidgets('link received while running plays the video', (t) async {
    final c = FakeController();
    final s = FakeSource(null);
    await pumpWith(t, c, s);
    expect(c.played, isEmpty);
    s.stream.add('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await t.pumpAndSettle();
    expect(c.played, ['dQw4w9WgXcQ']);
  });

  testWidgets('shared playlist link is not played and shows the sign-in message when signed out (D30)', (t) async {
    final c = FakeController();
    await pumpWith(t, c, FakeSource('https://www.youtube.com/playlist?list=PL123'));
    expect(c.played, isEmpty);
    expect(find.textContaining('سجّل الدخول لإضافة قوائم يوتيوب'), findsOneWidget);
  });

  testWidgets('invalid shared text shows error and does not crash', (t) async {
    final c = FakeController();
    final s = FakeSource(null);
    await pumpWith(t, c, s);
    s.stream.add('مرحبا');
    await t.pumpAndSettle();
    expect(c.played, isEmpty);
    expect(find.textContaining('الرابط غير صالح'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('failure reading the initial intent does not crash', (t) async {
    final c = FakeController();
    await pumpWith(t, c, FakeSource(null, initialError: StateError('boom')));
    expect(c.played, isEmpty);
    expect(find.textContaining('ابدأ بالبحث أو الصق رابطاً'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('cold start plays exactly once, even after the UI rebuilds', (t) async {
    final c = FakeController();
    final s = FakeSource('https://youtu.be/dQw4w9WgXcQ');
    await pumpWith(t, c, s);
    expect(c.played, ['dQw4w9WgXcQ']);
    expect(s.initialCalls, 1);
    // إعادة بناء الشجرة (تغيير لغة مثلاً) لا تعيد التشغيل.
    await t.pumpWidget(ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWithValue(c),
        incomingLinkSourceProvider.overrideWithValue(s),
      ],
      child: const BgtubeApp(locale: Locale('en')),
    ));
    await t.pumpAndSettle();
    expect(c.played, ['dQw4w9WgXcQ']);
    expect(s.initialCalls, 1);
  });
}
