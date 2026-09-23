// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SpikeLocalTable extends SpikeLocal
    with TableInfo<$SpikeLocalTable, SpikeLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeLocalTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, note, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikeLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikeLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeLocalData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SpikeLocalTable createAlias(String alias) {
    return $SpikeLocalTable(attachedDatabase, alias);
  }
}

class SpikeLocalData extends DataClass implements Insertable<SpikeLocalData> {
  final int id;
  final String note;
  final DateTime createdAt;
  const SpikeLocalData({
    required this.id,
    required this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SpikeLocalCompanion toCompanion(bool nullToAbsent) {
    return SpikeLocalCompanion(
      id: Value(id),
      note: Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory SpikeLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeLocalData(
      id: serializer.fromJson<int>(json['id']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SpikeLocalData copyWith({int? id, String? note, DateTime? createdAt}) =>
      SpikeLocalData(
        id: id ?? this.id,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
  SpikeLocalData copyWithCompanion(SpikeLocalCompanion data) {
    return SpikeLocalData(
      id: data.id.present ? data.id.value : this.id,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeLocalData(')
          ..write('id: $id, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikeLocalData &&
          other.id == this.id &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class SpikeLocalCompanion extends UpdateCompanion<SpikeLocalData> {
  final Value<int> id;
  final Value<String> note;
  final Value<DateTime> createdAt;
  const SpikeLocalCompanion({
    this.id = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SpikeLocalCompanion.insert({
    this.id = const Value.absent(),
    required String note,
    this.createdAt = const Value.absent(),
  }) : note = Value(note);
  static Insertable<SpikeLocalData> custom({
    Expression<int>? id,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SpikeLocalCompanion copyWith({
    Value<int>? id,
    Value<String>? note,
    Value<DateTime>? createdAt,
  }) {
    return SpikeLocalCompanion(
      id: id ?? this.id,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikeLocalCompanion(')
          ..write('id: $id, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpikeLocalTable spikeLocal = $SpikeLocalTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [spikeLocal];
}

typedef $$SpikeLocalTableCreateCompanionBuilder =
    SpikeLocalCompanion Function({
      Value<int> id,
      required String note,
      Value<DateTime> createdAt,
    });
typedef $$SpikeLocalTableUpdateCompanionBuilder =
    SpikeLocalCompanion Function({
      Value<int> id,
      Value<String> note,
      Value<DateTime> createdAt,
    });

class $$SpikeLocalTableFilterComposer
    extends Composer<_$AppDatabase, $SpikeLocalTable> {
  $$SpikeLocalTableFilterComposer({
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

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikeLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $SpikeLocalTable> {
  $$SpikeLocalTableOrderingComposer({
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

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikeLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpikeLocalTable> {
  $$SpikeLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SpikeLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpikeLocalTable,
          SpikeLocalData,
          $$SpikeLocalTableFilterComposer,
          $$SpikeLocalTableOrderingComposer,
          $$SpikeLocalTableAnnotationComposer,
          $$SpikeLocalTableCreateCompanionBuilder,
          $$SpikeLocalTableUpdateCompanionBuilder,
          (
            SpikeLocalData,
            BaseReferences<_$AppDatabase, $SpikeLocalTable, SpikeLocalData>,
          ),
          SpikeLocalData,
          PrefetchHooks Function()
        > {
  $$SpikeLocalTableTableManager(_$AppDatabase db, $SpikeLocalTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpikeLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpikeLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) =>
                  SpikeLocalCompanion(id: id, note: note, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String note,
                Value<DateTime> createdAt = const Value.absent(),
              }) => SpikeLocalCompanion.insert(
                id: id,
                note: note,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpikeLocalTable,
      SpikeLocalData,
      $$SpikeLocalTableFilterComposer,
      $$SpikeLocalTableOrderingComposer,
      $$SpikeLocalTableAnnotationComposer,
      $$SpikeLocalTableCreateCompanionBuilder,
      $$SpikeLocalTableUpdateCompanionBuilder,
      (
        SpikeLocalData,
        BaseReferences<_$AppDatabase, $SpikeLocalTable, SpikeLocalData>,
      ),
      SpikeLocalData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SpikeLocalTableTableManager get spikeLocal =>
      $$SpikeLocalTableTableManager(_db, _db.spikeLocal);
}
