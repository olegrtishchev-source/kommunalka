import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/channel.dart';
import '../models/payment.dart';
import '../models/reading.dart';
import '../models/supplier.dart';
import '../services/backup_service.dart';
import '../services/supabase_tables.dart';
import 'repository_exceptions.dart';

/// Итог импорта — что реально записалось, для сообщения пользователю.
class BackupImportResult {
  const BackupImportResult({
    required this.suppliers,
    required this.channels,
    required this.readings,
    required this.payments,
  });

  final int suppliers;
  final int channels;
  final int readings;
  final int payments;

  int get total => suppliers + channels + readings + payments;
}

/// Экспорт/импорт резервной копии (ТЗ §4.9) поверх Supabase — источник
/// истины, как и у остальных репозиториев (см. журнал 3.5/3.6). Сетевые и
/// серверные ошибки — через guardRepositoryCall (Этап 3.9).
///
/// Экспорт читает записи пользователя из облака (RLS ограничивает выборку
/// его строками). Импорт записывает с сохранением `id` (иначе потерялись бы
/// связи supplier→channel→reading/payment) и проставлением текущего
/// `user_id`: копия могла прийти из другого аккаунта, а данные всегда должны
/// принадлежать вошедшему пользователю.
///
/// Файлы чеков в копию не входят (ТЗ §4.9) и при импорте не восстанавливаются.
class BackupRepository {
  BackupRepository(this._client);

  final SupabaseClient _client;

  /// Читает все данные текущего пользователя из Supabase и собирает
  /// [BackupData]. [receipts] намеренно не читаются (ТЗ §4.9).
  Future<BackupData> exportData() async {
    final rows = await Future.wait([
      guardRepositoryCall(
        () => _client.from(SupabaseTables.suppliers).select(),
      ),
      guardRepositoryCall(
        () => _client.from(SupabaseTables.channels).select(),
      ),
      guardRepositoryCall(
        () => _client.from(SupabaseTables.readings).select(),
      ),
      guardRepositoryCall(
        () => _client.from(SupabaseTables.payments).select(),
      ),
    ]);
    return BackupData(
      suppliers: _mapList(rows[0], Supplier.fromJson),
      channels: _mapList(rows[1], Channel.fromJson),
      readings: _mapList(rows[2], Reading.fromJson),
      payments: _mapList(rows[3], Payment.fromJson),
    );
  }

  /// Записывает данные резервной копии в Supabase. Порядок — по связям FK:
  /// поставщики → каналы → показания/платежи. Используется upsert по `id`,
  /// поэтому повторный импорт той же копии не создаёт дубликатов, а
  /// обновляет записи (поставщик с `id` из копии перезапишется).
  ///
  /// `user_id` берётся из текущей сессии, а не из файла: даже если копия
  /// снята с другого аккаунта, после импорта данные принадлежат вошедшему.
  Future<BackupImportResult> importData(BackupData data) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw ServerException('Нет активной сессии — войдите и повторите импорт.');
    }

    await guardRepositoryCall(() async {
      if (data.suppliers.isNotEmpty) {
        await _client.from(SupabaseTables.suppliers).upsert(
              data.suppliers
                  .map((s) => {...s.toJson(), 'user_id': userId})
                  .toList(),
            );
      }
      if (data.channels.isNotEmpty) {
        await _client.from(SupabaseTables.channels).upsert(
              data.channels
                  .map((c) => {...c.toJson(), 'user_id': userId})
                  .toList(),
            );
      }
      if (data.readings.isNotEmpty) {
        await _client.from(SupabaseTables.readings).upsert(
              data.readings
                  .map((r) => {...r.toJson(), 'user_id': userId})
                  .toList(),
            );
      }
      if (data.payments.isNotEmpty) {
        await _client.from(SupabaseTables.payments).upsert(
              data.payments
                  .map((p) => {...p.toJson(), 'user_id': userId})
                  .toList(),
            );
      }
    });

    return BackupImportResult(
      suppliers: data.suppliers.length,
      channels: data.channels.length,
      readings: data.readings.length,
      payments: data.payments.length,
    );
  }

  /// Приводит ответ Supabase к списку доменных моделей.
  List<T> _mapList<T>(
    Object? raw,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return List<Map<String, dynamic>>.from(raw as List)
        .map(fromJson)
        .toList();
  }
}
