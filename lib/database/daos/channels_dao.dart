import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/channels_table.dart';

part 'channels_dao.g.dart';

@DriftAccessor(tables: [Channels])
class ChannelsDao extends DatabaseAccessor<AppDatabase>
    with _$ChannelsDaoMixin {
  ChannelsDao(super.db);

  Stream<List<ChannelRow>> watchForSupplier(String supplierId) {
    return (select(channels)..where((t) => t.supplierId.equals(supplierId)))
        .watch();
  }

  /// Все каналы пользователя — для выбора канала-источника у производного
  /// канала (ТЗ §4.1: источник может быть у другого поставщика, поэтому
  /// нужна выборка не по одному supplierId, а по всем сразу).
  Stream<List<ChannelRow>> watchAll() => select(channels).watch();

  Future<ChannelRow?> getById(String id) {
    return (select(channels)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsert(ChannelsCompanion entry) {
    return into(channels).insertOnConflictUpdate(entry);
  }

  Future<void> deleteById(String id) {
    return (delete(channels)..where((t) => t.id.equals(id))).go();
  }
}
