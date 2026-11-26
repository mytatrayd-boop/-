import 'package:drift/drift.dart';

import 'app_database.steps.dart';

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

/// عناصر الطابور (v2، D27). لقطة كاملة تُكتب عند كل تغيير.
@DataClassName('QueueEntryRow')
class QueueEntries extends Table {
  IntColumn get key => integer()();
  IntColumn get ord => integer()();
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get thumbUrl => text().nullable()();
  BoolColumn get failed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// صف واحد (id = 0) بمفتاح الحالي. موضعه مصدره `positions` وحده.
@DataClassName('QueueStateRow')
class QueueState extends Table {
  // نمط drift الموثّق لقيد CHECK على العمود نفسه.
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(0))();
  IntColumn get currentKey => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// قوائم محلية مسمّاة (v2، D27). لا تُرسل إلى يوتيوب.
@DataClassName('LocalPlaylistRow')
class LocalPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('LocalPlaylistItemRow')
class LocalPlaylistItems extends Table {
  IntColumn get playlistId => integer().references(LocalPlaylists, #id, onDelete: KeyAction.cascade)();
  IntColumn get ord => integer()();
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get thumbUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, ord};
}

@DriftDatabase(tables: [Positions, QueueEntries, QueueState, LocalPlaylists, LocalPlaylistItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// v1: positions. v2: الطابور والقوائم المحلية (D27).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // خطوات مولَّدة من المخططات المصدَّرة في drift_schemas/ (make-migrations).
        onUpgrade: stepByStep(
          from1To2: (m, schema) async {
            await m.createTable(schema.queueEntries);
            await m.createTable(schema.queueState);
            await m.createTable(schema.localPlaylists);
            await m.createTable(schema.localPlaylistItems);
          },
        ),
        beforeOpen: (details) async {
          // ON DELETE CASCADE لعناصر القوائم يحتاجه.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
