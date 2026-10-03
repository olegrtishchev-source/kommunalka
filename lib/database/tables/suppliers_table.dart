import 'package:drift/drift.dart';

/// Локальный кеш поставщиков (зеркало таблицы suppliers в Supabase,
/// см. supabase/schema.sql, ТЗ §7).
///
/// @DataClassName переименовывает сгенерированный класс строки —
/// без этого drift назвал бы его Supplier и он столкнулся бы с доменной
/// моделью lib/models/supplier.dart.
@DataClassName('SupplierRow')
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get type => text()();
  /// Сериализованный JSON (BankDetails.toJson()).
  TextColumn get bankDetails => text().nullable()();
  TextColumn get paymentPurposeTemplate => text().nullable()();
  /// Лицевой счёт плательщика у поставщика (ТЗ §4.11).
  TextColumn get personalAccount => text().nullable()();
  /// Способы передачи показаний (bank_form / cabinet / email) — сериализованный
  /// JSON-массив строк (в SQLite нет типа массива), ТЗ §4.12.
  TextColumn get readingMethods => text().nullable()();
  TextColumn get cabinetUrl => text().nullable()();
  TextColumn get readingEmail => text().nullable()();
  /// Адрес (объект) поставщика — свободный текст (ТЗ §4.13).
  TextColumn get address => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
