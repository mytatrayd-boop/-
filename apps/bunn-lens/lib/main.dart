import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'app/app.dart';
import 'data/db/app_database.dart';
import 'data/db/connection.dart';
import 'data/providers.dart';
import 'data/repositories/cafe_repository.dart';
import 'data/repositories/scan_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final db = AppDatabase(openDeviceConnection());
  final repo = DriftScanRepository(
    db,
    imagesDir: Directory(p.join(docs.path, 'scan_images')),
  );
  runApp(ProviderScope(
    overrides: [
      scanRepositoryProvider.overrideWithValue(repo),
      cafeRepositoryProvider.overrideWithValue(DriftCafeRepository(db)),
    ],
    child: const BunnLensApp(),
  ));
}
