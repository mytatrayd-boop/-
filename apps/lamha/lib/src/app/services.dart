import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

/// اختيار لقطة الخلفية (آيفون) وحفظ نسخة منها في مجلد التطبيق.
/// القص على مقاس الودجت في ميزة لاحقة.
abstract class BackgroundPicker {
  /// مسار الصورة المحفوظة، أو null إذا ألغى المستخدم.
  Future<String?> pickAndSave();
}

class ImagePickerBackgroundPicker implements BackgroundPicker {
  @override
  Future<String?> pickAndSave() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final dot = file.name.lastIndexOf('.');
    final ext = dot >= 0 ? file.name.substring(dot) : '.png';
    final path = '${dir.path}${Platform.pathSeparator}wallpaper$ext';
    await file.saveTo(path);
    return path;
  }
}
