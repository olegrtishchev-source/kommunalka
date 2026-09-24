import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/suppliers_dao.dart';
import '../models/supplier.dart';
import '../services/supabase_tables.dart';

/// Поставщики: чтение — из локального кеша (drift, реактивно), запись —
/// сначала в Supabase (источник истины, ТЗ §4.7 — создание требует сети),
/// затем результат (с id/user_id/таймстемпами, сгенерированными на сервере)
/// кладётся в локальный кеш тем же upsert, которым его обновляет [refresh].
///
/// Обработка сетевых/серверных ошибок здесь намеренно не перехватывается —
/// это отдельный пункт плана (Этап 3.9), как и разбор ошибок авторизации
/// был оставлен экранам в AuthService (см. журнал 3.2).
class SupplierRepository {
  SupplierRepository(this._client, this._dao);

  final SupabaseClient _client;
  final SuppliersDao _dao;

  /// Активные (неархивные) поставщики — для главного экрана (ТЗ §4.1).
  Stream<List<SupplierRow>> watchActive() => _dao.watchActive();

  /// Все поставщики, включая архивные — для экранов, где архив нужен
  /// (например, история платежей архивного поставщика).
  Stream<List<SupplierRow>> watchAll() => _dao.watchAll();

  Future<SupplierRow?> getById(String id) => _dao.getById(id);

  /// Подтягивает актуальный список поставщиков из Supabase и обновляет
  /// локальный кеш. Вызывается при старте приложения, открытии экрана
  /// и pull-to-refresh (ТЗ §4.7) — сам механизм вызова не здесь, это дело
  /// экранов/провайдеров Этапа 4.
  Future<void> refresh() async {
    final rows = await _client.from(SupabaseTables.suppliers).select();
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      await _dao.upsert(_toCompanion(Supplier.fromJson(row)));
    }
  }

  /// Создаёт нового поставщика (ТЗ §4.1). id, user_id, created_at, updated_at
  /// не передаются — их генерирует Supabase (значения по умолчанию в
  /// supabase/schema.sql: gen_random_uuid(), auth.uid(), now()).
  Future<Supplier> create({
    required String name,
    String? category,
    required SupplierType type,
    BankDetails? bankDetails,
    String? paymentPurposeTemplate,
  }) async {
    final row = await _client
        .from(SupabaseTables.suppliers)
        .insert({
          'name': name,
          'category': category,
          'type': type.dbValue,
          'bank_details': bankDetails?.toJson(),
          'payment_purpose_template': paymentPurposeTemplate,
        })
        .select()
        .single();
    final supplier = Supplier.fromJson(row);
    await _dao.upsert(_toCompanion(supplier));
    return supplier;
  }

  /// Редактирование карточки поставщика (ТЗ §4.1). Тип поставщика тоже
  /// редактируемый — своей логики блокировки смены типа тут нет, это
  /// вопрос экрана редактирования (Этап 4), а не репозитория.
  Future<Supplier> update(Supplier supplier) async {
    final row = await _client
        .from(SupabaseTables.suppliers)
        .update({
          'name': supplier.name,
          'category': supplier.category,
          'type': supplier.type.dbValue,
          'bank_details': supplier.bankDetails?.toJson(),
          'payment_purpose_template': supplier.paymentPurposeTemplate,
        })
        .eq('id', supplier.id)
        .select()
        .single();
    final updated = Supplier.fromJson(row);
    await _dao.upsert(_toCompanion(updated));
    return updated;
  }

  /// Мягкое удаление (ТЗ §4.1): выставляет archived_at, запись и связанные
  /// показания/платежи не удаляются.
  Future<void> archive(String id) async {
    final row = await _client
        .from(SupabaseTables.suppliers)
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    await _dao.upsert(_toCompanion(Supplier.fromJson(row)));
  }

  SuppliersCompanion _toCompanion(Supplier s) {
    return SuppliersCompanion(
      id: Value(s.id),
      userId: Value(s.userId),
      name: Value(s.name),
      category: Value(s.category),
      type: Value(s.type.dbValue),
      bankDetails: Value(
        s.bankDetails == null ? null : jsonEncode(s.bankDetails!.toJson()),
      ),
      paymentPurposeTemplate: Value(s.paymentPurposeTemplate),
      archivedAt: Value(s.archivedAt),
      createdAt: Value(s.createdAt),
      updatedAt: Value(s.updatedAt),
    );
  }
}
