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
}
