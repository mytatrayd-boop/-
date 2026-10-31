import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bunn_lens/app/app.dart';
import 'package:bunn_lens/app/locale_provider.dart';
import 'package:bunn_lens/data/db/app_database.dart';
import 'package:bunn_lens/data/providers.dart';
import 'package:bunn_lens/data/repositories/scan_repository.dart';

/// مستودع على قاعدة بالذاكرة ومجلد صور مؤقت.
class TestRepo {
  TestRepo._(this.db, this.dir, this.repo);

  final AppDatabase db;
  final Directory dir;
  final DriftScanRepository repo;

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

Widget buildTestApp(ScanRepository repository, {Locale locale = const Locale('ar')}) =>
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _FixedLocale(locale)),
        scanRepositoryProvider.overrideWithValue(repository),
      ],
      child: const BunnLensApp(),
    );

Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('ar'),
  ScanRepository? repository,
}) async {
  final own = repository == null ? TestRepo.create() : null;
  if (own != null) addTearDown(own.dispose);
  await tester.pumpWidget(buildTestApp(repository ?? own!.repo, locale: locale));
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
