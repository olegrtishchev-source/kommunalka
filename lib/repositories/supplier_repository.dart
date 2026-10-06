import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/channels_dao.dart';
import '../database/daos/payments_dao.dart';
import '../database/daos/readings_dao.dart';
import '../database/daos/receipts_dao.dart';
import '../database/daos/suppliers_dao.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../services/supabase_tables.dart';
import 'repository_exceptions.dart';

/// Сколько связанных данных будет удалено при полном удалении поставщика —
/// показывается в предупреждении перед необратимым действием.
class SupplierDeletionImpact {
  SupplierDeletionImpact({
    required this.payments,
    required this.receipts,
  });

  /// Платежей (за все периоды).
  final int payments;

  /// Чеков (файлов будет удалено столько же).
  final int receipts;

  bool get isEmpty => payments == 0 && receipts == 0;
}

/// Поставщики: чтение — из локального кеша (drift, реактивно), запись —
/// сначала в Supabase (источник истины, ТЗ §4.7 — создание требует сети),
/// затем результат (с id/user_id/таймстемпами, сгенерированными на сервере)
/// кладётся в локальный кеш тем же upsert, которым его обновляет [refresh].
///
/// Сетевые/серверные ошибки переводятся в NetworkException/ServerException
/// через guardRepositoryCall (Этап 3.9, lib/repositories/repository_exceptions.dart) —
/// экраны (Этап 4) ловят эти два типа вместо разбора сырых исключений Supabase.
class SupplierRepository {
  SupplierRepository(
    this._client,
    this._dao,
    this._channelsDao,
    this._readingsDao,
    this._paymentsDao,
    this._receiptsDao,
    this._storage,
  );

  final SupabaseClient _client;
  final SuppliersDao _dao;
  final ChannelsDao _channelsDao;
  final ReadingsDao _readingsDao;
  final PaymentsDao _paymentsDao;
  final ReceiptsDao _receiptsDao;
  final StorageService _storage;

  /// Активные (неархивные) поставщики — для главного экрана (ТЗ §4.1).
  Stream<List<SupplierRow>> watchActive() => _dao.watchActive();

  /// Архивные (архивированные) поставщики — для экрана «Архив» (п. 5.5.2).
  Stream<List<SupplierRow>> watchArchived() => _dao.watchArchived();

  /// Все поставщики, включая архивные — для экранов, где архив нужен
  /// (например, история платежей архивного поставщика).
  Stream<List<SupplierRow>> watchAll() => _dao.watchAll();

  Future<SupplierRow?> getById(String id) => _dao.getById(id);

  /// Подтягивает актуальный список поставщиков из Supabase и обновляет
  /// локальный кеш. Вызывается при старте приложения, открытии экрана
  /// и pull-to-refresh (ТЗ §4.7) — сам механизм вызова не здесь, это дело
  /// экранов/провайдеров Этапа 4.
  Future<void> refresh() async {
    final rows = await guardRepositoryCall(
      () => _client.from(SupabaseTables.suppliers).select(),
    );
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
    String? personalAccount,
    List<String> readingMethods = const [],
    String? cabinetUrl,
    String? readingEmail,
    String? address,
  }) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.suppliers)
          .insert({
            'name': name,
            'category': category,
            'type': type.dbValue,
            'bank_details': bankDetails?.toJson(),
            'payment_purpose_template': paymentPurposeTemplate,
            'personal_account': personalAccount,
            'reading_methods': readingMethods,
            'cabinet_url': cabinetUrl,
            'reading_email': readingEmail,
            'address': address,
          })
          .select()
          .single(),
    );
    final supplier = Supplier.fromJson(row);
    await _dao.upsert(_toCompanion(supplier));
    return supplier;
  }

  /// Редактирование карточки поставщика (ТЗ §4.1). Тип поставщика тоже
  /// редактируемый — своей логики блокировки смены типа тут нет, это
  /// вопрос экрана редактирования (Этап 4), а не репозитория.
  Future<Supplier> update(Supplier supplier) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.suppliers)
          .update({
            'name': supplier.name,
            'category': supplier.category,
            'type': supplier.type.dbValue,
            'bank_details': supplier.bankDetails?.toJson(),
            'payment_purpose_template': supplier.paymentPurposeTemplate,
            'personal_account': supplier.personalAccount,
            'reading_methods': supplier.readingMethods,
            'cabinet_url': supplier.cabinetUrl,
            'reading_email': supplier.readingEmail,
            'address': supplier.address,
          })
          .eq('id', supplier.id)
          .select()
          .single(),
    );
    final updated = Supplier.fromJson(row);
    await _dao.upsert(_toCompanion(updated));
    return updated;
  }

  /// Мягкое удаление (ТЗ §4.1): выставляет archived_at, запись и связанные
  /// показания/платежи не удаляются.
  Future<void> archive(String id) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.suppliers)
          .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .select()
          .single(),
    );
    await _dao.upsert(_toCompanion(Supplier.fromJson(row)));
  }

  /// Восстановление из архива (п. 5.5.2): очищает archived_at — поставщик
  /// возвращается в активный список.
  Future<void> unarchive(String id) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.suppliers)
          .update({'archived_at': null})
          .eq('id', id)
          .select()
          .single(),
    );
    await _dao.upsert(_toCompanion(Supplier.fromJson(row)));
  }

  /// Оценивает, сколько связанных данных будет удалено при полном удалении
  /// поставщика — для предупреждения в UI. Считает по локальному кешу.
  Future<SupplierDeletionImpact> deletionImpact(String supplierId) async {
    final payments = await _paymentsDao.getForSupplier(supplierId);
    var receipts = 0;
    for (final payment in payments) {
      receipts += (await _receiptsDao.getForPayment(payment.id)).length;
    }
    return SupplierDeletionImpact(payments: payments.length, receipts: receipts);
  }

  /// Полное (необратимое) удаление поставщика и всех связанных данных:
  /// показания, каналы, платежи, чеки (записи и файлы в Storage).
  ///
  /// Порядок важен из-за ограничений БД (supabase/schema.sql):
  /// readings.channel_id — ON DELETE RESTRICT, поэтому показания удаляются
  /// первыми, иначе удаление каналов/поставщика блокируется. Остальные связи
  /// (channels→supplier, payments→supplier, receipts→payment) — CASCADE,
  /// но удаляем явно, чтобы синхронно почистить и локальный кеш, и файлы
  /// чеков в Storage (каскад БД их не трогает).
  Future<void> deleteCompletely(String supplierId) async {
    final channels = await _channelsDao.watchForSupplier(supplierId).first;
    final payments = await _paymentsDao.getForSupplier(supplierId);

    // Собираем пути файлов чеков, чтобы удалить их из Storage.
    final receiptPaths = <String>[];
    for (final payment in payments) {
      final receipts = await _receiptsDao.getForPayment(payment.id);
      receiptPaths.addAll(receipts.map((r) => r.filePath));
    }

    // Supabase (источник истины) — порядок под ограничения FK.
    await guardRepositoryCall(() async {
      for (final channel in channels) {
        await _client.from(SupabaseTables.readings).delete().eq(
              'channel_id',
              channel.id,
            );
      }
      for (final payment in payments) {
        await _client.from(SupabaseTables.receipts).delete().eq(
              'payment_id',
              payment.id,
            );
      }
      await _client.from(SupabaseTables.payments).delete().eq(
            'supplier_id',
            supplierId,
          );
      await _client.from(SupabaseTables.channels).delete().eq(
            'supplier_id',
            supplierId,
          );
      await _client.from(SupabaseTables.suppliers).delete().eq(
            'id',
            supplierId,
          );
    });

    // Файлы чеков в Storage — после успешного удаления записей.
    await guardRepositoryCall(() => _storage.remove(receiptPaths));

    // Локальный кеш.
    for (final channel in channels) {
      await _readingsDao.deleteForChannel(channel.id);
    }
    for (final payment in payments) {
      await _receiptsDao.deleteForPayment(payment.id);
      await _paymentsDao.deleteById(payment.id);
    }
    for (final channel in channels) {
      await _channelsDao.deleteById(channel.id);
    }
    await _dao.deleteById(supplierId);
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
      personalAccount: Value(s.personalAccount),
      readingMethods: Value(
        s.readingMethods.isEmpty ? null : jsonEncode(s.readingMethods),
      ),
      cabinetUrl: Value(s.cabinetUrl),
      readingEmail: Value(s.readingEmail),
      address: Value(s.address),
      archivedAt: Value(s.archivedAt),
      createdAt: Value(s.createdAt),
      updatedAt: Value(s.updatedAt),
    );
  }
}
