import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';

import '../engine/weather.dart';
import '../engine/widget_theme.dart';

/// واجهات المنصة خلف أنواع قابلة للاستبدال في الاختبارات.

/// App Group المشترك مع ودجت آيفون.
const appGroupId = 'group.sa.lamha.shared';

/// اسم الودجت الأصلية في أندرويد وآيفون.
const widgetName = 'LamhaWidget';

/// مستقبل الودجت في أندرويد بالاسم الكامل (android/.../widget/LamhaWidgetReceiver.kt).
const androidWidgetReceiver = 'sa.lamha.lamha.widget.LamhaWidgetReceiver';

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
      qualifiedAndroidName: androidWidgetReceiver,
      iOSName: widgetName,
    );
  }
}

/// قراءة واحدة للموقع بدقة تقريبية.
abstract class LocationService {
  /// يعيد null إذا رُفض الإذن أو تعطلت خدمة الموقع، ويرمي إذا تعذّرت القراءة.
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

/// رابط فتح شاشة القبلة من مربع القبلة في الودجت (LamhaWidget.kt: QIBLA_URI).
final qiblaLaunchUri = Uri.parse('lamha://qibla');

/// هل فُتح التطبيق من مربع القبلة؟
bool isQiblaLaunch(Uri? uri) =>
    uri != null && uri.scheme == qiblaLaunchUri.scheme && uri.host == qiblaLaunchUri.host;

/// فتح التطبيق من الودجت (home_widget). الرابط null إذا لم يُفتح منها.
abstract class WidgetLaunch {
  Future<Uri?> initial();
  Stream<Uri?> get clicks;
}

class HomeWidgetLaunch implements WidgetLaunch {
  @override
  Future<Uri?> initial() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('home_widget launch: $e');
      return null;
    }
  }

  @override
  Stream<Uri?> get clicks => HomeWidget.widgetClicked.handleError(
      (Object e) => debugPrint('home_widget clicks: $e'));
}

/// قراءة من حساس البوصلة: الاتجاه من الشمال، والخطأ المحتمل بالدرجات.
typedef CompassReading = ({double? heading, double? accuracy});

/// حساس البوصلة (flutter_compass). null إذا لم يتوفر في الجهاز.
abstract class CompassSource {
  Stream<CompassReading>? readings();
}

class FlutterCompassSource implements CompassSource {
  @override
  Stream<CompassReading>? readings() => FlutterCompass.events
      ?.map((e) => (heading: e.heading, accuracy: e.accuracy));
}

/// الطقس الحالي من Open-Meteo (بلا مفتاح).
abstract class WeatherService {
  /// يرمي عند فشل الاتصال أو رد غير صالح.
  Future<WeatherReading> current(double latitude, double longitude);
}

class OpenMeteoWeatherService implements WeatherService {
  @override
  Future<WeatherReading> current(double latitude, double longitude) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(openMeteoUri(latitude, longitude));
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw HttpException('Open-Meteo ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return parseOpenMeteo(jsonDecode(body) as Map<String, dynamic>,
          DateTime.now().toUtc(), latitude, longitude);
    } finally {
      client.close();
    }
  }
}

/// قناة MainActivity.kt في أندرويد: ألوان النظام وإذن الإشعارات والاهتزاز.
const androidChannel = MethodChannel('sa.lamha/android');

/// ألوان Material You (أندرويد ١٢+)؛ null في غيره.
abstract class SystemColorsSource {
  Future<SystemColors?> read();
}

class AndroidSystemColorsSource implements SystemColorsSource {
  @override
  Future<SystemColors?> read() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final m = await androidChannel.invokeMapMethod<String, int>('systemColors');
      if (m == null || m['accent'] == null || m['background'] == null) return null;
      return (accent: m['accent']!, background: m['background']!);
    } catch (e) {
      debugPrint('systemColors: $e');
      return null;
    }
  }
}

/// الانحراف المغناطيسي بالدرجات عند الموقع (أندرويد: GeomagneticField، نموذج WMM). بوصلة
/// أندرويد مغناطيسية، فيُضاف إليها ليصير الاتجاه من الشمال الحقيقي كالقبلة. آيفون يعطي الحقيقي
/// أصلاً، فـ٠.
abstract class DeclinationSource {
  Future<double> at(double latitude, double longitude);
}

class AndroidDeclinationSource implements DeclinationSource {
  @override
  Future<double> at(double latitude, double longitude) async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;
    try {
      return await androidChannel.invokeMethod<double>('declination', {'latitude': latitude, 'longitude': longitude}) ?? 0;
    } catch (e) {
      debugPrint('declination: $e');
      return 0;
    }
  }
}

/// إذن POST_NOTIFICATIONS لإشعار شاشة القفل (أندرويد ١٣+؛ الأقدم مسموح دائماً).
abstract class NotificationPermission {
  Future<bool> request();
}

class AndroidNotificationPermission implements NotificationPermission {
  @override
  Future<bool> request() async =>
      await androidChannel.invokeMethod<bool>('requestNotificationPermission') ??
      false;
}

/// نبضتا اهتزاز عند الاتجاه إلى القبلة.
abstract class Vibration {
  Future<void> alignedPulse();
}

/// أندرويد: محرك الاهتزاز عبر MainActivity (HapticFeedback يتبع إعداد «اهتزاز اللمس» وكثيراً ما
/// يُتجاهل). غيره: HapticFeedback.
class DeviceVibration implements Vibration {
  @override
  Future<void> alignedPulse() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await androidChannel.invokeMethod<bool>('vibrate');
      } catch (e) {
        debugPrint('vibrate: $e');
      }
      return;
    }
    // نبضة خفيفة واحدة (lamha_qibla_update.md).
    await HapticFeedback.mediumImpact();
  }
}
