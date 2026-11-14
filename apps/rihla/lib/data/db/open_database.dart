import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// يفتح قاعدة البيانات على القرص (مجلد مستندات التطبيق).
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'rihla.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
