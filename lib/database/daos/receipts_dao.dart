import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/receipts_table.dart';

part 'receipts_dao.g.dart';

@DriftAccessor(tables: [Receipts])
class ReceiptsDao extends DatabaseAccessor<AppDatabase>
    with _$ReceiptsDaoMixin {
  ReceiptsDao(super.db);

  Stream<List<ReceiptRow>> watchForPayment(String paymentId) {
    return (select(receipts)..where((t) => t.paymentId.equals(paymentId)))
        .watch();
  }

  Future<void> upsert(ReceiptsCompanion entry) {
    return into(receipts).insertOnConflictUpdate(entry);
  }

  /// Пути файлов чеков платежа (для удаления из Storage) — часть полного
  /// удаления поставщика (см. SupplierRepository.deleteCompletely).
  Future<List<ReceiptRow>> getForPayment(String paymentId) {
    return (select(receipts)..where((t) => t.paymentId.equals(paymentId))).get();
  }

  /// Удаляет все чеки платежа из локального кеша — часть полного удаления
  /// поставщика.
  Future<void> deleteForPayment(String paymentId) {
    return (delete(receipts)..where((t) => t.paymentId.equals(paymentId))).go();
  }
}
