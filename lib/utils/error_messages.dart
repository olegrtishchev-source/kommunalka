/// Перевод технических исключений в понятные пользователю сообщения
/// (Этап 7, п. 7.1 — «Обработка пограничных случаев»). Одна точка правды:
/// экраны не показывают сырой `toString()` исключения (в нём видны стек,
/// URL, префиксы вроде `Invalid argument(s):`, `SocketException`, `errno`),
/// а вызывают эти функции.
///
/// Доменные исключения репозиториев (`NetworkException`, `ServerException`)
/// уже содержат готовый русский текст — их `toString()` возвращается как есть.
library;

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/repository_exceptions.dart';

/// Технические префиксы, которые Dart добавляет к описанию исключения
/// (`ArgumentError` → `Invalid argument(s): …`, и т.п.) — их нужно снять,
/// пользователю нужен только текст причины.
const _technicalPrefixes = <String>[
  'Invalid argument(s): ',
  'Invalid argument(s):',
  'Exception: ',
  'Bad state: ',
];

/// Снимает технический префикс с текста исключения (если он есть).
String _stripTechnicalPrefix(String text) {
  var result = text.trim();
  for (final prefix in _technicalPrefixes) {
    if (result.startsWith(prefix)) {
      result = result.substring(prefix.length).trim();
      break;
    }
  }
  return result;
}

/// Признак сетевой ошибки любого уровня (`SocketException`, ошибка хоста,
/// таймаут) — по типу или по тексту: supabase_flutter оборачивает сетевые
/// сбои в собственные типы (`AuthRetryableFetchException`), но в тексте
/// остаются узнаваемые маркеры.
bool _isNetworkError(Object e) {
  if (e is SocketException || e is TimeoutException) return true;
  final text = e.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('no address associated with hostname') ||
      text.contains('connection refused') ||
      text.contains('connection closed') ||
      text.contains('connection reset') ||
      text.contains('network is unreachable') ||
      text.contains('failed to fetch') ||
      text.contains('clientexception') ||
      text.contains('timed out') ||
      text.contains('timeout');
}

/// Сообщение об ошибке входа (экран «Вход», ТЗ §3). Различает сетевую
/// ошибку и неверные данные; для остального — общее понятное сообщение.
String describeAuthError(Object e) {
  if (e is AuthException) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_grant')) {
      return 'Неверный email или пароль.';
    }
    if (message.contains('email not confirmed')) {
      return 'Email не подтверждён. Проверьте почту.';
    }
    if (_isNetworkError(e)) {
      return 'Нет соединения с сервером. Проверьте интернет и попробуйте снова.';
    }
    // Прочие AuthException — сообщение Supabase уже осмысленно, но без обёртки.
    final cleanMessage = _stripTechnicalPrefix(e.message);
    if (cleanMessage.isEmpty || cleanMessage == 'Exception') {
      return 'Не удалось войти. Попробуйте ещё раз.';
    }
    return cleanMessage;
  }
  if (_isNetworkError(e)) {
    return 'Нет соединения с сервером. Проверьте интернет и попробуйте снова.';
  }
  return 'Не удалось войти. Попробуйте ещё раз.';
}

/// Общее сообщение об ошибке для выполнения операции (сохранение, удаление,
/// построение QR, загрузка). Отдаёт готовый текст доменных исключений
/// репозиториев, распознаёт `ArgumentError`/сетевые сбои, снимает технические
/// префиксы и никогда не показывает «голый» стек.
String describeError(Object e) {
  // Доменные исключения уже несут понятный русский текст.
  if (e is NetworkException || e is ServerException) return e.toString();

  if (e is ArgumentError) {
    final message = e.message?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return _stripTechnicalPrefix(message);
    }
    return 'Операция не выполнена: некорректные данные.';
  }

  if (_isNetworkError(e)) {
    return 'Нет соединения с сервером. Проверьте интернет и попробуйте снова.';
  }

  final text = _stripTechnicalPrefix(e.toString());
  if (text.isEmpty || text == 'Exception') {
    return 'Не удалось выполнить операцию. Попробуйте ещё раз.';
  }
  return text;
}
