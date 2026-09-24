import 'package:drift/drift.dart';

/// Локальный кеш каналов показаний (ТЗ §4.1, §7).
///
/// supplierId и sourceChannelId без .references() — drift здесь только
/// зеркалирует Supabase (источник истины и настоящие FK — в Postgres,
/// supabase/schema.sql), локальный кеш не создаёт данные самостоятельно
/// (ТЗ §4.7: создание записей требует сети, всегда идёт через Supabase),
/// поэтому ссылочная целостность на уровне SQLite не нужна.
@DataClassName('ChannelRow')
class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get supplierId => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()();
  RealColumn get tariff => real()();
  /// Производный канал (ТЗ §4.1): расход берётся из канала-источника,
  /// собственных показаний нет. Самоссылка на эту же таблицу.
  TextColumn get sourceChannelId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
