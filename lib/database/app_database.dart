import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Спайк Этапа 1.5 — минимальная локальная таблица, чтобы проверить,
/// что drift собирается и работает на Android (нативная sqlite3-библиотека,
/// генерация кода). Реальная схема (Supplier/Channel/Reading/Payment/Receipt)
/// появится на Этапе 2–3.
class SpikeLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [SpikeLocal])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'kommunalka_local');
}
