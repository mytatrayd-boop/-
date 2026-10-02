import 'package:flutter/services.dart';

import '../domain/tables.dart';
import 'tables_loader.dart';

/// يحمّل الجداول من أصول التطبيق المضمّنة (بلا إنترنت).
class TableRepository {
  TableRepository([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<Tables> load() =>
      TablesLoader((path) => _bundle.loadString(path, cache: false)).load();
}
