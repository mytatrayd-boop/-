import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/main.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:lamha/src/app/services.dart';
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

final testNow = DateTime.utc(2026, 10, 19, 9);
final _data = loadEngineDataFromFiles();
final _cities = parseCities(readAsset('assets/cities.json'));

/// يشغّل التطبيق بطبقات وهمية ويعيد طبقة الودجت.
Future<FakeBridge> pumpApp(
  WidgetTester tester, {
  FakeBridge? bridge,
  LocationService? location,
  BackgroundStore? background,
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
    ],
    child: const LamhaApp(),
  ));
  await tester.pumpAndSettle();
  return b;
}
