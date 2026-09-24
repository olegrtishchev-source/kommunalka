import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Запрос не дошёл до сервера — нет интернета, таймаут, DNS и т.п.
/// (ТЗ §5: приложение должно переживать потерю соединения без потери
/// данных — это тот случай, когда repository честно сообщает «не сейчас»
/// вместо непонятного низкоуровневого исключения).
class NetworkException implements Exception {
  NetworkException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'Нет соединения с сервером. Проверьте интернет и попробуйте снова.';
}

/// Запрос дошёл, но Supabase ответил ошибкой — RLS запретил операцию,
/// нарушено ограничение БД, файл не найден в Storage и т.п.
class ServerException implements Exception {
  ServerException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Общая обёртка для сетевых вызовов во всех репозиториях (ТЗ, Этап 3.9) —
/// переводит низкоуровневые исключения Supabase/сети в NetworkException/
/// ServerException. Не перехватывает и не должна перехватывать доменные
/// исключения самих репозиториев (MeterValueDecreasedException,
/// ChannelHasReadingsException и т.п.) — они бросаются до сетевого вызова
/// и в guardRepositoryCall не попадают.
///
/// Базовый уровень (как и назван пункт плана) — распознаются самые частые
/// случаи (нет сети, ошибка Postgres/Storage/Auth), а не исчерпывающий
/// список; исключение типа, которого нет ни в одном catch, проходит
/// насквозь необёрнутым.
Future<T> guardRepositoryCall<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on SocketException catch (e) {
    throw NetworkException(e);
  } on TimeoutException catch (e) {
    throw NetworkException(e);
  } on PostgrestException catch (e) {
    throw ServerException(_translatePostgrestError(e), cause: e);
  } on StorageException catch (e) {
    throw ServerException(e.message, cause: e);
  } on AuthException catch (e) {
    throw ServerException(e.message, cause: e);
  }
}

/// Postgres code 23505 — unique_violation; в проекте это readings
/// (channel_id, reading_date) и payments (supplier_id, period)
/// (см. supabase/schema.sql) — оба случая по смыслу одно и то же:
/// запись за этот период/дату уже есть.
String _translatePostgrestError(PostgrestException e) {
  if (e.code == '23505') {
    return 'Такая запись уже существует — проверьте, не была ли она внесена ранее.';
  }
  // На это удаление уже есть ссылки, БД отказала (пример — попытка
  // удалить канал, у которого параллельно появилось показание, см.
  // ChannelRepository.delete и его клиентскую проверку заранее).
  if (e.code == '23503') {
    return 'Нельзя удалить — на эту запись ссылаются другие данные.';
  }
  return e.message;
}
