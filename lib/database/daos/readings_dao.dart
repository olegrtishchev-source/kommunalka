import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/readings_table.dart';

part 'readings_dao.g.dart';

@DriftAccessor(tables: [Readings])
class ReadingsDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingsDaoMixin {
  ReadingsDao(super.db);

  Stream<List<ReadingRow>> watchForChannel(String channelId) {
    return (select(readings)
          ..where((t) => t.channelId.equals(channelId))
          ..orderBy([(t) => OrderingTerm.desc(t.readingDate)]))
        .watch();
  }

  /// Последнее показание по каналу — приложение подтягивает его
  /// автоматически как «предыдущее» (ТЗ §4.2).
  Future<ReadingRow?> getLatestForChannel(String channelId) {
    return (select(readings)
          ..where((t) => t.channelId.equals(channelId))
          ..orderBy([(t) => OrderingTerm.desc(t.readingDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsert(ReadingsCompanion entry) {
    return into(readings).insertOnConflictUpdate(entry);
  }
}
