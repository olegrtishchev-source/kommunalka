import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/payments_table.dart';

part 'payments_dao.g.dart';

@DriftAccessor(tables: [Payments])
class PaymentsDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentsDaoMixin {
  PaymentsDao(super.db);

  Stream<List<PaymentRow>> watchForSupplier(String supplierId) {
    return (select(payments)
          ..where((t) => t.supplierId.equals(supplierId))
          ..orderBy([(t) => OrderingTerm.desc(t.period)]))
        .watch();
  }

  /// Общая история по всем поставщикам пользователя (ТЗ §4.6).
  Stream<List<PaymentRow>> watchAll() {
    return (select(payments)
          ..orderBy([(t) => OrderingTerm.desc(t.period)]))
        .watch();
  }

  Future<PaymentRow?> getForSupplierAndPeriod(
    String supplierId,
    DateTime period,
  ) {
    return (select(payments)
          ..where(
            (t) => t.supplierId.equals(supplierId) & t.period.equals(period),
          ))
        .getSingleOrNull();
  }

  Future<void> upsert(PaymentsCompanion entry) {
    return into(payments).insertOnConflictUpdate(entry);
  }
}
