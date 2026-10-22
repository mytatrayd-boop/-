import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/main.dart';
import 'dart:async';

import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/app/places.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:lamha/src/app/services.dart';
import 'package:lamha/src/engine/weather.dart';
import 'package:lamha/src/engine/widget_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

class FakeBridge implements WidgetBridge {
  final saved = <String>[];
  var updates = 0;

  Map<String, dynamic> get last => jsonDecode(saved.last) as Map<String, dynamic>;

  @override
  Future<void> saveSchedule(String json) async => saved.add(json);

  @override
  Future<void> requestUpdate() async => updates++;
}

class FakeLocation implements LocationService {
  FakeLocation(this.result);

  final ({double latitude, double longitude})? result;

  @override
  Future<({double latitude, double longitude})?> currentPosition() async =>
      result;
}

/// حاوية App Group وهمية: تحفظ اسم الملف ولا تلمس القرص.
class FakeBackgroundStore implements BackgroundStore {
  FakeBackgroundStore([this.picked = 'wallpaper.jpg', this.error]);

  final String? picked;
  final Object? error;
  var picks = 0;

  @override
  Future<String?> pickAndSave() async {
    picks++;
    if (error != null) throw error!;
    return picked;
  }

  @override
  Future<String?> resolve(String fileName) async => null;
}

/// geocoding وهمي: اسم ثابت أو خطأ (لا إنترنت).
class FakeGeocoder implements PlaceGeocoder {
  FakeGeocoder({this.name, this.results = const [], this.error});

  final String? name;
  final List<Place> results;
  final Object? error;
  final queries = <String>[];

  @override
  Future<String?> placeName(double latitude, double longitude) async {
    if (error != null) throw error!;
    return name;
  }

  @override
  Future<List<Place>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }
}

/// حساس بوصلة وهمي: [controller] يرسل القراءات، و[available] = false بلا حساس.
class FakeCompass implements CompassSource {
  FakeCompass({this.available = true});

  final bool available;
  final controller = StreamController<CompassReading>.broadcast();

  @override
  Stream<CompassReading>? readings() => available ? controller.stream : null;
}

/// فتح التطبيق من الودجت (وهمي).
class FakeLaunch implements WidgetLaunch {
  FakeLaunch([this.initialUri]);

  final Uri? initialUri;
  final controller = StreamController<Uri?>.broadcast();

  @override
  Future<Uri?> initial() async => initialUri;

  @override
  Stream<Uri?> get clicks => controller.stream;
}

/// طقس وهمي: قراءة ثابتة لأي مكان، أو خطأ (لا إنترنت).
class FakeWeather implements WeatherService {
  FakeWeather({this.temp = 31, this.code = 0, this.error, DateTime? at})
      : at = at ?? testNow;

  final double temp;
  final int code;
  final Object? error;
  final DateTime at;
  final calls = <({double latitude, double longitude})>[];

  @override
  Future<WeatherReading> current(double latitude, double longitude) async {
    calls.add((latitude: latitude, longitude: longitude));
    if (error != null) throw error!;
    return WeatherReading(
        temp: temp, code: code, fetchedAt: at, latitude: latitude, longitude: longitude);
  }
}

class FakeSystemColors implements SystemColorsSource {
  FakeSystemColors([this.colors]);

  final SystemColors? colors;

  @override
  Future<SystemColors?> read() async => colors;
}

class FakeVibration implements Vibration {
  var pulses = 0;

  @override
  Future<void> alignedPulse() async => pulses++;
}

class FakePermission implements NotificationPermission {
  FakePermission([this.granted = true]);

  final bool granted;
  var requests = 0;

  @override
  Future<bool> request() async {
    requests++;
    return granted;
  }
}

final testNow = DateTime.utc(2026, 10, 19, 9);
final _data = loadEngineDataFromFiles();
final _cities = parseCities(readAsset('assets/cities.json'));

/// يشغّل التطبيق بطبقات وهمية ويعيد طبقة الودجت.
Future<FakeBridge> pumpApp(
  WidgetTester tester, {
  FakeBridge? bridge,
  LocationService? location,
  BackgroundStore? background,
  PlaceGeocoder? geocoder,
  CompassSource? compass,
  WidgetLaunch? launch,
  WeatherService? weather,
  SystemColorsSource? systemColors,
  NotificationPermission? permission,
  Vibration? vibration,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final b = bridge ?? FakeBridge();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      engineDataProvider.overrideWith((ref) async => _data),
      citiesProvider.overrideWith((ref) async => _cities),
      clockProvider.overrideWithValue(() => testNow),
      widgetBridgeProvider.overrideWithValue(b),
      locationServiceProvider.overrideWithValue(location ?? FakeLocation(null)),
      backgroundStoreProvider
          .overrideWithValue(background ?? FakeBackgroundStore()),
      placeGeocoderProvider.overrideWithValue(geocoder ?? FakeGeocoder()),
      compassSourceProvider.overrideWithValue(compass ?? FakeCompass()),
      widgetLaunchProvider.overrideWithValue(launch ?? FakeLaunch()),
      weatherServiceProvider
          .overrideWithValue(weather ?? FakeWeather(error: 'offline')),
      systemColorsProvider.overrideWithValue(systemColors ?? FakeSystemColors()),
      notificationPermissionProvider
          .overrideWithValue(permission ?? FakePermission()),
      vibrationProvider.overrideWithValue(vibration ?? FakeVibration()),
    ],
    child: const LamhaApp(),
  ));
  await tester.pumpAndSettle();
  return b;
}
