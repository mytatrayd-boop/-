import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';

/// واجهات المنصة خلف أنواع قابلة للاستبدال في الاختبارات.

/// App Group المشترك مع ودجت آيفون.
const appGroupId = 'group.sa.lamha.shared';

/// اسم الودجت الأصلية في أندرويد وآيفون.
const widgetName = 'LamhaWidget';

/// مفتاح الجدول (نص JSON) في التخزين المشترك.
const scheduleKey = 'schedule';

/// طبقة الربط بالودجت الأصلية (حزمة home_widget).
abstract class WidgetBridge {
  Future<void> saveSchedule(String json);
  Future<void> requestUpdate();
}

class HomeWidgetBridge implements WidgetBridge {
  bool _groupSet = false;

  @override
  Future<void> saveSchedule(String json) async {
    if (!_groupSet) {
      await HomeWidget.setAppGroupId(appGroupId);
      _groupSet = true;
    }
    await HomeWidget.saveWidgetData<String>(scheduleKey, json);
  }

  @override
  Future<void> requestUpdate() async {
    await HomeWidget.updateWidget(
      androidName: widgetName,
      iOSName: widgetName,
    );
  }
}

/// قراءة واحدة للموقع بدقة تقريبية.
abstract class LocationService {
  /// يعيد null إذا رُفض الإذن أو تعطلت خدمة الموقع.
  Future<({double latitude, double longitude})?> currentPosition();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<({double latitude, double longitude})?> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return (latitude: p.latitude, longitude: p.longitude);
  }
}

/// اختيار لقطة الخلفية (آيفون) وحفظها في حاوية App Group [appGroupId]
/// لتقرأها الودجت من حاويتها. القص على مقاس الودجت في ميزة لاحقة.
abstract class BackgroundStore {
  /// اسم الملف المحفوظ داخل الحاوية (نسبي)، أو null إذا ألغى المستخدم.
  Future<String?> pickAndSave();

  /// المسار الكامل للملف [fileName] لعرضه في المعاينة، أو null.
  Future<String?> resolve(String fileName);
}

/// قناة صغيرة في AppDelegate تعيد مسار containerURL للـApp Group.
const appGroupChannel = MethodChannel('sa.lamha/app_group');

class AppGroupBackgroundStore implements BackgroundStore {
  Future<String?> _container() =>
      appGroupChannel.invokeMethod<String>('containerPath', appGroupId);

  @override
  Future<String?> pickAndSave() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final dir = await _container();
    if (dir == null) throw StateError('App Group غير متاح: $appGroupId');
    final dot = file.name.lastIndexOf('.');
    final ext = dot >= 0 ? file.name.substring(dot) : '.png';
    final name = 'wallpaper$ext';
    await file.saveTo('$dir${Platform.pathSeparator}$name');
    return name;
  }

  @override
  Future<String?> resolve(String fileName) async {
    final dir = await _container();
    if (dir == null) return null;
    final path = '$dir${Platform.pathSeparator}$fileName';
    return File(path).existsSync() ? path : null;
  }
}
