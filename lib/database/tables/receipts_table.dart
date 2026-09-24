import 'package:drift/drift.dart';

/// Локальный кеш чеков об оплате (ТЗ §4.5, §7).
@DataClassName('ReceiptRow')
class Receipts extends Table {
  TextColumn get id => text()();
  TextColumn get paymentId => text()();
  TextColumn get filePath => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
