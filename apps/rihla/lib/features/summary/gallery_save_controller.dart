import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/gallery/video_gallery_service.dart';
import '../../data/repositories/trip_repository.dart';

/// حالة حفظ فيديو الرحلة في ألبوم الجوال.
enum GallerySaveStatus { none, saving, saved, failed }

/// يحفظ فيديو الرحلة في الألبوم مرة عند فتح الملخص، ويسمح بإعادة المحاولة.
/// غير autoDispose عمداً: العودة للملخص في الجلسة نفسها لا تكرر الحفظ.
class GallerySaveController extends Notifier<GallerySaveStatus> {
  GallerySaveController(this.tripId);
  final String tripId;
  bool _running = false;

  @override
  GallerySaveStatus build() {
    Future.microtask(retry);
    return GallerySaveStatus.saving;
  }

  Future<void> retry() async {
    if (_running) return;
    _running = true;
    state = GallerySaveStatus.saving;
    void set(GallerySaveStatus v) {
      if (ref.mounted) state = v;
    }

    try {
      final repo = ref.read(tripRepositoryProvider);
      final gallery = ref.read(videoGalleryProvider);
      final trip = await repo.getTrip(tripId);
      final path = trip?.videoPath;
      if (path == null) {
        set(GallerySaveStatus.none);
        return;
      }
      if (trip!.videoAssetId != null) {
        set(GallerySaveStatus.saved);
        return;
      }
      try {
        final id = await gallery.saveVideo(path);
        if (id != null) await repo.setVideoAssetId(tripId, id);
        set(GallerySaveStatus.saved);
      } catch (_) {
        set(GallerySaveStatus.failed);
      }
    } catch (_) {
      set(GallerySaveStatus.failed);
    } finally {
      _running = false;
    }
  }
}

final gallerySaveProvider = NotifierProvider.family<
  GallerySaveController,
  GallerySaveStatus,
  String
>(GallerySaveController.new);
