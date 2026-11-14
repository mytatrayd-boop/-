import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

/// فشل حفظ الفيديو في ألبوم الجوال (إذن مرفوض أو ملف مفقود أو خطأ نظام).
class GallerySaveException implements Exception {
  const GallerySaveException(this.message, {this.permissionDenied = false});
  final String message;
  final bool permissionDenied;
  @override
  String toString() => 'GallerySaveException($message)';
}

/// حفظ الفيديو الناتج في ألبوم الجوال. خلف واجهة (features لا تستدعي الأصلي).
abstract class VideoGalleryService {
  /// يحفظ الملف في الألبوم ويعيد المعرّف إن وفّرته المنصة، وإلا null.
  /// يرمي [GallerySaveException] عند الفشل.
  Future<String?> saveVideo(String path);
}

/// اسم الألبوم في الجوال.
const galleryAlbumName = 'Rihla';

/// حزمة gal: لا تُعيد معرّف الأصل (putVideo ترجع void)، فالمعرّف null دائماً.
class GalVideoGalleryService implements VideoGalleryService {
  const GalVideoGalleryService();

  @override
  Future<String?> saveVideo(String path) async {
    try {
      // iOS: ألبوم مخصص يتطلب إذن قراءة وكتابة كامل؛ نكتفي بإذن الإضافة (أقل صلاحية)
      // فيظهر الفيديو في "الأحدث". أندرويد: مجلد Movies/Rihla بلا إذن إضافي.
      final album = Platform.isAndroid ? galleryAlbumName : null;
      if (!await Gal.hasPermission() && !await Gal.requestPermission()) {
        throw const GallerySaveException('permission_denied', permissionDenied: true);
      }
      await Gal.putVideo(path, album: album);
      return null;
    } on GallerySaveException {
      rethrow;
    } on GalException catch (e) {
      throw GallerySaveException(
        e.type.name,
        permissionDenied: e.type == GalExceptionType.permissionDenied,
      );
    } catch (e) {
      throw GallerySaveException(e.toString());
    }
  }
}

class FakeVideoGalleryService implements VideoGalleryService {
  FakeVideoGalleryService({this.failures = 0, this.assetId = 'fake-asset-1'});

  /// عدد المحاولات القادمة التي تفشل قبل أن تنجح.
  int failures;
  String? assetId;
  final List<String> saved = [];
  int calls = 0;

  @override
  Future<String?> saveVideo(String path) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const GallerySaveException('fake_failure');
    }
    saved.add(path);
    return assetId;
  }
}

final videoGalleryProvider = Provider<VideoGalleryService>(
  (_) => const GalVideoGalleryService(),
);
