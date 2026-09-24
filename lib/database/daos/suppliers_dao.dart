import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/suppliers_table.dart';

part 'suppliers_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SuppliersDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  /// Активные (неархивные) поставщики — главный экран (ТЗ §4.1).
  Stream<List<SupplierRow>> watchActive() {
    return (select(suppliers)..where((t) => t.archivedAt.isNull())).watch();
  }

  Stream<List<SupplierRow>> watchAll() => select(suppliers).watch();

  Future<SupplierRow?> getById(String id) {
    return (select(suppliers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Кеш обновляется данными из Supabase (pull-синхронизация, ТЗ §4.7) —
  /// вставка или замена по id.
  Future<void> upsert(SuppliersCompanion entry) {
    return into(suppliers).insertOnConflictUpdate(entry);
  }

  Future<void> deleteById(String id) {
    return (delete(suppliers)..where((t) => t.id.equals(id))).go();
  }
}
