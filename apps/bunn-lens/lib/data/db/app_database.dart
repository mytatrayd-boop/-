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
}

@DriftDatabase(tables: [Scans])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
