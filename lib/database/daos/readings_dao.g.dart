// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readings_dao.dart';

// ignore_for_file: type=lint
mixin _$ReadingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReadingsTable get readings => attachedDatabase.readings;
  ReadingsDaoManager get managers => ReadingsDaoManager(this);
}

class ReadingsDaoManager {
  final _$ReadingsDaoMixin _db;
  ReadingsDaoManager(this._db);
  $$ReadingsTableTableManager get readings =>
      $$ReadingsTableTableManager(_db.attachedDatabase, _db.readings);
}
