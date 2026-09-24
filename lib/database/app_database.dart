import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/channels_dao.dart';
import 'daos/payments_dao.dart';
import 'daos/readings_dao.dart';
import 'daos/receipts_dao.dart';
import 'daos/suppliers_dao.dart';
import 'tables/channels_table.dart';
import 'tables/payments_table.dart';
import 'tables/readings_table.dart';
import 'tables/receipts_table.dart';
import 'tables/suppliers_table.dart';

part 'app_database.g.dart';

/// Спайк Этапа 1.5 — минимальная локальная таблица, оставлена как есть до
/// замены спайк-экрана настоящими экранами (Этап 3.5). Реальная схема ниже.
class SpikeLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [SpikeLocal, Suppliers, Channels, Readings, Payments, Receipts],
  daos: [SuppliersDao, ChannelsDao, ReadingsDao, PaymentsDao, ReceiptsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // drift — только локальный кеш поверх Supabase (ТЗ §3), а не
          // источник истины: при смене схемы кеша проще пересоздать таблицы
          // и заново наполнить их через pull-синхронизацию (ТЗ §4.7), чем
          // писать пошаговые миграции для промежуточных версий кеша.
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'kommunalka_local');
}
