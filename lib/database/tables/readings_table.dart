import 'package:drift/drift.dart';

/// Локальный кеш показаний счётчиков (ТЗ §4.2, §7). Не существует для
/// производных каналов и для поставщиков типа without_readings.
@DataClassName('ReadingRow')
class Readings extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get channelId => text()();
  RealColumn get value => real()();
  DateTimeColumn get readingDate => dateTime()();
  /// Показание после замены счётчика — снимает ограничение
  /// «не меньше предыдущего» (ТЗ §4.2).
  BoolColumn get meterReplaced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
