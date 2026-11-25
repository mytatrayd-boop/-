import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

const _processingStates = {
  ProcessingState.idle: AudioProcessingState.idle,
  ProcessingState.loading: AudioProcessingState.loading,
  ProcessingState.buffering: AudioProcessingState.buffering,
  ProcessingState.ready: AudioProcessingState.ready,
  ProcessingState.completed: AudioProcessingState.completed,
};

/// يحوّل حدث just_audio إلى [PlaybackState] لـaudio_service (إشعار وشاشة قفل).
PlaybackState toPlaybackState({
  required PlaybackEvent event,
  required bool playing,
  required double speed,
}) {
  return PlaybackState(
    controls: [
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
    ],
    systemActions: const {MediaAction.seek},
    androidCompactActionIndices: const [0, 1],
    processingState: _processingStates[event.processingState]!,
    playing: playing,
    updatePosition: event.updatePosition,
    bufferedPosition: event.bufferedPosition,
    speed: speed,
    updateTime: event.updateTime,
    queueIndex: event.currentIndex,
  );
}
