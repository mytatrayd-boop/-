import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/asset_loader.dart';
import '../engine/schedule.dart';
import '../engine/settings.dart';
import 'app_settings.dart';
import 'cities.dart';
import 'services.dart';

final engineDataProvider = FutureProvider<EngineData>((ref) => loadEngineData());

final citiesProvider = FutureProvider<List<City>>(
    (ref) async => parseCities(await rootBundle.loadString('assets/cities.json')));

final preferencesProvider =
    FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final widgetBridgeProvider = Provider<WidgetBridge>((ref) => HomeWidgetBridge());

final locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());

final backgroundPickerProvider =
    Provider<BackgroundPicker>((ref) => ImagePickerBackgroundPicker());

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
  });

  final LamhaSettings settings;

  /// الجدول كما يُحفظ للودجت؛ المعاينة تُبنى منه.
  final Map<String, Object?> schedule;
  final List<City> cities;
  final EngineData data;
}

enum LocationResult { ok, unavailable }

class SettingsController extends AsyncNotifier<AppState> {
  late SharedPreferences _prefs;

  @override
  Future<AppState> build() async {
    final data = await ref.watch(engineDataProvider.future);
    final cities = await ref.watch(citiesProvider.future);
    _prefs = await ref.watch(preferencesProvider.future);
    final saved = _prefs.getString(LamhaSettings.prefsKey);
    var settings = saved == null
        ? LamhaSettings.defaults(cities.first, data.deposits.ids)
        : LamhaSettings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    final s = _state(settings, cities, data);
    // يُبنى الجدول ويُحفظ عند فتح التطبيق (ARCHITECTURE: متى يُحسب الجدول).
    await _publish(s);
    return s;
  }

  AppState _state(LamhaSettings s, List<City> cities, EngineData data) =>
      AppState(
        settings: s,
        schedule: buildSchedule(
          ref.read(clockProvider)(),
          s.toEngine(),
          data,
          days: scheduleDays,
        ),
        cities: cities,
        data: data,
      );

  /// يحفظ الإعدادات، ثم الجدول للودجت، ثم يطلب تحديثها.
  Future<void> _publish(AppState s) async {
    await _prefs.setString(LamhaSettings.prefsKey, s.settings.encode());
    final bridge = ref.read(widgetBridgeProvider);
    try {
      await bridge.saveSchedule(jsonEncode(s.schedule));
      await bridge.requestUpdate();
    } on Exception catch (e) {
      // الودجت الأصلية لم تُكتب بعد؛ لا يوقف ذلك التطبيق.
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

  Future<void> setCity(City c) => _update(_s.copyWith(
        cityId: c.id,
        cityName: c.name,
        latitude: c.latitude,
        longitude: c.longitude,
        timeZone: c.timeZone,
      ));

  /// قراءة واحدة للموقع؛ الاسم من أقرب مدينة في القائمة.
  Future<LocationResult> useMyLocation() async {
    final ({double latitude, double longitude})? p;
    try {
      p = await ref.read(locationServiceProvider).currentPosition();
    } on Exception catch (e) {
      debugPrint('location: $e');
      return LocationResult.unavailable;
    }
    if (p == null) return LocationResult.unavailable;
    final c = nearestCity(state.requireValue.cities, p.latitude, p.longitude);
    await _update(_s.copyWith(
      cityId: c.id,
      cityName: c.name,
      latitude: p.latitude,
      longitude: p.longitude,
      timeZone: c.timeZone,
    ));
    return LocationResult.ok;
  }

  Future<void> setPrayerMethod(String id) =>
      _update(_s.copyWith(prayerMethod: id));

  Future<void> setVisible(WidgetElement e, bool on) {
    final v = {..._s.visible};
    on ? v.add(e) : v.remove(e);
    return _update(_s.copyWith(visible: v));
  }

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
    final path = await ref.read(backgroundPickerProvider).pickAndSave();
    if (path == null) return false;
    await _update(_s.copyWith(backgroundPath: path));
    return true;
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppState>(SettingsController.new);
