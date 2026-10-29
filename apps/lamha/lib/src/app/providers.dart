import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/asset_loader.dart';
import '../engine/schedule.dart';
import '../engine/arabic.dart';
import '../engine/settings.dart';
import '../engine/weather.dart';
import '../engine/widget_theme.dart';
import 'app_settings.dart';
import 'cities.dart';
import 'places.dart';
import 'services.dart';

final engineDataProvider = FutureProvider<EngineData>((ref) => loadEngineData());

final citiesProvider = FutureProvider<List<City>>(
    (ref) async => parseCities(await rootBundle.loadString('assets/cities.json')));

final preferencesProvider =
    FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final widgetBridgeProvider = Provider<WidgetBridge>((ref) => HomeWidgetBridge());

final locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());

final backgroundStoreProvider =
    Provider<BackgroundStore>((ref) => AppGroupBackgroundStore());

final placeGeocoderProvider =
    Provider<PlaceGeocoder>((ref) => GeocodingPlaceGeocoder());

final compassSourceProvider =
    Provider<CompassSource>((ref) => FlutterCompassSource());

final declinationProvider =
    Provider<DeclinationSource>((ref) => AndroidDeclinationSource());

final widgetLaunchProvider = Provider<WidgetLaunch>((ref) => HomeWidgetLaunch());

final weatherServiceProvider =
    Provider<WeatherService>((ref) => OpenMeteoWeatherService());

final systemColorsProvider =
    Provider<SystemColorsSource>((ref) => AndroidSystemColorsSource());

final vibrationProvider = Provider<Vibration>((ref) => DeviceVibration());

final notificationPermissionProvider =
    Provider<NotificationPermission>((ref) => AndroidNotificationPermission());

/// مفتاح آخر قراءة طقس في shared_preferences.
const weatherPrefsKey = 'weather';

/// الساعة (تُثبَّت في الاختبارات).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// عدد أيام الجدول المحفوظ للودجت (ARCHITECTURE).
const scheduleDays = 30;

class AppState {
  const AppState({
    required this.settings,
    required this.schedule,
    required this.cities,
    required this.data,
    this.backgroundPath,
    this.systemColors,
  });

  final LamhaSettings settings;

  /// الجدول كما يُحفظ للودجت؛ المعاينة تُبنى منه.
  final Map<String, Object?> schedule;
  final List<City> cities;
  final EngineData data;

  /// المسار الكامل للقطة الخلفية للمعاينة فقط (لا يُحفظ).
  final String? backgroundPath;

  /// ألوان النظام (أندرويد ١٢+) لسمة «ألوان النظام» في المعاينة.
  final SystemColors? systemColors;
}

/// نتيجة «موقعي»: [named] باسم من geocoding، و[nearest] باسم أقرب مدينة («قرب ...»).
enum LocationResult { named, nearest, denied, failed }

/// معرّفا المكان غير الموجود في قائمة المدن.
const gpsPlaceId = 'gps';
const searchPlaceId = 'search';

class SettingsController extends AsyncNotifier<AppState> {
  late SharedPreferences _prefs;
  String? _backgroundPath;
  WeatherReading? _weather;
  SystemColors? _systemColors;

  /// اللقطة لآيفون فقط؛ في أندرويد `background` في الجدول null.
  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<AppState> build() async {
    final data = await ref.watch(engineDataProvider.future);
    final cities = await ref.watch(citiesProvider.future);
    _prefs = await ref.watch(preferencesProvider.future);
    final saved = _prefs.getString(LamhaSettings.prefsKey);
    var settings = saved == null
        ? LamhaSettings.defaults(cities.first, data.deposits.defaultIds)
        : LamhaSettings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    // إيداع محفوظ لم يعد في deposits.json لا يُكسر الجدول.
    final known = settings.deposits.intersection(data.deposits.ids);
    if (known.length != settings.deposits.length) {
      settings = settings.copyWith(
          deposits: known.isEmpty ? data.deposits.defaultIds : known);
    }
    final bg = settings.backgroundFile;
    if (_ios && bg != null) {
      try {
        _backgroundPath = await ref.read(backgroundStoreProvider).resolve(bg);
      } on Exception catch (e) {
        debugPrint('background: $e');
      }
    }
    final w = _prefs.getString(weatherPrefsKey);
    if (w != null) {
      try {
        _weather = WeatherReading.fromJson(jsonDecode(w) as Map<String, dynamic>);
      } on Object catch (e) {
        debugPrint('weather prefs: $e');
      }
    }
    _systemColors = await ref.read(systemColorsProvider).read();
    final s = _state(settings, cities, data);
    // يُبنى الجدول ويُحفظ عند فتح التطبيق (ARCHITECTURE: متى يُحسب الجدول).
    await _publish(s);
    // الطقس عند فتح التطبيق، دون انتظار.
    unawaited(Future(refreshWeather));
    return s;
  }

  AppState _state(LamhaSettings s, List<City> cities, EngineData data) {
    final now = ref.read(clockProvider)();
    return AppState(
      settings: s,
      schedule: buildSchedule(
        now,
        s.toEngine(withBackground: _ios),
        data,
        days: scheduleDays,
        generatedAt: now,
        weather: _weather,
      ),
      cities: cities,
      data: data,
      backgroundPath: _ios ? _backgroundPath : null,
      systemColors: _systemColors,
    );
  }

  /// يحفظ الإعدادات، ثم الجدول للودجت، ثم يطلب تحديثها.
  Future<void> _publish(AppState s) async {
    await _prefs.setString(LamhaSettings.prefsKey, s.settings.encode());
    final bridge = ref.read(widgetBridgeProvider);
    try {
      await bridge.saveSchedule(jsonEncode(s.schedule));
      await bridge.requestUpdate();
    } catch (e) {
      // فشل الحفظ للودجت لا يوقف التطبيق.
      debugPrint('home_widget: $e');
    }
  }

  Future<void> _update(LamhaSettings s, {bool commit = true}) async {
    final cur = state.requireValue;
    final next = _state(s, cur.cities, cur.data);
    state = AsyncData(next);
    if (commit) await _publish(next);
  }

  LamhaSettings get _s => state.requireValue.settings;

  /// أثناء السحب [commit] = false (المعاينة فقط)، وعند الإفلات يُحفظ.
  Future<void> setOpacity(int value, {bool commit = true}) =>
      _update(_s.copyWith(opacity: value.clamp(0, 100)), commit: commit);

  Future<void> setCity(City c) async {
    await _update(_s.copyWith(
      cityId: c.id,
      cityName: c.name,
      latitude: c.latitude,
      longitude: c.longitude,
      timeZone: c.timeZone,
    ));
    await refreshWeather();
  }

  /// يجلب الطقس للمدينة الحالية ويحفظه في الإعدادات والجدول. بلا إنترنت تبقى آخر قراءة.
  /// يعيد true عند النجاح.
  Future<bool> refreshWeather() async {
    if (!state.hasValue) return false;
    final s = _s;
    final WeatherReading r;
    try {
      r = await ref.read(weatherServiceProvider).current(s.latitude, s.longitude);
    } catch (e) {
      debugPrint('weather: $e');
      return false;
    }
    if (!ref.mounted || !state.hasValue) return false;
    _weather = r;
    await _prefs.setString(weatherPrefsKey, jsonEncode(r.toJson()));
    // المدينة تغيّرت أثناء الجلب: القراءة لا تُعرض لها (isFor في الجدول).
    await _update(_s);
    return true;
  }

  Future<void> setTheme(WidgetTheme t) => _update(_s.copyWith(theme: t));

  Future<void> setFontScale(FontScale f) => _update(_s.copyWith(fontScale: f));

  Future<void> setDigits(DigitStyle d) => _update(_s.copyWith(digits: d));

  /// عند التشغيل يُطلب إذن الإشعارات (أندرويد ١٣+)؛ يعيد false إذا رُفض.
  Future<bool> setLockNotification(bool on) async {
    if (on) {
      bool granted;
      try {
        granted = await ref.read(notificationPermissionProvider).request();
      } catch (e) {
        debugPrint('notification permission: $e');
        granted = false;
      }
      if (!granted) return false;
    }
    await _update(_s.copyWith(lockNotification: on));
    return true;
  }

  /// مكان من البحث أو من الموقع: إحداثياته الفعلية، وتوقيت الرياض (المدن سعودية).
  Future<void> setPlace(Place p, {String id = searchPlaceId}) async {
    await _update(_s.copyWith(
      cityId: id,
      cityName: p.name,
      latitude: p.latitude,
      longitude: p.longitude,
      timeZone: state.requireValue.cities.first.timeZone,
    ));
    await refreshWeather();
  }

  /// قراءة واحدة للموقع، والحساب بإحداثياته الفعلية. الاسم من geocoding بالعربية،
  /// وإن تعذّر فـ[nearLabel] لأقرب مدينة في القائمة (مثل «قرب أبها»).
  Future<LocationResult> useMyLocation(
      {required String Function(String city) nearLabel}) async {
    final ({double latitude, double longitude})? p;
    try {
      p = await ref.read(locationServiceProvider).currentPosition();
    } catch (e) {
      debugPrint('location: $e');
      return LocationResult.failed;
    }
    if (p == null) return LocationResult.denied;
    String? name;
    try {
      name = await ref.read(placeGeocoderProvider).placeName(p.latitude, p.longitude);
    } catch (e) {
      // بلا إنترنت أو بلا خدمة geocoding: اسم أقرب مدينة.
      debugPrint('geocoding: $e');
    }
    final near = nearestCity(state.requireValue.cities, p.latitude, p.longitude);
    await setPlace(
      Place(name: name ?? nearLabel(near.name), latitude: p.latitude, longitude: p.longitude),
      id: gpsPlaceId,
    );
    return name == null ? LocationResult.nearest : LocationResult.named;
  }

  /// البحث عن مدينة أو محافظة؛ يرمي عند فشل الاتصال.
  Future<List<Place>> searchPlaces(String query) =>
      ref.read(placeGeocoderProvider).search(query);

  Future<void> setPrayerMethod(String id) =>
      _update(_s.copyWith(prayerMethod: id));

  /// تخطيط الودجت (الميزة ٥): إعدادات مربع واحد.
  Future<void> updateTile(
          WidgetElement id, TileLayout Function(TileLayout t) change) =>
      _update(_s.copyWith(layout: [
        for (final t in _s.layout) t.id == id ? change(t) : t,
      ]));

  Future<void> setVisible(WidgetElement e, bool on) =>
      updateTile(e, (t) => t.copyWith(visible: on));

  /// نقل مربع من [from] إلى [to] (موضعه بعد حذفه من [from]، كـ onReorderItem).
  Future<void> moveTile(int from, int to) {
    final l = [..._s.layout];
    final t = l.removeAt(from);
    l.insert(to.clamp(0, l.length), t);
    return _update(_s.copyWith(layout: l));
  }

  Future<void> resetLayout() => _update(_s.copyWith(layout: defaultLayout));

  /// يعيد false إذا كان هذا آخر إيداع مفعّل (لا يُلغى).
  Future<bool> setDeposit(String id, bool on) async {
    final d = {..._s.deposits};
    if (!on && d.length == 1 && d.contains(id)) return false;
    on ? d.add(id) : d.remove(id);
    await _update(_s.copyWith(deposits: d));
    return true;
  }

  /// يعيد true إذا اختيرت صورة وحُفظت.
  Future<bool> pickBackground() async {
    final store = ref.read(backgroundStoreProvider);
    final name = await store.pickAndSave();
    if (name == null) return false;
    _backgroundPath = await store.resolve(name);
    await _update(_s.copyWith(backgroundFile: name));
    return true;
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppState>(SettingsController.new);
