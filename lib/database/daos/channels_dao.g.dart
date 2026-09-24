// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channels_dao.dart';

// ignore_for_file: type=lint
mixin _$ChannelsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChannelsTable get channels => attachedDatabase.channels;
  ChannelsDaoManager get managers => ChannelsDaoManager(this);
}

class ChannelsDaoManager {
  final _$ChannelsDaoMixin _db;
  ChannelsDaoManager(this._db);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db.attachedDatabase, _db.channels);
}
