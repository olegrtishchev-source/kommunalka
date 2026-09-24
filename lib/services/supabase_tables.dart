/// Имена таблиц Supabase — одно место вместо строк-литералов, разбросанных
/// по репозиториям (см. supabase/schema.sql, ТЗ §7).
abstract final class SupabaseTables {
  static const suppliers = 'suppliers';
  static const channels = 'channels';
  static const readings = 'readings';
  static const payments = 'payments';
  static const receipts = 'receipts';
}
