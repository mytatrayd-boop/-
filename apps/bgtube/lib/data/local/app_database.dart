import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// جدول `positions` (ARCHITECTURE: نموذج البيانات المحلي).
class Positions extends Table {
  TextColumn get videoId => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {videoId};
}

@DriftDatabase(tables: [Positions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
