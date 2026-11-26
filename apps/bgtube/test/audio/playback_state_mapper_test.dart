import 'package:audio_service/audio_service.dart';
import 'package:bgtube/audio/playback_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

PlaybackEvent event(ProcessingState s) => PlaybackEvent(
      processingState: s,
      updateTime: DateTime(2026),
      updatePosition: const Duration(seconds: 5),
      bufferedPosition: const Duration(seconds: 20),
    );

void main() {
  test('playing shows pause control and ready state', () {
    final st = toPlaybackState(event: event(ProcessingState.ready), playing: true, speed: 1);
    expect(st.playing, isTrue);
    expect(st.processingState, AudioProcessingState.ready);
    expect(st.controls[1], MediaControl.pause);
    expect(st.controls, contains(MediaControl.stop));
    expect(st.updatePosition, const Duration(seconds: 5));
    expect(st.bufferedPosition, const Duration(seconds: 20));
  });

  test('paused shows play control', () {
    final st = toPlaybackState(event: event(ProcessingState.ready), playing: false, speed: 1);
    expect(st.controls[1], MediaControl.play);
  });

  test('maps every processing state', () {
    const expected = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    };
    expected.forEach((k, v) {
      expect(toPlaybackState(event: event(k), playing: false, speed: 1).processingState, v);
    });
  });

  test('seek is a system action (lock screen scrubbing)', () {
    final st = toPlaybackState(event: event(ProcessingState.ready), playing: true, speed: 1);
    expect(st.systemActions, contains(MediaAction.seek));
  });

  test('notification: previous, play/pause, next, stop; compact = previous, play/pause, next (D27)', () {
    final st = toPlaybackState(event: event(ProcessingState.ready), playing: true, speed: 1, queueIndex: 2);
    expect(st.controls, [
      MediaControl.skipToPrevious,
      MediaControl.pause,
      MediaControl.skipToNext,
      MediaControl.stop,
    ]);
    expect(st.androidCompactActionIndices, [0, 1, 2]);
    expect(st.queueIndex, 2);
    expect(st.systemActions, contains(MediaAction.skipToQueueItem));
  });
}
