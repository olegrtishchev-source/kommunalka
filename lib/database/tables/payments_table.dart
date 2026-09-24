import 'package:drift/drift.dart';

/// Локальный кеш платежей (ТЗ §4.3–4.4, §7).
@DataClassName('PaymentRow')
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get supplierId => text()();
  /// Первое число месяца периода (напр. 2026-09-01).
  DateTimeColumn get period => dateTime()();
  /// Сериализованный JSON-массив (список ReadingSnapshotEntry.toJson()).
  TextColumn get readingSnapshot => text().nullable()();
  RealColumn get consumption => real().nullable()();
  RealColumn get calculatedAmount => real()();
  RealColumn get actualAmount => real().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get paymentDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
