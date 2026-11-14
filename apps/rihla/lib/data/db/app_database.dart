import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// حالة الرحلة المخزَّنة كنص (ARCHITECTURE 5).
enum TripStatus { recording, completed, interrupted }

@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  TextColumn get videoAssetId => text().nullable()();
  TextColumn get videoPath => text().nullable()();
  IntColumn get quality => integer().withDefault(const Constant(720))();
  TextColumn get status => textEnum<TripStatus>()();
  TextColumn get title => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TrackPointRow')
@TableIndex(
  name: 'track_points_trip_seq',
  columns: {#tripId, #seq},
  unique: true,
)
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  DateTimeColumn get ts => dateTime()();
  RealColumn get accuracyM => real().nullable()();
  RealColumn get speedMps => real().nullable()();
}

@DriftDatabase(tables: [Trips, TrackPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// رفع الرقم عند أي تغيير في الجداول وإضافة خطوة في [onUpgrade].
  static const int version = 1;

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // لا ترحيلات بعد: الإصدار 1 هو الأول. كل إصدار جديد يضيف
      // `if (from < N) { ... }` هنا ويُختبر في test/data/db_test.dart.
    },
    beforeOpen: (details) async {
      // SQLite يعطّل المفاتيح الأجنبية افتراضياً؛ مطلوب لـON DELETE CASCADE.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
