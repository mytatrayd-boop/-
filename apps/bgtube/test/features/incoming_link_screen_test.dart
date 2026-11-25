import 'dart:async';

import 'package:bgtube/app.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/ports/incoming_link_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player_screen_test.dart' show FakeController;

class FakeSource implements IncomingLinkSource {
  FakeSource(this.initial);
  final String? initial;
  final stream = StreamController<String>.broadcast();
  @override
  Future<String?> initialText() async => initial;
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

  testWidgets('shared playlist link is not played and shows unsupported message', (t) async {
    final c = FakeController();
    await pumpWith(t, c, FakeSource('https://www.youtube.com/playlist?list=PL123'));
    expect(c.played, isEmpty);
    expect(find.textContaining('القوائم غير مدعومة'), findsOneWidget);
  });

  testWidgets('invalid shared text shows error and does not crash', (t) async {
    final c = FakeController();
    final s = FakeSource(null);
    await pumpWith(t, c, s);
    s.stream.add('مرحبا');
    await t.pumpAndSettle();
    expect(c.played, isEmpty);
    expect(t.takeException(), isNull);
  });
}
