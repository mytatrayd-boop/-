import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// جدول `scans` وفق ARCHITECTURE §4 (حقول المكان تُضاف مع ميزتها بترحيل).
@DataClassName('ScanRow')
class Scans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // bean | coffee
  IntColumn get score => integer()();
  TextColumn get notes => text()(); // JSON لثلاث ملاحظات
  TextColumn get imagePath => text()(); // اسم الملف فقط داخل imagesDir
  TextColumn get roasterName => text().nullable()();
  RealColumn get price => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get promptVersion => text().nullable()();
  IntColumn get cafeId => integer().nullable().references(Cafes, #id)();
}

/// جدول `cafes` (ARCHITECTURE §4): الاسم إلزامي والإحداثيات اختيارية.
@DataClassName('CafeRow')
class Cafes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  DateTimeColumn get savedAt => dateTime()();
}

@DriftDatabase(tables: [Scans, Cafes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cafes);
            await m.addColumn(scans, scans.cafeId);
          }
        },
      );
}
