import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/receipts_dao.dart';
import '../models/receipt.dart';
import '../services/storage_service.dart';
import '../services/supabase_tables.dart';
import 'repository_exceptions.dart';

/// Чеки об оплате: чтение — из локального кеша (drift, реактивно), запись —
/// сначала файл в Storage, потом строка в Supabase, потом кеш (та же
/// схема, что и у остальных репозиториев, см. журнал 3.5–3.7). Сетевые/
/// серверные ошибки Storage и Supabase — через guardRepositoryCall
/// (Этап 3.9); compress() — чистая локальная операция, её не оборачиваем.
class ReceiptRepository {
  ReceiptRepository(this._client, this._dao, this._storage);

  final SupabaseClient _client;
  final ReceiptsDao _dao;
  final StorageService _storage;

  /// Чеки, прикреплённые к платежу — может быть больше одного (ТЗ §4.5
  /// не ограничивает количество прикреплённых файлов на платёж).
  Stream<List<ReceiptRow>> watchForPayment(String paymentId) =>
      _dao.watchForPayment(paymentId);

  /// Подтягивает все чеки пользователя из Supabase (RLS через
  /// payment_id → payments.user_id, см. журнал 2.3) и обновляет кеш.
  Future<void> refresh() async {
    final rows = await guardRepositoryCall(
      () => _client.from(SupabaseTables.receipts).select(),
    );
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      await _dao.upsert(_toCompanion(Receipt.fromJson(row)));
    }
  }

  /// Прикрепляет чек к платежу (ТЗ §4.5): сжимает изображение
  /// (StorageService.compress), загружает в приватный бакет Storage,
  /// затем создаёт запись Receipt со ссылкой на файл.
  ///
  /// Путь файла — `<user_id>/<payment_id>/<таймстемп>.jpg`. Префикс
  /// user_id — не для читаемости, а потому что политика доступа к бакету
  /// receipts в Supabase Storage построена на первом сегменте пути
  /// (storage.foldername(name)[1] = auth.uid()), это стандартный для
  /// Supabase Storage способ давать RLS-доступ без join к payments
  /// внутри политики (см. подсказку по созданию бакета в чате). Метка
  /// времени вместо uuid — пакет uuid не заводим, коллизий в пределах
  /// одного платежа одного пользователя практически не бывает.
  Future<Receipt> attach({
    required String paymentId,
    required Uint8List imageBytes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Нет авторизованного пользователя — чек не может быть загружен.');
    }
    final compressed = _storage.compress(imageBytes);
    final path = '$userId/$paymentId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await guardRepositoryCall(() => _storage.upload(compressed, path));

    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.receipts)
          .insert({'payment_id': paymentId, 'file_path': path})
          .select()
          .single(),
    );
    final receipt = Receipt.fromJson(row);
    await _dao.upsert(_toCompanion(receipt));
    return receipt;
  }

  /// Кликабельная ссылка на файл чека (ТЗ §4.5) — подписанная, бакет
  /// приватный, публичного URL нет.
  Future<String> getUrl(Receipt receipt, {int expiresInSeconds = 3600}) {
    return guardRepositoryCall(
      () => _storage.getSignedUrl(
        receipt.filePath,
        expiresInSeconds: expiresInSeconds,
      ),
    );
  }

  ReceiptsCompanion _toCompanion(Receipt r) {
    return ReceiptsCompanion(
      id: Value(r.id),
      paymentId: Value(r.paymentId),
      filePath: Value(r.filePath),
      createdAt: Value(r.createdAt),
    );
  }
}
