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

@DriftDatabase(
  tables: [Suppliers, Channels, Readings, Payments, Receipts],
  daos: [SuppliersDao, ChannelsDao, ReadingsDao, PaymentsDao, ReceiptsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // drift — только локальный кеш поверх Supabase (ТЗ §3), а не
          // источник истины: при смене схемы кеша проще пересоздать таблицы
          // и заново наполнить их через pull-синхронизацию (ТЗ §4.7), чем
          // писать пошаговые миграции для промежуточных версий кеша.
          //
          // v2 → v3 (Этап 3.5): удалена спайк-таблица SpikeLocal — цикл
          // deleteTable ниже проходит по актуальному allTables (уже без
          // неё), поэтому саму spike_local в SQLite он не тронет. Она
          // останется в файле БД как безобидный мусор; чтобы убрать её
          // физически — переустановить приложение на тестовом устройстве
          // (не обязательно для корректной работы, просто для чистоты).
          //
          // v3 → v4 (Этап 3.5.4): убрано поле bank у Payments — источник
          // информации о банке теперь чек (ТЗ §4.5), а не отдельное поле.
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
