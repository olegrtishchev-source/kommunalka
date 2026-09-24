import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/readings_dao.dart';
import '../models/reading.dart';
import '../services/supabase_tables.dart';
import '../utils/json_parsing.dart';
import 'repository_exceptions.dart';

/// Показание больше предыдущего сохранённого по тому же каналу нельзя
/// внести без явного флага `meterReplaced` (ТЗ §4.2). Сравнение — с
/// последним показанием в локальном кеше, поэтому экран, вызывающий
/// [ReadingRepository.create], должен сначала обновить кеш через
/// [ReadingRepository.refresh] (как и везде — сам вызов освежения решает
/// экран, Этап 4), иначе проверка может ориентироваться на устаревшее
/// значение. Финальная защита целостности всё равно на стороне Supabase —
/// это клиентская подсказка пользователю, а не единственный барьер.
class MeterValueDecreasedException implements Exception {
  MeterValueDecreasedException(this.previousValue, this.attemptedValue);

  final double previousValue;
  final double attemptedValue;

  @override
  String toString() =>
      'Новое показание ($attemptedValue) меньше предыдущего ($previousValue). '
      'Если счётчик был заменён — повторите с meterReplaced: true.';
}

/// Показания счётчиков: чтение — из локального кеша (drift, реактивно),
/// запись — сначала в Supabase, затем в кеш (см. журнал 3.5 — та же схема,
/// что и в SupplierRepository). Сетевые/серверные ошибки — через
/// guardRepositoryCall (Этап 3.9).
///
/// Правило «канал-источник должен иметь показание за период, прежде чем
/// доступен ввод по производному каналу» (ТЗ §4.2) сюда не входит — оно
/// требует знания о Channel.source_channel_id и относится к экрану ввода
/// (Этап 4), а не к хранению самих показаний.
class ReadingRepository {
  ReadingRepository(this._client, this._dao);

  final SupabaseClient _client;
  final ReadingsDao _dao;

  /// История показаний по каналу, от новых к старым (ТЗ §4.2).
  Stream<List<ReadingRow>> watchForChannel(String channelId) =>
      _dao.watchForChannel(channelId);

  /// Последнее показание по каналу — «предыдущее» для формы ввода.
  Future<ReadingRow?> getLatestForChannel(String channelId) =>
      _dao.getLatestForChannel(channelId);

  /// Подтягивает все показания пользователя из Supabase (RLS уже
  /// ограничивает выборку его записями) и обновляет локальный кеш.
  Future<void> refresh() async {
    final rows = await guardRepositoryCall(
      () => _client.from(SupabaseTables.readings).select(),
    );
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      await _dao.upsert(_toCompanion(Reading.fromJson(row)));
    }
  }

  /// Вносит новое показание (ТЗ §4.2). id, user_id, created_at, updated_at —
  /// от Supabase (см. журнал 3.5, тот же приём, что и у Supplier).
  ///
  /// Показания вводятся строго последовательно по времени — «предыдущее»
  /// всегда последнее сохранённое по каналу, задним числом в MVP не
  /// вводится (ТЗ §4.2), поэтому здесь нет параметра «после какой записи
  /// вставить» — только новое значение и дата.
  Future<Reading> create({
    required String channelId,
    required double value,
    required DateTime readingDate,
    bool meterReplaced = false,
  }) async {
    if (!meterReplaced) {
      final previous = await _dao.getLatestForChannel(channelId);
      if (previous != null && value < previous.value) {
        throw MeterValueDecreasedException(previous.value, value);
      }
    }
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.readings)
          .insert({
            'channel_id': channelId,
            'value': value,
            'reading_date': formatDateOnly(readingDate),
            'meter_replaced': meterReplaced,
          })
          .select()
          .single(),
    );
    final reading = Reading.fromJson(row);
    await _dao.upsert(_toCompanion(reading));
    return reading;
  }

  ReadingsCompanion _toCompanion(Reading r) {
    return ReadingsCompanion(
      id: Value(r.id),
      userId: Value(r.userId),
      channelId: Value(r.channelId),
      value: Value(r.value),
      readingDate: Value(r.readingDate),
      meterReplaced: Value(r.meterReplaced),
      createdAt: Value(r.createdAt),
      updatedAt: Value(r.updatedAt),
    );
  }
}
