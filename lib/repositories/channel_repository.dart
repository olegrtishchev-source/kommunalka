import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/channels_dao.dart';
import '../database/daos/readings_dao.dart';
import '../models/channel.dart';
import '../services/supabase_tables.dart';
import 'repository_exceptions.dart';

/// Канал с сохранёнными показаниями нельзя удалить — доступно только
/// переименование/редактирование (ТЗ §4.1). То же самое ограничение
/// продублировано на уровне Supabase (readings.channel_id ... on delete
/// restrict, см. supabase/schema.sql) — эта проверка лишь даёт понятную
/// ошибку до сетевого запроса, а не единственный барьер.
class ChannelHasReadingsException implements Exception {
  ChannelHasReadingsException(this.channelId);

  final String channelId;

  @override
  String toString() =>
      'У канала $channelId уже есть сохранённые показания — удаление '
      'недоступно (ТЗ §4.1), доступно только переименование/редактирование.';
}

/// Каналы показаний поставщика: чтение — из локального кеша (drift,
/// реактивно), запись — сначала в Supabase, потом в кеш (та же схема,
/// что и в SupplierRepository/ReadingRepository, см. журнал 3.5/3.6).
/// Сетевые/серверные ошибки — через guardRepositoryCall (Этап 3.9).
class ChannelRepository {
  ChannelRepository(this._client, this._dao, this._readingsDao);

  final SupabaseClient _client;
  final ChannelsDao _dao;
  final ReadingsDao _readingsDao;

  /// Каналы поставщика (ТЗ §4.1 — их может быть несколько на поставщика).
  Stream<List<ChannelRow>> watchForSupplier(String supplierId) =>
      _dao.watchForSupplier(supplierId);

  Future<ChannelRow?> getById(String id) => _dao.getById(id);

  /// Подтягивает все каналы пользователя из Supabase (RLS уже ограничивает
  /// выборку его записями) и обновляет локальный кеш.
  Future<void> refresh() async {
    final rows = await guardRepositoryCall(
      () => _client.from(SupabaseTables.channels).select(),
    );
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      await _dao.upsert(_toCompanion(Channel.fromJson(row)));
    }
  }

  /// Создаёт канал (ТЗ §4.1). [sourceChannelId] заполняется только для
  /// производного канала — расход берётся из канала-источника (в т.ч.
  /// у другого поставщика), собственных показаний у такого канала нет.
  /// id/user_id/created_at/updated_at — от Supabase (см. журнал 3.5).
  Future<Channel> create({
    required String supplierId,
    required String name,
    required String unit,
    required double tariff,
    String? sourceChannelId,
  }) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.channels)
          .insert({
            'supplier_id': supplierId,
            'name': name,
            'unit': unit,
            'tariff': tariff,
            'source_channel_id': sourceChannelId,
          })
          .select()
          .single(),
    );
    final channel = Channel.fromJson(row);
    await _dao.upsert(_toCompanion(channel));
    return channel;
  }

  /// Переименование/редактирование канала (ТЗ §4.1) — supplier_id не
  /// входит в обновляемые поля: перенос канала между поставщиками не
  /// описан в ТЗ как сценарий.
  Future<Channel> update(Channel channel) async {
    final row = await guardRepositoryCall(
      () => _client
          .from(SupabaseTables.channels)
          .update({
            'name': channel.name,
            'unit': channel.unit,
            'tariff': channel.tariff,
            'source_channel_id': channel.sourceChannelId,
          })
          .eq('id', channel.id)
          .select()
          .single(),
    );
    final updated = Channel.fromJson(row);
    await _dao.upsert(_toCompanion(updated));
    return updated;
  }

  /// Удаляет канал — только если по нему ещё нет ни одного показания
  /// (ТЗ §4.1). Проверка — по локальному кешу; см. класс
  /// [ChannelHasReadingsException] о том, почему это не единственная
  /// защита.
  Future<void> delete(String id) async {
    if (await _readingsDao.hasAnyForChannel(id)) {
      throw ChannelHasReadingsException(id);
    }
    await guardRepositoryCall(
      () => _client.from(SupabaseTables.channels).delete().eq('id', id),
    );
    await _dao.deleteById(id);
  }

  ChannelsCompanion _toCompanion(Channel c) {
    return ChannelsCompanion(
      id: Value(c.id),
      userId: Value(c.userId),
      supplierId: Value(c.supplierId),
      name: Value(c.name),
      unit: Value(c.unit),
      tariff: Value(c.tariff),
      sourceChannelId: Value(c.sourceChannelId),
      createdAt: Value(c.createdAt),
      updatedAt: Value(c.updatedAt),
    );
  }
}
