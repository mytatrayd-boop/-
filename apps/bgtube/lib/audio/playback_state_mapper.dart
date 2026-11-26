import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

const _processingStates = {
  ProcessingState.idle: AudioProcessingState.idle,
  ProcessingState.loading: AudioProcessingState.loading,
  ProcessingState.buffering: AudioProcessingState.buffering,
  ProcessingState.ready: AudioProcessingState.ready,
  ProcessingState.completed: AudioProcessingState.completed,
};

/// أزرار الإشعار وشاشة القفل (D27): السابق، تشغيل/إيقاف، التالي، إيقاف؛ والثلاثة
/// المضغوطة: السابق، تشغيل/إيقاف، التالي. ثابتة الفهارس (audio_service لا يعرف
/// الزر المعطّل؛ التالي في آخر الطابور لا يفعل شيئاً).
List<MediaControl> playbackControls({required bool playing}) => [
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];

const compactActionIndices = [0, 1, 2];

/// يحوّل حدث just_audio إلى [PlaybackState] لـaudio_service (إشعار وشاشة قفل).
/// [queueIndex] من نموذج الطابور لا من just_audio (مصدر واحد في كل لحظة).
PlaybackState toPlaybackState({
  required PlaybackEvent event,
  required bool playing,
  required double speed,
  int? queueIndex,
}) {
  return PlaybackState(
    controls: playbackControls(playing: playing),
    systemActions: const {MediaAction.seek, MediaAction.skipToQueueItem},
    androidCompactActionIndices: compactActionIndices,
    processingState: _processingStates[event.processingState]!,
    playing: playing,
    updatePosition: event.updatePosition,
    bufferedPosition: event.bufferedPosition,
    speed: speed,
    updateTime: event.updateTime,
    queueIndex: queueIndex,
  );
}
