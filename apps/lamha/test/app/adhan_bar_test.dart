import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/adhan_bar.dart';
import 'package:lamha/src/app/adhan_player.dart';
import 'package:lamha/src/app/providers.dart';

class _FakePlayer implements AdhanPlayer {
  final _playing = ValueNotifier(false);
  var starts = 0;
  var stops = 0;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> start() async {
    starts++;
    _playing.value = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    _playing.value = false;
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('شريط الأذان: يظهر أثناء التشغيل وزر الإيقاف يوقفه', (tester) async {
    final player = _FakePlayer();
    await tester.pumpWidget(ProviderScope(
      overrides: [adhanPlayerProvider.overrideWithValue(player)],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Stack(children: [SizedBox.expand(), AdhanBar()]),
      ),
    ));
    expect(find.byKey(const Key('adhan-bar')), findsNothing);

    await player.start();
    await tester.pump();
    expect(find.byKey(const Key('adhan-bar')), findsOneWidget);
    expect(find.text('الأذان يُرفع الآن'), findsOneWidget);

    await tester.tap(find.byKey(const Key('adhan-stop')));
    await tester.pump();
    expect(player.stops, 1);
    expect(find.byKey(const Key('adhan-bar')), findsNothing);
  });

  test('بلا آيفون: المشغّل لا يفعل شيئاً ولا يظهر شريط', () async {
    final noop = NoopAdhanPlayer();
    await noop.start();
    expect(noop.playing.value, isFalse);
    noop.dispose();
  });
}
