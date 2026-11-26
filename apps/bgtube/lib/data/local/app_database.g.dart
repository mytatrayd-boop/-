// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PositionsTable extends Positions
    with TableInfo<$PositionsTable, Position> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    videoId,
    positionMs,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Position> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  Position map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Position(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PositionsTable createAlias(String alias) {
    return $PositionsTable(attachedDatabase, alias);
  }
}

class Position extends DataClass implements Insertable<Position> {
  final String videoId;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
  const Position({
    required this.videoId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PositionsCompanion toCompanion(bool nullToAbsent) {
    return PositionsCompanion(
      videoId: Value(videoId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory Position.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Position(
      videoId: serializer.fromJson<String>(json['videoId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Position copyWith({
    String? videoId,
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
  }) => Position(
    videoId: videoId ?? this.videoId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Position copyWithCompanion(PositionsCompanion data) {
    return Position(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Position(')
          ..write('videoId: $videoId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, positionMs, durationMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Position &&
          other.videoId == this.videoId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class PositionsCompanion extends UpdateCompanion<Position> {
  final Value<String> videoId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PositionsCompanion({
    this.videoId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PositionsCompanion.insert({
    required String videoId,
    required int positionMs,
    required int durationMs,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       updatedAt = Value(updatedAt);
  static Insertable<Position> custom({
    Expression<String>? videoId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PositionsCompanion copyWith({
    Value<String>? videoId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PositionsCompanion(
      videoId: videoId ?? this.videoId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PositionsCompanion(')
          ..write('videoId: $videoId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueEntriesTable extends QueueEntries
    with TableInfo<$QueueEntriesTable, QueueEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<int> key = GeneratedColumn<int>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<bool> failed = GeneratedColumn<bool>(
    'failed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("failed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    ord,
    videoId,
    title,
    author,
    durationMs,
    thumbUrl,
    failed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('failed')) {
      context.handle(
        _failedMeta,
        failed.isAcceptableOrUnknown(data['failed']!, _failedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  QueueEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueEntryRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      failed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}failed'],
      )!,
    );
  }

  @override
  $QueueEntriesTable createAlias(String alias) {
    return $QueueEntriesTable(attachedDatabase, alias);
  }
}

class QueueEntryRow extends DataClass implements Insertable<QueueEntryRow> {
  final int key;
  final int ord;
  final String videoId;
  final String? title;
  final String? author;
  final int? durationMs;
  final String? thumbUrl;
  final bool failed;
  const QueueEntryRow({
    required this.key,
    required this.ord,
    required this.videoId,
    this.title,
    this.author,
    this.durationMs,
    this.thumbUrl,
    required this.failed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<int>(key);
    map['ord'] = Variable<int>(ord);
    map['video_id'] = Variable<String>(videoId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['failed'] = Variable<bool>(failed);
    return map;
  }

  QueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return QueueEntriesCompanion(
      key: Value(key),
      ord: Value(ord),
      videoId: Value(videoId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      failed: Value(failed),
    );
  }

  factory QueueEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueEntryRow(
      key: serializer.fromJson<int>(json['key']),
      ord: serializer.fromJson<int>(json['ord']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      failed: serializer.fromJson<bool>(json['failed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<int>(key),
      'ord': serializer.toJson<int>(ord),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'durationMs': serializer.toJson<int?>(durationMs),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'failed': serializer.toJson<bool>(failed),
    };
  }

  QueueEntryRow copyWith({
    int? key,
    int? ord,
    String? videoId,
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> thumbUrl = const Value.absent(),
    bool? failed,
  }) => QueueEntryRow(
    key: key ?? this.key,
    ord: ord ?? this.ord,
    videoId: videoId ?? this.videoId,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    failed: failed ?? this.failed,
  );
  QueueEntryRow copyWithCompanion(QueueEntriesCompanion data) {
    return QueueEntryRow(
      key: data.key.present ? data.key.value : this.key,
      ord: data.ord.present ? data.ord.value : this.ord,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      failed: data.failed.present ? data.failed.value : this.failed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntryRow(')
          ..write('key: $key, ')
          ..write('ord: $ord, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('durationMs: $durationMs, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('failed: $failed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    ord,
    videoId,
    title,
    author,
    durationMs,
    thumbUrl,
    failed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueEntryRow &&
          other.key == this.key &&
          other.ord == this.ord &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.author == this.author &&
          other.durationMs == this.durationMs &&
          other.thumbUrl == this.thumbUrl &&
          other.failed == this.failed);
}

class QueueEntriesCompanion extends UpdateCompanion<QueueEntryRow> {
  final Value<int> key;
  final Value<int> ord;
  final Value<String> videoId;
  final Value<String?> title;
  final Value<String?> author;
  final Value<int?> durationMs;
  final Value<String?> thumbUrl;
  final Value<bool> failed;
  const QueueEntriesCompanion({
    this.key = const Value.absent(),
    this.ord = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.failed = const Value.absent(),
  });
  QueueEntriesCompanion.insert({
    this.key = const Value.absent(),
    required int ord,
    required String videoId,
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.failed = const Value.absent(),
  }) : ord = Value(ord),
       videoId = Value(videoId);
  static Insertable<QueueEntryRow> custom({
    Expression<int>? key,
    Expression<int>? ord,
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<int>? durationMs,
    Expression<String>? thumbUrl,
    Expression<bool>? failed,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (ord != null) 'ord': ord,
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (durationMs != null) 'duration_ms': durationMs,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (failed != null) 'failed': failed,
    });
  }

  QueueEntriesCompanion copyWith({
    Value<int>? key,
    Value<int>? ord,
    Value<String>? videoId,
    Value<String?>? title,
    Value<String?>? author,
    Value<int?>? durationMs,
    Value<String?>? thumbUrl,
    Value<bool>? failed,
  }) {
    return QueueEntriesCompanion(
      key: key ?? this.key,
      ord: ord ?? this.ord,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      durationMs: durationMs ?? this.durationMs,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      failed: failed ?? this.failed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<int>(key.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (failed.present) {
      map['failed'] = Variable<bool>(failed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntriesCompanion(')
          ..write('key: $key, ')
          ..write('ord: $ord, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('durationMs: $durationMs, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('failed: $failed')
          ..write(')'))
        .toString();
  }
}

class $QueueStateTable extends QueueState
    with TableInfo<$QueueStateTable, QueueStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentKeyMeta = const VerificationMeta(
    'currentKey',
  );
  @override
  late final GeneratedColumn<int> currentKey = GeneratedColumn<int>(
    'current_key',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, currentKey, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_key')) {
      context.handle(
        _currentKeyMeta,
        currentKey.isAcceptableOrUnknown(data['current_key']!, _currentKeyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueueStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_key'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $QueueStateTable createAlias(String alias) {
    return $QueueStateTable(attachedDatabase, alias);
  }
}

class QueueStateRow extends DataClass implements Insertable<QueueStateRow> {
  final int id;
  final int? currentKey;
  final DateTime updatedAt;
  const QueueStateRow({
    required this.id,
    this.currentKey,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || currentKey != null) {
      map['current_key'] = Variable<int>(currentKey);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  QueueStateCompanion toCompanion(bool nullToAbsent) {
    return QueueStateCompanion(
      id: Value(id),
      currentKey: currentKey == null && nullToAbsent
          ? const Value.absent()
          : Value(currentKey),
      updatedAt: Value(updatedAt),
    );
  }

  factory QueueStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueStateRow(
      id: serializer.fromJson<int>(json['id']),
      currentKey: serializer.fromJson<int?>(json['currentKey']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentKey': serializer.toJson<int?>(currentKey),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  QueueStateRow copyWith({
    int? id,
    Value<int?> currentKey = const Value.absent(),
    DateTime? updatedAt,
  }) => QueueStateRow(
    id: id ?? this.id,
    currentKey: currentKey.present ? currentKey.value : this.currentKey,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  QueueStateRow copyWithCompanion(QueueStateCompanion data) {
    return QueueStateRow(
      id: data.id.present ? data.id.value : this.id,
      currentKey: data.currentKey.present
          ? data.currentKey.value
          : this.currentKey,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueStateRow(')
          ..write('id: $id, ')
          ..write('currentKey: $currentKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, currentKey, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueStateRow &&
          other.id == this.id &&
          other.currentKey == this.currentKey &&
          other.updatedAt == this.updatedAt);
}

class QueueStateCompanion extends UpdateCompanion<QueueStateRow> {
  final Value<int> id;
  final Value<int?> currentKey;
  final Value<DateTime> updatedAt;
  const QueueStateCompanion({
    this.id = const Value.absent(),
    this.currentKey = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  QueueStateCompanion.insert({
    this.id = const Value.absent(),
    this.currentKey = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<QueueStateRow> custom({
    Expression<int>? id,
    Expression<int>? currentKey,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentKey != null) 'current_key': currentKey,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  QueueStateCompanion copyWith({
    Value<int>? id,
    Value<int?>? currentKey,
    Value<DateTime>? updatedAt,
  }) {
    return QueueStateCompanion(
      id: id ?? this.id,
      currentKey: currentKey ?? this.currentKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentKey.present) {
      map['current_key'] = Variable<int>(currentKey.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueStateCompanion(')
          ..write('id: $id, ')
          ..write('currentKey: $currentKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaylistsTable extends LocalPlaylists
    with TableInfo<$LocalPlaylistsTable, LocalPlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaylistsTable(this.attachedDatabase, [this._alias]);
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
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPlaylistRow> instance, {
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalPlaylistsTable createAlias(String alias) {
    return $LocalPlaylistsTable(attachedDatabase, alias);
  }
}

class LocalPlaylistRow extends DataClass
    implements Insertable<LocalPlaylistRow> {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalPlaylistRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPlaylistRow copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalPlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalPlaylistRow copyWithCompanion(LocalPlaylistsCompanion data) {
    return LocalPlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalPlaylistsCompanion extends UpdateCompanion<LocalPlaylistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LocalPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalPlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalPlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalPlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LocalPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaylistItemsTable extends LocalPlaylistItems
    with TableInfo<$LocalPlaylistItemsTable, LocalPlaylistItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    ord,
    videoId,
    title,
    author,
    durationMs,
    thumbUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPlaylistItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, ord};
  @override
  LocalPlaylistItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaylistItemRow(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
    );
  }

  @override
  $LocalPlaylistItemsTable createAlias(String alias) {
    return $LocalPlaylistItemsTable(attachedDatabase, alias);
  }
}

class LocalPlaylistItemRow extends DataClass
    implements Insertable<LocalPlaylistItemRow> {
  final int playlistId;
  final int ord;
  final String videoId;
  final String? title;
  final String? author;
  final int? durationMs;
  final String? thumbUrl;
  const LocalPlaylistItemRow({
    required this.playlistId,
    required this.ord,
    required this.videoId,
    this.title,
    this.author,
    this.durationMs,
    this.thumbUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['ord'] = Variable<int>(ord);
    map['video_id'] = Variable<String>(videoId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    return map;
  }

  LocalPlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaylistItemsCompanion(
      playlistId: Value(playlistId),
      ord: Value(ord),
      videoId: Value(videoId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
    );
  }

  factory LocalPlaylistItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaylistItemRow(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      ord: serializer.fromJson<int>(json['ord']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'ord': serializer.toJson<int>(ord),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'durationMs': serializer.toJson<int?>(durationMs),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
    };
  }

  LocalPlaylistItemRow copyWith({
    int? playlistId,
    int? ord,
    String? videoId,
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> thumbUrl = const Value.absent(),
  }) => LocalPlaylistItemRow(
    playlistId: playlistId ?? this.playlistId,
    ord: ord ?? this.ord,
    videoId: videoId ?? this.videoId,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
  );
  LocalPlaylistItemRow copyWithCompanion(LocalPlaylistItemsCompanion data) {
    return LocalPlaylistItemRow(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      ord: data.ord.present ? data.ord.value : this.ord,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistItemRow(')
          ..write('playlistId: $playlistId, ')
          ..write('ord: $ord, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('durationMs: $durationMs, ')
          ..write('thumbUrl: $thumbUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playlistId,
    ord,
    videoId,
    title,
    author,
    durationMs,
    thumbUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaylistItemRow &&
          other.playlistId == this.playlistId &&
          other.ord == this.ord &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.author == this.author &&
          other.durationMs == this.durationMs &&
          other.thumbUrl == this.thumbUrl);
}

class LocalPlaylistItemsCompanion
    extends UpdateCompanion<LocalPlaylistItemRow> {
  final Value<int> playlistId;
  final Value<int> ord;
  final Value<String> videoId;
  final Value<String?> title;
  final Value<String?> author;
  final Value<int?> durationMs;
  final Value<String?> thumbUrl;
  final Value<int> rowid;
  const LocalPlaylistItemsCompanion({
    this.playlistId = const Value.absent(),
    this.ord = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlaylistItemsCompanion.insert({
    required int playlistId,
    required int ord,
    required String videoId,
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       ord = Value(ord),
       videoId = Value(videoId);
  static Insertable<LocalPlaylistItemRow> custom({
    Expression<int>? playlistId,
    Expression<int>? ord,
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<int>? durationMs,
    Expression<String>? thumbUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (ord != null) 'ord': ord,
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (durationMs != null) 'duration_ms': durationMs,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlaylistItemsCompanion copyWith({
    Value<int>? playlistId,
    Value<int>? ord,
    Value<String>? videoId,
    Value<String?>? title,
    Value<String?>? author,
    Value<int?>? durationMs,
    Value<String?>? thumbUrl,
    Value<int>? rowid,
  }) {
    return LocalPlaylistItemsCompanion(
      playlistId: playlistId ?? this.playlistId,
      ord: ord ?? this.ord,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      durationMs: durationMs ?? this.durationMs,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistItemsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('ord: $ord, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('durationMs: $durationMs, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ApiCacheTable extends ApiCache
    with TableInfo<$ApiCacheTable, ApiCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApiCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ttlSecMeta = const VerificationMeta('ttlSec');
  @override
  late final GeneratedColumn<int> ttlSec = GeneratedColumn<int>(
    'ttl_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _privateMeta = const VerificationMeta(
    'private',
  );
  @override
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
    'private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, fetchedAt, ttlSec, private];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'api_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ApiCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('ttl_sec')) {
      context.handle(
        _ttlSecMeta,
        ttlSec.isAcceptableOrUnknown(data['ttl_sec']!, _ttlSecMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlSecMeta);
    }
    if (data.containsKey('private')) {
      context.handle(
        _privateMeta,
        private.isAcceptableOrUnknown(data['private']!, _privateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ApiCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApiCacheRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      ttlSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ttl_sec'],
      )!,
      private: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}private'],
      )!,
    );
  }

  @override
  $ApiCacheTable createAlias(String alias) {
    return $ApiCacheTable(attachedDatabase, alias);
  }
}

class ApiCacheRow extends DataClass implements Insertable<ApiCacheRow> {
  final String key;
  final String json;
  final DateTime fetchedAt;
  final int ttlSec;

  /// بيانات الحساب: تُمسح عند تسجيل الخروج.
  final bool private;
  const ApiCacheRow({
    required this.key,
    required this.json,
    required this.fetchedAt,
    required this.ttlSec,
    required this.private,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['ttl_sec'] = Variable<int>(ttlSec);
    map['private'] = Variable<bool>(private);
    return map;
  }

  ApiCacheCompanion toCompanion(bool nullToAbsent) {
    return ApiCacheCompanion(
      key: Value(key),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
      ttlSec: Value(ttlSec),
      private: Value(private),
    );
  }

  factory ApiCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApiCacheRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      ttlSec: serializer.fromJson<int>(json['ttlSec']),
      private: serializer.fromJson<bool>(json['private']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'ttlSec': serializer.toJson<int>(ttlSec),
      'private': serializer.toJson<bool>(private),
    };
  }

  ApiCacheRow copyWith({
    String? key,
    String? json,
    DateTime? fetchedAt,
    int? ttlSec,
    bool? private,
  }) => ApiCacheRow(
    key: key ?? this.key,
    json: json ?? this.json,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    ttlSec: ttlSec ?? this.ttlSec,
    private: private ?? this.private,
  );
  ApiCacheRow copyWithCompanion(ApiCacheCompanion data) {
    return ApiCacheRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      ttlSec: data.ttlSec.present ? data.ttlSec.value : this.ttlSec,
      private: data.private.present ? data.private.value : this.private,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApiCacheRow(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('ttlSec: $ttlSec, ')
          ..write('private: $private')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, fetchedAt, ttlSec, private);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiCacheRow &&
          other.key == this.key &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt &&
          other.ttlSec == this.ttlSec &&
          other.private == this.private);
}

class ApiCacheCompanion extends UpdateCompanion<ApiCacheRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> ttlSec;
  final Value<bool> private;
  final Value<int> rowid;
  const ApiCacheCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.ttlSec = const Value.absent(),
    this.private = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ApiCacheCompanion.insert({
    required String key,
    required String json,
    required DateTime fetchedAt,
    required int ttlSec,
    this.private = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       fetchedAt = Value(fetchedAt),
       ttlSec = Value(ttlSec);
  static Insertable<ApiCacheRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? ttlSec,
    Expression<bool>? private,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (ttlSec != null) 'ttl_sec': ttlSec,
      if (private != null) 'private': private,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ApiCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? fetchedAt,
    Value<int>? ttlSec,
    Value<bool>? private,
    Value<int>? rowid,
  }) {
    return ApiCacheCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      ttlSec: ttlSec ?? this.ttlSec,
      private: private ?? this.private,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (ttlSec.present) {
      map['ttl_sec'] = Variable<int>(ttlSec.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApiCacheCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('ttlSec: $ttlSec, ')
          ..write('private: $private, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuotaTable extends Quota with TableInfo<$QuotaTable, QuotaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuotaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayPtMeta = const VerificationMeta('dayPt');
  @override
  late final GeneratedColumn<String> dayPt = GeneratedColumn<String>(
    'day_pt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<int> units = GeneratedColumn<int>(
    'units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [dayPt, units];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quota';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuotaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_pt')) {
      context.handle(
        _dayPtMeta,
        dayPt.isAcceptableOrUnknown(data['day_pt']!, _dayPtMeta),
      );
    } else if (isInserting) {
      context.missing(_dayPtMeta);
    }
    if (data.containsKey('units')) {
      context.handle(
        _unitsMeta,
        units.isAcceptableOrUnknown(data['units']!, _unitsMeta),
      );
    } else if (isInserting) {
      context.missing(_unitsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayPt};
  @override
  QuotaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuotaRow(
      dayPt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_pt'],
      )!,
      units: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}units'],
      )!,
    );
  }

  @override
  $QuotaTable createAlias(String alias) {
    return $QuotaTable(attachedDatabase, alias);
  }
}

class QuotaRow extends DataClass implements Insertable<QuotaRow> {
  final String dayPt;
  final int units;
  const QuotaRow({required this.dayPt, required this.units});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_pt'] = Variable<String>(dayPt);
    map['units'] = Variable<int>(units);
    return map;
  }

  QuotaCompanion toCompanion(bool nullToAbsent) {
    return QuotaCompanion(dayPt: Value(dayPt), units: Value(units));
  }

  factory QuotaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuotaRow(
      dayPt: serializer.fromJson<String>(json['dayPt']),
      units: serializer.fromJson<int>(json['units']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayPt': serializer.toJson<String>(dayPt),
      'units': serializer.toJson<int>(units),
    };
  }

  QuotaRow copyWith({String? dayPt, int? units}) =>
      QuotaRow(dayPt: dayPt ?? this.dayPt, units: units ?? this.units);
  QuotaRow copyWithCompanion(QuotaCompanion data) {
    return QuotaRow(
      dayPt: data.dayPt.present ? data.dayPt.value : this.dayPt,
      units: data.units.present ? data.units.value : this.units,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuotaRow(')
          ..write('dayPt: $dayPt, ')
          ..write('units: $units')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayPt, units);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuotaRow &&
          other.dayPt == this.dayPt &&
          other.units == this.units);
}

class QuotaCompanion extends UpdateCompanion<QuotaRow> {
  final Value<String> dayPt;
  final Value<int> units;
  final Value<int> rowid;
  const QuotaCompanion({
    this.dayPt = const Value.absent(),
    this.units = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuotaCompanion.insert({
    required String dayPt,
    required int units,
    this.rowid = const Value.absent(),
  }) : dayPt = Value(dayPt),
       units = Value(units);
  static Insertable<QuotaRow> custom({
    Expression<String>? dayPt,
    Expression<int>? units,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayPt != null) 'day_pt': dayPt,
      if (units != null) 'units': units,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuotaCompanion copyWith({
    Value<String>? dayPt,
    Value<int>? units,
    Value<int>? rowid,
  }) {
    return QuotaCompanion(
      dayPt: dayPt ?? this.dayPt,
      units: units ?? this.units,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayPt.present) {
      map['day_pt'] = Variable<String>(dayPt.value);
    }
    if (units.present) {
      map['units'] = Variable<int>(units.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuotaCompanion(')
          ..write('dayPt: $dayPt, ')
          ..write('units: $units, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PositionsTable positions = $PositionsTable(this);
  late final $QueueEntriesTable queueEntries = $QueueEntriesTable(this);
  late final $QueueStateTable queueState = $QueueStateTable(this);
  late final $LocalPlaylistsTable localPlaylists = $LocalPlaylistsTable(this);
  late final $LocalPlaylistItemsTable localPlaylistItems =
      $LocalPlaylistItemsTable(this);
  late final $ApiCacheTable apiCache = $ApiCacheTable(this);
  late final $QuotaTable quota = $QuotaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    positions,
    queueEntries,
    queueState,
    localPlaylists,
    localPlaylistItems,
    apiCache,
    quota,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_playlist_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PositionsTableCreateCompanionBuilder = PositionsCompanion Function({
  required String videoId,
  required int positionMs,
  required int durationMs,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PositionsTableUpdateCompanionBuilder = PositionsCompanion Function({
  Value<String> videoId,
  Value<int> positionMs,
  Value<int> durationMs,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PositionsTableFilterComposer
    extends Composer<_$AppDatabase, $PositionsTable> {
  $$PositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PositionsTable> {
  $$PositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PositionsTable> {
  $$PositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PositionsTable,
          Position,
          $$PositionsTableFilterComposer,
          $$PositionsTableOrderingComposer,
          $$PositionsTableAnnotationComposer,
          $$PositionsTableCreateCompanionBuilder,
          $$PositionsTableUpdateCompanionBuilder,
          (Position, BaseReferences<_$AppDatabase, $PositionsTable, Position>),
          Position,
          PrefetchHooks Function()
        > {
  $$PositionsTableTableManager(_$AppDatabase db, $PositionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PositionsCompanion(
                videoId: videoId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required int positionMs,
                required int durationMs,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PositionsCompanion.insert(
                videoId: videoId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PositionsTable, Position>(table),
                  BaseReferences<_$AppDatabase, $PositionsTable, Position>(
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

typedef $$PositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PositionsTable,
      Position,
      $$PositionsTableFilterComposer,
      $$PositionsTableOrderingComposer,
      $$PositionsTableAnnotationComposer,
      $$PositionsTableCreateCompanionBuilder,
      $$PositionsTableUpdateCompanionBuilder,
      (Position, BaseReferences<_$AppDatabase, $PositionsTable, Position>),
      Position,
      PrefetchHooks Function()
    >;
typedef $$QueueEntriesTableCreateCompanionBuilder =
    QueueEntriesCompanion Function({
      Value<int> key,
      required int ord,
      required String videoId,
      Value<String?> title,
      Value<String?> author,
      Value<int?> durationMs,
      Value<String?> thumbUrl,
      Value<bool> failed,
    });
typedef $$QueueEntriesTableUpdateCompanionBuilder =
    QueueEntriesCompanion Function({
      Value<int> key,
      Value<int> ord,
      Value<String> videoId,
      Value<String?> title,
      Value<String?> author,
      Value<int?> durationMs,
      Value<String?> thumbUrl,
      Value<bool> failed,
    });

class $$QueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<bool> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);
}

class $$QueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueEntriesTable,
          QueueEntryRow,
          $$QueueEntriesTableFilterComposer,
          $$QueueEntriesTableOrderingComposer,
          $$QueueEntriesTableAnnotationComposer,
          $$QueueEntriesTableCreateCompanionBuilder,
          $$QueueEntriesTableUpdateCompanionBuilder,
          (
            QueueEntryRow,
            BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntryRow>,
          ),
          QueueEntryRow,
          PrefetchHooks Function()
        > {
  $$QueueEntriesTableTableManager(_$AppDatabase db, $QueueEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> key = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<bool> failed = const Value.absent(),
              }) => QueueEntriesCompanion(
                key: key,
                ord: ord,
                videoId: videoId,
                title: title,
                author: author,
                durationMs: durationMs,
                thumbUrl: thumbUrl,
                failed: failed,
              ),
          createCompanionCallback:
              ({
                Value<int> key = const Value.absent(),
                required int ord,
                required String videoId,
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<bool> failed = const Value.absent(),
              }) => QueueEntriesCompanion.insert(
                key: key,
                ord: ord,
                videoId: videoId,
                title: title,
                author: author,
                durationMs: durationMs,
                thumbUrl: thumbUrl,
                failed: failed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QueueEntriesTable, QueueEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $QueueEntriesTable,
                    QueueEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueEntriesTable,
      QueueEntryRow,
      $$QueueEntriesTableFilterComposer,
      $$QueueEntriesTableOrderingComposer,
      $$QueueEntriesTableAnnotationComposer,
      $$QueueEntriesTableCreateCompanionBuilder,
      $$QueueEntriesTableUpdateCompanionBuilder,
      (
        QueueEntryRow,
        BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntryRow>,
      ),
      QueueEntryRow,
      PrefetchHooks Function()
    >;
typedef $$QueueStateTableCreateCompanionBuilder = QueueStateCompanion Function({
  Value<int> id,
  Value<int?> currentKey,
  required DateTime updatedAt,
});
typedef $$QueueStateTableUpdateCompanionBuilder = QueueStateCompanion Function({
  Value<int> id,
  Value<int?> currentKey,
  Value<DateTime> updatedAt,
});

class $$QueueStateTableFilterComposer
    extends Composer<_$AppDatabase, $QueueStateTable> {
  $$QueueStateTableFilterComposer({
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

  ColumnFilters<int> get currentKey => $composableBuilder(
    column: $table.currentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueStateTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueStateTable> {
  $$QueueStateTableOrderingComposer({
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

  ColumnOrderings<int> get currentKey => $composableBuilder(
    column: $table.currentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueStateTable> {
  $$QueueStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentKey => $composableBuilder(
    column: $table.currentKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$QueueStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueStateTable,
          QueueStateRow,
          $$QueueStateTableFilterComposer,
          $$QueueStateTableOrderingComposer,
          $$QueueStateTableAnnotationComposer,
          $$QueueStateTableCreateCompanionBuilder,
          $$QueueStateTableUpdateCompanionBuilder,
          (
            QueueStateRow,
            BaseReferences<_$AppDatabase, $QueueStateTable, QueueStateRow>,
          ),
          QueueStateRow,
          PrefetchHooks Function()
        > {
  $$QueueStateTableTableManager(_$AppDatabase db, $QueueStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> currentKey = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => QueueStateCompanion(
                id: id,
                currentKey: currentKey,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> currentKey = const Value.absent(),
                required DateTime updatedAt,
              }) => QueueStateCompanion.insert(
                id: id,
                currentKey: currentKey,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QueueStateTable, QueueStateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $QueueStateTable,
                    QueueStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueStateTable,
      QueueStateRow,
      $$QueueStateTableFilterComposer,
      $$QueueStateTableOrderingComposer,
      $$QueueStateTableAnnotationComposer,
      $$QueueStateTableCreateCompanionBuilder,
      $$QueueStateTableUpdateCompanionBuilder,
      (
        QueueStateRow,
        BaseReferences<_$AppDatabase, $QueueStateTable, QueueStateRow>,
      ),
      QueueStateRow,
      PrefetchHooks Function()
    >;
typedef $$LocalPlaylistsTableCreateCompanionBuilder =
    LocalPlaylistsCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$LocalPlaylistsTableUpdateCompanionBuilder =
    LocalPlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$LocalPlaylistsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalPlaylistsTable, LocalPlaylistRow> {
  $$LocalPlaylistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LocalPlaylistItemsTable,
    List<LocalPlaylistItemRow>
  >
  _localPlaylistItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localPlaylistItems,
        aliasName: 'local_playlists__id__local_playlist_items__playlist_id',
      );

  $$LocalPlaylistItemsTableProcessedTableManager get localPlaylistItemsRefs {
    final manager = $$LocalPlaylistItemsTableTableManager(
      $_db,
      $_db.localPlaylistItems,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localPlaylistItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalPlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localPlaylistItemsRefs(
    Expression<bool> Function($$LocalPlaylistItemsTableFilterComposer f) f,
  ) {
    final $$LocalPlaylistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localPlaylistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistItemsTableFilterComposer(
            $db: $db,
            $table: $db.localPlaylistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalPlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> localPlaylistItemsRefs<T extends Object>(
    Expression<T> Function($$LocalPlaylistItemsTableAnnotationComposer a) f,
  ) {
    final $$LocalPlaylistItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localPlaylistItems,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalPlaylistItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.localPlaylistItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalPlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPlaylistsTable,
          LocalPlaylistRow,
          $$LocalPlaylistsTableFilterComposer,
          $$LocalPlaylistsTableOrderingComposer,
          $$LocalPlaylistsTableAnnotationComposer,
          $$LocalPlaylistsTableCreateCompanionBuilder,
          $$LocalPlaylistsTableUpdateCompanionBuilder,
          (LocalPlaylistRow, $$LocalPlaylistsTableReferences),
          LocalPlaylistRow,
          PrefetchHooks Function({bool localPlaylistItemsRefs})
        > {
  $$LocalPlaylistsTableTableManager(
    _$AppDatabase db,
    $LocalPlaylistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalPlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => LocalPlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalPlaylistsTable, LocalPlaylistRow>(table),
                  $$LocalPlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localPlaylistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localPlaylistItemsRefs) db.localPlaylistItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localPlaylistItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      LocalPlaylistRow,
                      $LocalPlaylistsTable,
                      LocalPlaylistItemRow,
                      $LocalPlaylistItemsTable
                    >(
                      currentTable: table,
                      referencedTable: $$LocalPlaylistsTableReferences
                          ._localPlaylistItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalPlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).localPlaylistItemsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalPlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPlaylistsTable,
      LocalPlaylistRow,
      $$LocalPlaylistsTableFilterComposer,
      $$LocalPlaylistsTableOrderingComposer,
      $$LocalPlaylistsTableAnnotationComposer,
      $$LocalPlaylistsTableCreateCompanionBuilder,
      $$LocalPlaylistsTableUpdateCompanionBuilder,
      (LocalPlaylistRow, $$LocalPlaylistsTableReferences),
      LocalPlaylistRow,
      PrefetchHooks Function({bool localPlaylistItemsRefs})
    >;
typedef $$LocalPlaylistItemsTableCreateCompanionBuilder =
    LocalPlaylistItemsCompanion Function({
      required int playlistId,
      required int ord,
      required String videoId,
      Value<String?> title,
      Value<String?> author,
      Value<int?> durationMs,
      Value<String?> thumbUrl,
      Value<int> rowid,
    });
typedef $$LocalPlaylistItemsTableUpdateCompanionBuilder =
    LocalPlaylistItemsCompanion Function({
      Value<int> playlistId,
      Value<int> ord,
      Value<String> videoId,
      Value<String?> title,
      Value<String?> author,
      Value<int?> durationMs,
      Value<String?> thumbUrl,
      Value<int> rowid,
    });

final class $$LocalPlaylistItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalPlaylistItemsTable,
          LocalPlaylistItemRow
        > {
  $$LocalPlaylistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalPlaylistsTable _playlistIdTable(_$AppDatabase db) => db
      .localPlaylists
      .createAlias('local_playlist_items__playlist_id__local_playlists__id');

  $$LocalPlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$LocalPlaylistsTableTableManager(
      $_db,
      $_db.localPlaylists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalPlaylistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlaylistItemsTable> {
  $$LocalPlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalPlaylistsTableFilterComposer get playlistId {
    final $$LocalPlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.localPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.localPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPlaylistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlaylistItemsTable> {
  $$LocalPlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalPlaylistsTableOrderingComposer get playlistId {
    final $$LocalPlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.localPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.localPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPlaylistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlaylistItemsTable> {
  $$LocalPlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  $$LocalPlaylistsTableAnnotationComposer get playlistId {
    final $$LocalPlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.localPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.localPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPlaylistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPlaylistItemsTable,
          LocalPlaylistItemRow,
          $$LocalPlaylistItemsTableFilterComposer,
          $$LocalPlaylistItemsTableOrderingComposer,
          $$LocalPlaylistItemsTableAnnotationComposer,
          $$LocalPlaylistItemsTableCreateCompanionBuilder,
          $$LocalPlaylistItemsTableUpdateCompanionBuilder,
          (LocalPlaylistItemRow, $$LocalPlaylistItemsTableReferences),
          LocalPlaylistItemRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$LocalPlaylistItemsTableTableManager(
    _$AppDatabase db,
    $LocalPlaylistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlaylistItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPlaylistItemsCompanion(
                playlistId: playlistId,
                ord: ord,
                videoId: videoId,
                title: title,
                author: author,
                durationMs: durationMs,
                thumbUrl: thumbUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required int ord,
                required String videoId,
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPlaylistItemsCompanion.insert(
                playlistId: playlistId,
                ord: ord,
                videoId: videoId,
                title: title,
                author: author,
                durationMs: durationMs,
                thumbUrl: thumbUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalPlaylistItemsTable, LocalPlaylistItemRow>(
                    table,
                  ),
                  $$LocalPlaylistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
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
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$LocalPlaylistItemsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$LocalPlaylistItemsTableReferences
                            ._playlistIdTable(db)
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

typedef $$LocalPlaylistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPlaylistItemsTable,
      LocalPlaylistItemRow,
      $$LocalPlaylistItemsTableFilterComposer,
      $$LocalPlaylistItemsTableOrderingComposer,
      $$LocalPlaylistItemsTableAnnotationComposer,
      $$LocalPlaylistItemsTableCreateCompanionBuilder,
      $$LocalPlaylistItemsTableUpdateCompanionBuilder,
      (LocalPlaylistItemRow, $$LocalPlaylistItemsTableReferences),
      LocalPlaylistItemRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$ApiCacheTableCreateCompanionBuilder = ApiCacheCompanion Function({
  required String key,
  required String json,
  required DateTime fetchedAt,
  required int ttlSec,
  Value<bool> private,
  Value<int> rowid,
});
typedef $$ApiCacheTableUpdateCompanionBuilder = ApiCacheCompanion Function({
  Value<String> key,
  Value<String> json,
  Value<DateTime> fetchedAt,
  Value<int> ttlSec,
  Value<bool> private,
  Value<int> rowid,
});

class $$ApiCacheTableFilterComposer
    extends Composer<_$AppDatabase, $ApiCacheTable> {
  $$ApiCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ttlSec => $composableBuilder(
    column: $table.ttlSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ApiCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $ApiCacheTable> {
  $$ApiCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ttlSec => $composableBuilder(
    column: $table.ttlSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ApiCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApiCacheTable> {
  $$ApiCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get ttlSec =>
      $composableBuilder(column: $table.ttlSec, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);
}

class $$ApiCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ApiCacheTable,
          ApiCacheRow,
          $$ApiCacheTableFilterComposer,
          $$ApiCacheTableOrderingComposer,
          $$ApiCacheTableAnnotationComposer,
          $$ApiCacheTableCreateCompanionBuilder,
          $$ApiCacheTableUpdateCompanionBuilder,
          (
            ApiCacheRow,
            BaseReferences<_$AppDatabase, $ApiCacheTable, ApiCacheRow>,
          ),
          ApiCacheRow,
          PrefetchHooks Function()
        > {
  $$ApiCacheTableTableManager(_$AppDatabase db, $ApiCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApiCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApiCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApiCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> ttlSec = const Value.absent(),
                Value<bool> private = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ApiCacheCompanion(
                key: key,
                json: json,
                fetchedAt: fetchedAt,
                ttlSec: ttlSec,
                private: private,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required DateTime fetchedAt,
                required int ttlSec,
                Value<bool> private = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ApiCacheCompanion.insert(
                key: key,
                json: json,
                fetchedAt: fetchedAt,
                ttlSec: ttlSec,
                private: private,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ApiCacheTable, ApiCacheRow>(table),
                  BaseReferences<_$AppDatabase, $ApiCacheTable, ApiCacheRow>(
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

typedef $$ApiCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ApiCacheTable,
      ApiCacheRow,
      $$ApiCacheTableFilterComposer,
      $$ApiCacheTableOrderingComposer,
      $$ApiCacheTableAnnotationComposer,
      $$ApiCacheTableCreateCompanionBuilder,
      $$ApiCacheTableUpdateCompanionBuilder,
      (ApiCacheRow, BaseReferences<_$AppDatabase, $ApiCacheTable, ApiCacheRow>),
      ApiCacheRow,
      PrefetchHooks Function()
    >;
typedef $$QuotaTableCreateCompanionBuilder = QuotaCompanion Function({
  required String dayPt,
  required int units,
  Value<int> rowid,
});
typedef $$QuotaTableUpdateCompanionBuilder = QuotaCompanion Function({
  Value<String> dayPt,
  Value<int> units,
  Value<int> rowid,
});

class $$QuotaTableFilterComposer extends Composer<_$AppDatabase, $QuotaTable> {
  $$QuotaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dayPt => $composableBuilder(
    column: $table.dayPt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuotaTableOrderingComposer
    extends Composer<_$AppDatabase, $QuotaTable> {
  $$QuotaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dayPt => $composableBuilder(
    column: $table.dayPt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuotaTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuotaTable> {
  $$QuotaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dayPt =>
      $composableBuilder(column: $table.dayPt, builder: (column) => column);

  GeneratedColumn<int> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);
}

class $$QuotaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuotaTable,
          QuotaRow,
          $$QuotaTableFilterComposer,
          $$QuotaTableOrderingComposer,
          $$QuotaTableAnnotationComposer,
          $$QuotaTableCreateCompanionBuilder,
          $$QuotaTableUpdateCompanionBuilder,
          (QuotaRow, BaseReferences<_$AppDatabase, $QuotaTable, QuotaRow>),
          QuotaRow,
          PrefetchHooks Function()
        > {
  $$QuotaTableTableManager(_$AppDatabase db, $QuotaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuotaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuotaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuotaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dayPt = const Value.absent(),
            Value<int> units = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => QuotaCompanion(dayPt: dayPt, units: units, rowid: rowid),
          createCompanionCallback: ({
            required String dayPt,
            required int units,
            Value<int> rowid = const Value.absent(),
          }) => QuotaCompanion.insert(dayPt: dayPt, units: units, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuotaTable, QuotaRow>(table),
                  BaseReferences<_$AppDatabase, $QuotaTable, QuotaRow>(
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

typedef $$QuotaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuotaTable,
      QuotaRow,
      $$QuotaTableFilterComposer,
      $$QuotaTableOrderingComposer,
      $$QuotaTableAnnotationComposer,
      $$QuotaTableCreateCompanionBuilder,
      $$QuotaTableUpdateCompanionBuilder,
      (QuotaRow, BaseReferences<_$AppDatabase, $QuotaTable, QuotaRow>),
      QuotaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PositionsTableTableManager get positions =>
      $$PositionsTableTableManager(_db, _db.positions);
  $$QueueEntriesTableTableManager get queueEntries =>
      $$QueueEntriesTableTableManager(_db, _db.queueEntries);
  $$QueueStateTableTableManager get queueState =>
      $$QueueStateTableTableManager(_db, _db.queueState);
  $$LocalPlaylistsTableTableManager get localPlaylists =>
      $$LocalPlaylistsTableTableManager(_db, _db.localPlaylists);
  $$LocalPlaylistItemsTableTableManager get localPlaylistItems =>
      $$LocalPlaylistItemsTableTableManager(_db, _db.localPlaylistItems);
  $$ApiCacheTableTableManager get apiCache =>
      $$ApiCacheTableTableManager(_db, _db.apiCache);
  $$QuotaTableTableManager get quota =>
      $$QuotaTableTableManager(_db, _db.quota);
}
