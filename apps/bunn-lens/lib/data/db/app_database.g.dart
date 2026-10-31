// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ScansTable extends Scans with TableInfo<$ScansTable, ScanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roasterNameMeta = const VerificationMeta(
    'roasterName',
  );
  @override
  late final GeneratedColumn<String> roasterName = GeneratedColumn<String>(
    'roaster_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _promptVersionMeta = const VerificationMeta(
    'promptVersion',
  );
  @override
  late final GeneratedColumn<String> promptVersion = GeneratedColumn<String>(
    'prompt_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    score,
    notes,
    imagePath,
    roasterName,
    price,
    createdAt,
    isFavorite,
    promptVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('roaster_name')) {
      context.handle(
        _roasterNameMeta,
        roasterName.isAcceptableOrUnknown(
          data['roaster_name']!,
          _roasterNameMeta,
        ),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('prompt_version')) {
      context.handle(
        _promptVersionMeta,
        promptVersion.isAcceptableOrUnknown(
          data['prompt_version']!,
          _promptVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      roasterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roaster_name'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      promptVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_version'],
      ),
    );
  }

  @override
  $ScansTable createAlias(String alias) {
    return $ScansTable(attachedDatabase, alias);
  }
}

class ScanRow extends DataClass implements Insertable<ScanRow> {
  final int id;
  final String type;
  final int score;
  final String notes;
  final String imagePath;
  final String? roasterName;
  final double? price;
  final DateTime createdAt;
  final bool isFavorite;
  final String? promptVersion;
  const ScanRow({
    required this.id,
    required this.type,
    required this.score,
    required this.notes,
    required this.imagePath,
    this.roasterName,
    this.price,
    required this.createdAt,
    required this.isFavorite,
    this.promptVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['score'] = Variable<int>(score);
    map['notes'] = Variable<String>(notes);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || roasterName != null) {
      map['roaster_name'] = Variable<String>(roasterName);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<double>(price);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || promptVersion != null) {
      map['prompt_version'] = Variable<String>(promptVersion);
    }
    return map;
  }

  ScansCompanion toCompanion(bool nullToAbsent) {
    return ScansCompanion(
      id: Value(id),
      type: Value(type),
      score: Value(score),
      notes: Value(notes),
      imagePath: Value(imagePath),
      roasterName: roasterName == null && nullToAbsent
          ? const Value.absent()
          : Value(roasterName),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      createdAt: Value(createdAt),
      isFavorite: Value(isFavorite),
      promptVersion: promptVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(promptVersion),
    );
  }

  factory ScanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanRow(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      score: serializer.fromJson<int>(json['score']),
      notes: serializer.fromJson<String>(json['notes']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      roasterName: serializer.fromJson<String?>(json['roasterName']),
      price: serializer.fromJson<double?>(json['price']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      promptVersion: serializer.fromJson<String?>(json['promptVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'score': serializer.toJson<int>(score),
      'notes': serializer.toJson<String>(notes),
      'imagePath': serializer.toJson<String>(imagePath),
      'roasterName': serializer.toJson<String?>(roasterName),
      'price': serializer.toJson<double?>(price),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'promptVersion': serializer.toJson<String?>(promptVersion),
    };
  }

  ScanRow copyWith({
    int? id,
    String? type,
    int? score,
    String? notes,
    String? imagePath,
    Value<String?> roasterName = const Value.absent(),
    Value<double?> price = const Value.absent(),
    DateTime? createdAt,
    bool? isFavorite,
    Value<String?> promptVersion = const Value.absent(),
  }) => ScanRow(
    id: id ?? this.id,
    type: type ?? this.type,
    score: score ?? this.score,
    notes: notes ?? this.notes,
    imagePath: imagePath ?? this.imagePath,
    roasterName: roasterName.present ? roasterName.value : this.roasterName,
    price: price.present ? price.value : this.price,
    createdAt: createdAt ?? this.createdAt,
    isFavorite: isFavorite ?? this.isFavorite,
    promptVersion: promptVersion.present
        ? promptVersion.value
        : this.promptVersion,
  );
  ScanRow copyWithCompanion(ScansCompanion data) {
    return ScanRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      score: data.score.present ? data.score.value : this.score,
      notes: data.notes.present ? data.notes.value : this.notes,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      roasterName: data.roasterName.present
          ? data.roasterName.value
          : this.roasterName,
      price: data.price.present ? data.price.value : this.price,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      promptVersion: data.promptVersion.present
          ? data.promptVersion.value
          : this.promptVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('score: $score, ')
          ..write('notes: $notes, ')
          ..write('imagePath: $imagePath, ')
          ..write('roasterName: $roasterName, ')
          ..write('price: $price, ')
          ..write('createdAt: $createdAt, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('promptVersion: $promptVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    score,
    notes,
    imagePath,
    roasterName,
    price,
    createdAt,
    isFavorite,
    promptVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.score == this.score &&
          other.notes == this.notes &&
          other.imagePath == this.imagePath &&
          other.roasterName == this.roasterName &&
          other.price == this.price &&
          other.createdAt == this.createdAt &&
          other.isFavorite == this.isFavorite &&
          other.promptVersion == this.promptVersion);
}

class ScansCompanion extends UpdateCompanion<ScanRow> {
  final Value<int> id;
  final Value<String> type;
  final Value<int> score;
  final Value<String> notes;
  final Value<String> imagePath;
  final Value<String?> roasterName;
  final Value<double?> price;
  final Value<DateTime> createdAt;
  final Value<bool> isFavorite;
  final Value<String?> promptVersion;
  const ScansCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.score = const Value.absent(),
    this.notes = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.roasterName = const Value.absent(),
    this.price = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.promptVersion = const Value.absent(),
  });
  ScansCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required int score,
    required String notes,
    required String imagePath,
    this.roasterName = const Value.absent(),
    this.price = const Value.absent(),
    required DateTime createdAt,
    this.isFavorite = const Value.absent(),
    this.promptVersion = const Value.absent(),
  }) : type = Value(type),
       score = Value(score),
       notes = Value(notes),
       imagePath = Value(imagePath),
       createdAt = Value(createdAt);
  static Insertable<ScanRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<int>? score,
    Expression<String>? notes,
    Expression<String>? imagePath,
    Expression<String>? roasterName,
    Expression<double>? price,
    Expression<DateTime>? createdAt,
    Expression<bool>? isFavorite,
    Expression<String>? promptVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (score != null) 'score': score,
      if (notes != null) 'notes': notes,
      if (imagePath != null) 'image_path': imagePath,
      if (roasterName != null) 'roaster_name': roasterName,
      if (price != null) 'price': price,
      if (createdAt != null) 'created_at': createdAt,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (promptVersion != null) 'prompt_version': promptVersion,
    });
  }

  ScansCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<int>? score,
    Value<String>? notes,
    Value<String>? imagePath,
    Value<String?>? roasterName,
    Value<double?>? price,
    Value<DateTime>? createdAt,
    Value<bool>? isFavorite,
    Value<String?>? promptVersion,
  }) {
    return ScansCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      score: score ?? this.score,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      roasterName: roasterName ?? this.roasterName,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      promptVersion: promptVersion ?? this.promptVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (roasterName.present) {
      map['roaster_name'] = Variable<String>(roasterName.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (promptVersion.present) {
      map['prompt_version'] = Variable<String>(promptVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScansCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('score: $score, ')
          ..write('notes: $notes, ')
          ..write('imagePath: $imagePath, ')
          ..write('roasterName: $roasterName, ')
          ..write('price: $price, ')
          ..write('createdAt: $createdAt, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('promptVersion: $promptVersion')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScansTable scans = $ScansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scans];
}

typedef $$ScansTableCreateCompanionBuilder = ScansCompanion Function({
  Value<int> id,
  required String type,
  required int score,
  required String notes,
  required String imagePath,
  Value<String?> roasterName,
  Value<double?> price,
  required DateTime createdAt,
  Value<bool> isFavorite,
  Value<String?> promptVersion,
});
typedef $$ScansTableUpdateCompanionBuilder = ScansCompanion Function({
  Value<int> id,
  Value<String> type,
  Value<int> score,
  Value<String> notes,
  Value<String> imagePath,
  Value<String?> roasterName,
  Value<double?> price,
  Value<DateTime> createdAt,
  Value<bool> isFavorite,
  Value<String?> promptVersion,
});

class $$ScansTableFilterComposer extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roasterName => $composableBuilder(
    column: $table.roasterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScansTableOrderingComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roasterName => $composableBuilder(
    column: $table.roasterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get roasterName => $composableBuilder(
    column: $table.roasterName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => column,
  );
}

class $$ScansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScansTable,
          ScanRow,
          $$ScansTableFilterComposer,
          $$ScansTableOrderingComposer,
          $$ScansTableAnnotationComposer,
          $$ScansTableCreateCompanionBuilder,
          $$ScansTableUpdateCompanionBuilder,
          (ScanRow, BaseReferences<_$AppDatabase, $ScansTable, ScanRow>),
          ScanRow,
          PrefetchHooks Function()
        > {
  $$ScansTableTableManager(_$AppDatabase db, $ScansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> roasterName = const Value.absent(),
                Value<double?> price = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> promptVersion = const Value.absent(),
              }) => ScansCompanion(
                id: id,
                type: type,
                score: score,
                notes: notes,
                imagePath: imagePath,
                roasterName: roasterName,
                price: price,
                createdAt: createdAt,
                isFavorite: isFavorite,
                promptVersion: promptVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required int score,
                required String notes,
                required String imagePath,
                Value<String?> roasterName = const Value.absent(),
                Value<double?> price = const Value.absent(),
                required DateTime createdAt,
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> promptVersion = const Value.absent(),
              }) => ScansCompanion.insert(
                id: id,
                type: type,
                score: score,
                notes: notes,
                imagePath: imagePath,
                roasterName: roasterName,
                price: price,
                createdAt: createdAt,
                isFavorite: isFavorite,
                promptVersion: promptVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScansTable, ScanRow>(table),
                  BaseReferences<_$AppDatabase, $ScansTable, ScanRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScansTable,
      ScanRow,
      $$ScansTableFilterComposer,
      $$ScansTableOrderingComposer,
      $$ScansTableAnnotationComposer,
      $$ScansTableCreateCompanionBuilder,
      $$ScansTableUpdateCompanionBuilder,
      (ScanRow, BaseReferences<_$AppDatabase, $ScansTable, ScanRow>),
      ScanRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScansTableTableManager get scans =>
      $$ScansTableTableManager(_db, _db.scans);
}
