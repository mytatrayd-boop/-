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

/// ردود YouTube Data API (v3، D29). المفتاح = الطلب المطبَّع بلا رموز.
@DataClassName('ApiCacheRow')
class ApiCache extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  IntColumn get ttlSec => integer()();

  /// بيانات الحساب المباشرة (mine/البحث). للعلم فقط: الخروج يمسح الجدول كله (D29).
  BoolColumn get private => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// الوحدات المقدّرة لكل يوم بتوقيت المحيط الهادئ ولكل وعاء حصة (v3، D29).
@DataClassName('QuotaRow')
class Quota extends Table {
  TextColumn get dayPt => text()();

  /// `general` (10,000 وحدة) أو `search` (100 طلب).
  TextColumn get bucket => text()();
  IntColumn get units => integer()();

  @override
  Set<Column<Object>> get primaryKey => {dayPt, bucket};
}

/// المفضلة المحلية (v4، الميزة 5، D5/D30). لا تُرسل إلى يوتيوب ولا تُمسح عند الخروج.
@DataClassName('FavoriteRow')
class Favorites extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get thumbUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {videoId};
}

/// سجل التشغيل داخل التطبيق (v4، الميزة 5، D5/D30): صف لكل مقطع، بحد 500.
@DataClassName('HistoryRow')
class History extends Table {
  @override
  String get tableName => 'history';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text().unique()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get thumbUrl => text().nullable()();
  DateTimeColumn get playedAt => dateTime()();
}

@DriftDatabase(
  tables: [Positions, QueueEntries, QueueState, LocalPlaylists, LocalPlaylistItems, ApiCache, Quota, Favorites, History],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// v1: positions. v2: الطابور والقوائم المحلية (D27). v3: كاش الواجهة والحصة (D29).
  /// v4: المفضلة والسجل (D30).
  @override
  int get schemaVersion => 4;

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
          from2To3: (m, schema) async {
            await m.createTable(schema.apiCache);
            await m.createTable(schema.quota);
          },
          from3To4: (m, schema) async {
            await m.createTable(schema.favorites);
            await m.createTable(schema.history);
          },
        ),
        beforeOpen: (details) async {
          // ON DELETE CASCADE لعناصر القوائم يحتاجه.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
