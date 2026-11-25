import '../models/playback_position.dart';

/// تخزين آخر موضع لكل فيديو (ينفّذه drift في طبقة data).
abstract interface class PositionRepository {
  Future<PlaybackPosition?> get(String videoId);
  Future<void> save(PlaybackPosition position);
  Future<void> delete(String videoId);
}
