import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/engine/adhan.dart';
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

  var armed = <AdhanEvent>[];
  var disarms = 0;

  @override
  Future<void> arm(List<AdhanEvent> events, {void Function(AdhanEvent event)? onPrepare}) async => armed = events;

  @override
  Future<void> disarm() async => disarms++;

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

  test('الخلفية: ثانية الصمت المتكررة والأذان الكامل أصلان في التطبيق، وUIBackgroundModes: audio', () {
    expect(File('assets/audio/silence.wav').existsSync(), isTrue);
    expect(File('assets/audio/adhan.mp3').existsSync(), isTrue);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/audio/silence.wav'));
    expect(pubspec, contains('assets/audio/adhan.mp3'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('UIBackgroundModes'));
    expect(plist, contains('<string>audio</string>'));
    expect(AudioAdhanPlayer.prepareLead, const Duration(seconds: 20));
  });
}
