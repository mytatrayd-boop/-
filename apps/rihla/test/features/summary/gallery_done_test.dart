import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/gallery/video_gallery_service.dart';
import 'package:rihla/features/summary/gallery_save_controller.dart';

import '../../helpers/fakes.dart';

Future<ProviderContainer> open(HomeFakes f, String id) async {
  final c = ProviderContainer(overrides: f.overrides);
  addTearDown(c.dispose);
  c.listen(gallerySaveProvider(id), (_, _) {});
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return c;
}

Future<String> withTrip(HomeFakes f) async {
  final id = await f.repo.startTrip(startedAt: DateTime.utc(2026, 1, 1));
  await f.repo.completeTrip(id, videoPath: '/v/t1.mp4');
  return id;
}

void main() {
  test('gal بلا معرّف: galleryDone يُحفظ وvideoAssetId يبقى فارغاً', () async {
    final f = HomeFakes(gallery: FakeVideoGalleryService(assetId: null));
    final id = await withTrip(f);
    final c = await open(f, id);
    expect(c.read(gallerySaveProvider(id)), GallerySaveStatus.saved);
    final trip = (await f.repo.getTrip(id))!;
    expect(trip.galleryDone, isTrue);
    expect(trip.videoAssetId, isNull);
  });

  test('إعادة فتح الملخص (حاوية جديدة = جلسة جديدة) لا تكرر الحفظ', () async {
    final f = HomeFakes(gallery: FakeVideoGalleryService(assetId: null));
    final id = await withTrip(f);
    await open(f, id);
    expect(f.gallery.calls, 1);
    final c2 = await open(f, id);
    expect(c2.read(gallerySaveProvider(id)), GallerySaveStatus.saved);
    expect(f.gallery.calls, 1);
  });

  test('الفشل لا يضع العلامة، وإعادة المحاولة تضعها', () async {
    final f = HomeFakes(
      gallery: FakeVideoGalleryService(failures: 1, assetId: null),
    );
    final id = await withTrip(f);
    final c = await open(f, id);
    expect(c.read(gallerySaveProvider(id)), GallerySaveStatus.failed);
    expect((await f.repo.getTrip(id))!.galleryDone, isFalse);
    await c.read(gallerySaveProvider(id).notifier).retry();
    expect(c.read(gallerySaveProvider(id)), GallerySaveStatus.saved);
    expect((await f.repo.getTrip(id))!.galleryDone, isTrue);
  });
}
