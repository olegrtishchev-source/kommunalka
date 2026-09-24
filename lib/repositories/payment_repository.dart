import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/payments_dao.dart';
import '../models/payment.dart';
import '../services/supabase_tables.dart';
import '../utils/json_parsing.dart';
import 'repository_exceptions.dart';

/// Платежи: чтение — из локального кеша (drift, реактивно), запись —
/// сначала в Supabase, потом в кеш (та же схема, что и в остальных
/// репозиториях, см. журнал 3.5/3.6). Сетевые/серверные ошибки — через
/// guardRepositoryCall (Этап 3.9).
class PaymentRepository {
  PaymentRepository(this._client, this._dao);

  final SupabaseClient _client;
  final PaymentsDao _dao;

  /// Платежи по конкретному поставщику (ТЗ §4.6).
  Stream<List<PaymentRow>> watchForSupplier(String supplierId) =>
      _dao.watchForSupplier(supplierId);

  /// Общая история по всем поставщикам (ТЗ §4.6).
  Stream<List<PaymentRow>> watchAll() => _dao.watchAll();

  Future<PaymentRow?> getById(String id) => _dao.getById(id);

  Future<PaymentRow?> getForSupplierAndPeriod(
    String supplierId,
    DateTime period,
  ) => _dao.getForSupplierAndPeriod(supplierId, period);

  /// Подтягивает все платежи пользователя из Supabase (RLS уже ограничивает
  /// выборку его записями) и обновляет локальный кеш.
  Future<void> refresh() async {
    final rows = await guardRepositoryCall(
      () => _client.from(SupabaseTables.payments).select(),
    );
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      await _dao.upsert(_toCompanion(Payment.fromJson(row)));
    }
  }

  /// Создаёт платёж в момент перехода с экрана ввода показаний/суммы на
  /// экран оплаты (ТЗ §4.3, кнопка «Далее»). Факт-сумма, банк и дата
  /// оплаты ещё не заполнены — статус всегда `pending`; их вносит
  /// [recordPayment] следующим шагом (ТЗ §4.4). [readingSnapshot]/
  /// [consumption] — только для поставщика `with_readings`, для
  /// `without_readings` оба остаются null (ТЗ §4.3).
  Future<Payment> create({
    required String supplierId,
    required DateTime period,
    List<ReadingSnapshotEntry>? readingSnapshot,
    double? consumption,
    required double calculatedAmount,
  }) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.payments)
          .insert({
            'supplier_id': supplierId,
            'period': formatDateOnly(period),
            'reading_snapshot':
                readingSnapshot?.map((e) => e.toJson()).toList(),
            'consumption': consumption,
            'calculated_amount': calculatedAmount,
            'status': PaymentStatus.pending.dbValue,
          })
          .select()
          .single(),
    );
    final payment = Payment.fromJson(row);
    await _dao.upsert(_toCompanion(payment));
    return payment;
  }

  /// Шаг «оплата» (ТЗ §4.4): вносит факт-сумму и банк, статус пересчитывается
  /// автоматически по соотношению факта и расчётной суммы
  /// (PaymentStatus.calculate) — не передаётся снаружи, чтобы не завести
  /// рассинхронизацию между суммой и статусом. Тот же метод используется
  /// и для последующей корректировки факт-суммы/банка/даты (ТЗ §4.4:
  /// «можно откорректировать позже»), отдельного метода под это не заводим.
  Future<Payment> recordPayment({
    required String paymentId,
    required double actualAmount,
    required DateTime paymentDate,
  }) async {
    final cached = await _dao.getById(paymentId);
    if (cached == null) {
      throw StateError(
        'Платёж $paymentId отсутствует в локальном кеше — сначала refresh().',
      );
    }
    final status = PaymentStatus.calculate(
      calculatedAmount: cached.calculatedAmount,
      actualAmount: actualAmount,
    );
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.payments)
          .update({
            'actual_amount': actualAmount,
            'payment_date': formatDateOnly(paymentDate),
            'status': status.dbValue,
          })
          .eq('id', paymentId)
          .select()
          .single(),
    );
    final updated = Payment.fromJson(row);
    await _dao.upsert(_toCompanion(updated));
    return updated;
  }

  PaymentsCompanion _toCompanion(Payment p) {
    return PaymentsCompanion(
      id: Value(p.id),
      userId: Value(p.userId),
      supplierId: Value(p.supplierId),
      period: Value(p.period),
      readingSnapshot: Value(
        p.readingSnapshot == null
            ? null
            : jsonEncode(p.readingSnapshot!.map((e) => e.toJson()).toList()),
      ),
      consumption: Value(p.consumption),
      calculatedAmount: Value(p.calculatedAmount),
      actualAmount: Value(p.actualAmount),
      status: Value(p.status.dbValue),
      paymentDate: Value(p.paymentDate),
      createdAt: Value(p.createdAt),
      updatedAt: Value(p.updatedAt),
    );
  }
}
