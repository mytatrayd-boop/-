import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/gallery/video_gallery_service.dart';
import '../../data/repositories/trip_repository.dart';

/// حالة حفظ فيديو الرحلة في ألبوم الجوال.
enum GallerySaveStatus { none, saving, saved, failed }

/// يحفظ فيديو الرحلة في الألبوم مرة عند فتح الملخص، ويسمح بإعادة المحاولة.
/// العلامة galleryDone في قاعدة البيانات تمنع التكرار حتى بعد إعادة تشغيل التطبيق.
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
      if (trip!.galleryDone || trip.videoAssetId != null) {
        set(GallerySaveStatus.saved);
        return;
      }
      try {
        final id = await gallery.saveVideo(path);
        // الحفظ نجح فعلاً: فشل تسجيل العلامة لا يقلبه إلى فشل (يُكرَّر فقط عند الجلسة التالية).
        try {
          await repo.markGallerySaved(tripId, assetId: id);
        } catch (_) {}
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
