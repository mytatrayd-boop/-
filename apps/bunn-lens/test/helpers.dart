import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bunn_lens/app/app.dart';
import 'package:bunn_lens/app/locale_provider.dart';
import 'package:bunn_lens/data/db/app_database.dart';
import 'package:bunn_lens/data/providers.dart';
import 'package:bunn_lens/data/repositories/cafe_repository.dart';
import 'package:bunn_lens/data/repositories/scan_repository.dart';
import 'package:bunn_lens/features/cafes/cafes_providers.dart';
import 'package:bunn_lens/features/cafes/data/location_service.dart';
import 'package:bunn_lens/features/share/share_flow.dart';

/// مستودع على قاعدة بالذاكرة ومجلد صور مؤقت.
class TestRepo {
  TestRepo._(this.db, this.dir, this.repo);

  final AppDatabase db;
  final Directory dir;
  final DriftScanRepository repo;
  late final DriftCafeRepository cafes = DriftCafeRepository(db);

  static TestRepo create({DateTime Function()? clock}) {
    final db = AppDatabase(NativeDatabase.memory());
    final dir = Directory.systemTemp.createTempSync('bunn_scans_');
    return TestRepo._(db, dir, DriftScanRepository(db, imagesDir: dir, clock: clock));
  }

  Future<void> dispose() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

Widget buildTestApp(
  ScanRepository repository, {
  Locale locale = const Locale('ar'),
  CafeRepository? cafeRepository,
  LocationService? locationService,
  UrlOpener? urlOpener,
  ShareLauncher? shareLauncher,
}) =>
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _FixedLocale(locale)),
        scanRepositoryProvider.overrideWithValue(repository),
        if (cafeRepository != null) cafeRepositoryProvider.overrideWithValue(cafeRepository),
        if (locationService != null) locationServiceProvider.overrideWithValue(locationService),
        if (urlOpener != null) urlOpenerProvider.overrideWithValue(urlOpener),
        if (shareLauncher != null) shareLauncherProvider.overrideWithValue(shareLauncher),
      ],
      child: const BunnLensApp(),
    );

Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('ar'),
  ScanRepository? repository,
  CafeRepository? cafeRepository,
  LocationService? locationService,
  UrlOpener? urlOpener,
  ShareLauncher? shareLauncher,
}) async {
  final own = repository == null ? TestRepo.create() : null;
  if (own != null) addTearDown(own.dispose);
  await tester.pumpWidget(buildTestApp(repository ?? own!.repo,
      locale: locale,
      cafeRepository: cafeRepository ?? own?.cafes,
      locationService: locationService,
      urlOpener: urlOpener,
      shareLauncher: shareLauncher));
  await tester.pumpAndSettle();
}

/// يفكّ الشجرة ويترك مؤقتات تنظيف بث drift تنتهي (وإلا يشتكي إطار الاختبار).
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

class _FixedLocale extends LocaleNotifier {
  _FixedLocale(this._locale);
  final Locale _locale;
  @override
  Locale build() => _locale;
}

/// موقع وهمي للاختبارات.
class FakeLocationService implements LocationService {
  FakeLocationService(this.result);
  LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> getCurrentLocation({Duration timeout = const Duration(seconds: 10)}) async {
    calls++;
    return result;
  }
}
