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

final backgroundStoreProvider =
    Provider<BackgroundStore>((ref) => AppGroupBackgroundStore());

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
  });

  final LamhaSettings settings;

  /// الجدول كما يُحفظ للودجت؛ المعاينة تُبنى منه.
  final Map<String, Object?> schedule;
  final List<City> cities;
  final EngineData data;

  /// المسار الكامل للقطة الخلفية للمعاينة فقط (لا يُحفظ).
  final String? backgroundPath;
}

enum LocationResult { ok, unavailable }

class SettingsController extends AsyncNotifier<AppState> {
  late SharedPreferences _prefs;
  String? _backgroundPath;

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
    final s = _state(settings, cities, data);
    // يُبنى الجدول ويُحفظ عند فتح التطبيق (ARCHITECTURE: متى يُحسب الجدول).
    await _publish(s);
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
      ),
      cities: cities,
      data: data,
      backgroundPath: _ios ? _backgroundPath : null,
    );
  }

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
