// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CafesTable extends Cafes with TableInfo<$CafesTable, CafeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CafesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, lat, lng, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cafes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CafeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CafeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CafeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $CafesTable createAlias(String alias) {
    return $CafesTable(attachedDatabase, alias);
  }
}

class CafeRow extends DataClass implements Insertable<CafeRow> {
  final int id;
  final String name;
  final double? lat;
  final double? lng;
  final DateTime savedAt;
  const CafeRow({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  CafesCompanion toCompanion(bool nullToAbsent) {
    return CafesCompanion(
      id: Value(id),
      name: Value(name),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      savedAt: Value(savedAt),
    );
  }

  factory CafeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CafeRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  CafeRow copyWith({
    int? id,
    String? name,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    DateTime? savedAt,
  }) => CafeRow(
    id: id ?? this.id,
    name: name ?? this.name,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    savedAt: savedAt ?? this.savedAt,
  );
  CafeRow copyWithCompanion(CafesCompanion data) {
    return CafeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CafeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, lat, lng, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CafeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.savedAt == this.savedAt);
}

class CafesCompanion extends UpdateCompanion<CafeRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<DateTime> savedAt;
  const CafesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  CafesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    required DateTime savedAt,
  }) : name = Value(name),
       savedAt = Value(savedAt);
  static Insertable<CafeRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<DateTime>? savedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  CafesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<DateTime>? savedAt,
  }) {
    return CafesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CafesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _cafeIdMeta = const VerificationMeta('cafeId');
  @override
  late final GeneratedColumn<int> cafeId = GeneratedColumn<int>(
    'cafe_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cafes (id)',
    ),
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
    cafeId,
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
    if (data.containsKey('cafe_id')) {
      context.handle(
        _cafeIdMeta,
        cafeId.isAcceptableOrUnknown(data['cafe_id']!, _cafeIdMeta),
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
      cafeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cafe_id'],
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
  final int? cafeId;
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
    this.cafeId,
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
    if (!nullToAbsent || cafeId != null) {
      map['cafe_id'] = Variable<int>(cafeId);
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
      cafeId: cafeId == null && nullToAbsent
          ? const Value.absent()
          : Value(cafeId),
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
      cafeId: serializer.fromJson<int?>(json['cafeId']),
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
      'cafeId': serializer.toJson<int?>(cafeId),
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
    Value<int?> cafeId = const Value.absent(),
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
    cafeId: cafeId.present ? cafeId.value : this.cafeId,
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
      cafeId: data.cafeId.present ? data.cafeId.value : this.cafeId,
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
          ..write('promptVersion: $promptVersion, ')
          ..write('cafeId: $cafeId')
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
    cafeId,
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
          other.promptVersion == this.promptVersion &&
          other.cafeId == this.cafeId);
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
  final Value<int?> cafeId;
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
    this.cafeId = const Value.absent(),
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
    this.cafeId = const Value.absent(),
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
    Expression<int>? cafeId,
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
      if (cafeId != null) 'cafe_id': cafeId,
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
    Value<int?>? cafeId,
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
      cafeId: cafeId ?? this.cafeId,
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
    if (cafeId.present) {
      map['cafe_id'] = Variable<int>(cafeId.value);
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
          ..write('promptVersion: $promptVersion, ')
          ..write('cafeId: $cafeId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CafesTable cafes = $CafesTable(this);
  late final $ScansTable scans = $ScansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cafes, scans];
}

typedef $$CafesTableCreateCompanionBuilder = CafesCompanion Function({
  Value<int> id,
  required String name,
  Value<double?> lat,
  Value<double?> lng,
  required DateTime savedAt,
});
typedef $$CafesTableUpdateCompanionBuilder = CafesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<double?> lat,
  Value<double?> lng,
  Value<DateTime> savedAt,
});

final class $$CafesTableReferences
    extends BaseReferences<_$AppDatabase, $CafesTable, CafeRow> {
  $$CafesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ScansTable, List<ScanRow>> _scansRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scans,
    aliasName: 'cafes__id__scans__cafe_id',
  );

  $$ScansTableProcessedTableManager get scansRefs {
    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.cafeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CafesTableFilterComposer extends Composer<_$AppDatabase, $CafesTable> {
  $$CafesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> scansRefs(
    Expression<bool> Function($$ScansTableFilterComposer f) f,
  ) {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.cafeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CafesTableOrderingComposer
    extends Composer<_$AppDatabase, $CafesTable> {
  $$CafesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CafesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CafesTable> {
  $$CafesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  Expression<T> scansRefs<T extends Object>(
    Expression<T> Function($$ScansTableAnnotationComposer a) f,
  ) {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.cafeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CafesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CafesTable,
          CafeRow,
          $$CafesTableFilterComposer,
          $$CafesTableOrderingComposer,
          $$CafesTableAnnotationComposer,
          $$CafesTableCreateCompanionBuilder,
          $$CafesTableUpdateCompanionBuilder,
          (CafeRow, $$CafesTableReferences),
          CafeRow,
          PrefetchHooks Function({bool scansRefs})
        > {
  $$CafesTableTableManager(_$AppDatabase db, $CafesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CafesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CafesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CafesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
              }) => CafesCompanion(
                id: id,
                name: name,
                lat: lat,
                lng: lng,
                savedAt: savedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                required DateTime savedAt,
              }) => CafesCompanion.insert(
                id: id,
                name: name,
                lat: lat,
                lng: lng,
                savedAt: savedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CafesTable, CafeRow>(table),
                  $$CafesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scansRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (scansRefs) db.scans],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scansRefs)
                    await $_getPrefetchedDataByColumns<
                      CafeRow,
                      $CafesTable,
                      ScanRow,
                      $ScansTable
                    >(
                      currentTable: table,
                      referencedTable: $$CafesTableReferences._scansRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$CafesTableReferences(db, table, p0).scansRefs,
                      currentColumn: 'id',
                      referencedColumn: 'cafe_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CafesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CafesTable,
      CafeRow,
      $$CafesTableFilterComposer,
      $$CafesTableOrderingComposer,
      $$CafesTableAnnotationComposer,
      $$CafesTableCreateCompanionBuilder,
      $$CafesTableUpdateCompanionBuilder,
      (CafeRow, $$CafesTableReferences),
      CafeRow,
      PrefetchHooks Function({bool scansRefs})
    >;
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
  Value<int?> cafeId,
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
  Value<int?> cafeId,
});

final class $$ScansTableReferences
    extends BaseReferences<_$AppDatabase, $ScansTable, ScanRow> {
  $$ScansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CafesTable _cafeIdTable(_$AppDatabase db) =>
      db.cafes.createAlias('scans__cafe_id__cafes__id');

  $$CafesTableProcessedTableManager? get cafeId {
    final $_column = $_itemColumn<int>('cafe_id');
    if ($_column == null) return null;
    final manager = $$CafesTableTableManager(
      $_db,
      $_db.cafes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cafeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  $$CafesTableFilterComposer get cafeId {
    final $$CafesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cafeId,
      referencedTable: $db.cafes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CafesTableFilterComposer(
            $db: $db,
            $table: $db.cafes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$CafesTableOrderingComposer get cafeId {
    final $$CafesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cafeId,
      referencedTable: $db.cafes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CafesTableOrderingComposer(
            $db: $db,
            $table: $db.cafes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$CafesTableAnnotationComposer get cafeId {
    final $$CafesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cafeId,
      referencedTable: $db.cafes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CafesTableAnnotationComposer(
            $db: $db,
            $table: $db.cafes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (ScanRow, $$ScansTableReferences),
          ScanRow,
          PrefetchHooks Function({bool cafeId})
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
                Value<int?> cafeId = const Value.absent(),
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
                cafeId: cafeId,
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
                Value<int?> cafeId = const Value.absent(),
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
                cafeId: cafeId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScansTable, ScanRow>(table),
                  $$ScansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cafeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cafeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cafeId,
                        referencedTable: $$ScansTableReferences._cafeIdTable(
                          db,
                        ),
                        referencedColumn: $$ScansTableReferences
                            ._cafeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
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
      (ScanRow, $$ScansTableReferences),
      ScanRow,
      PrefetchHooks Function({bool cafeId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CafesTableTableManager get cafes =>
      $$CafesTableTableManager(_db, _db.cafes);
  $$ScansTableTableManager get scans =>
      $$ScansTableTableManager(_db, _db.scans);
}
