// Unit-тесты перевода ошибок в понятные сообщения (Этап 7, п. 7.1):
// экраны не должны показывать сырой текст исключений (`Invalid argument(s):`,
// `SocketException`, стек, URL) — только чистые русские сообщения.
// Функции чистые (без Flutter-зависимостей, кроме типов Supabase), поэтому
// виджеты не поднимаются.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kommunalka/repositories/repository_exceptions.dart';
import 'package:kommunalka/utils/error_messages.dart';

void main() {
  group('describeError', () {
    test('ArgumentError без префикса Invalid argument(s) — чистый текст', () {
      final result = describeError(ArgumentError('У поставщика нет банковских реквизитов.'));
      expect(result, 'У поставщика нет банковских реквизитов.');
      expect(result.contains('Invalid argument(s)'), isFalse);
    });

    test('NetworkException репозитория отдаётся как есть', () {
      final e = NetworkException(const SocketException('failed'));
      expect(describeError(e), contains('Нет соединения с сервером'));
    });

    test('ServerException репозитория отдаётся как есть', () {
      final e = ServerException('Такая запись уже существует — проверьте, не была ли она внесена ранее.');
      expect(describeError(e), contains('Такая запись уже существует'));
    });

    test('SocketException → сообщение о соединении (без стека)', () {
      final result = describeError(const SocketException('Failed host lookup'));
      expect(result, contains('Нет соединения с сервером'));
      expect(result.contains('SocketException'), isFalse);
    });

    test('TimeoutException → сообщение о соединении', () {
      final result = describeError(TimeoutException('timed out'));
      expect(result, contains('Нет соединения с сервером'));
    });

    test('текстовый маркер failed host lookup распознаётся как сеть', () {
      final result = describeError(Exception('ClientException with SocketException: Failed host lookup: x.supabase.co (errno = 7)'));
      expect(result, contains('Нет соединения с сервером'));
      expect(result.contains('errno'), isFalse);
    });

    test('прочий Exception — снят префикс Exception:', () {
      final result = describeError(Exception('Что-то пошло не так'));
      expect(result, 'Что-то пошло не так');
      expect(result.startsWith('Exception:'), isFalse);
    });

    test('Bad state снимает префикс', () {
      final result = describeError(StateError('Пустое значение'));
      expect(result.contains('Bad state'), isFalse);
    });

    test('пустое исключение → общий текст', () {
      final result = describeError(Exception());
      expect(result, 'Не удалось выполнить операцию. Попробуйте ещё раз.');
    });
  });

  group('describeAuthError', () {
    test('неверные учётные данные → понятное сообщение', () {
      final result = describeAuthError(
        AuthException('Invalid login credentials'),
      );
      expect(result, 'Неверный email или пароль.');
    });

    test('email не подтверждён', () {
      final result = describeAuthError(AuthException('Email not confirmed'));
      expect(result, contains('Email не подтверждён'));
    });

    test('сетевая ошибка (SocketException) → сообщение о соединении', () {
      final result = describeAuthError(const SocketException('Failed host lookup'));
      expect(result, contains('Нет соединения с сервером'));
    });

    test('AuthRetryableFetchException с маркером сети → соединение', () {
      final result = describeAuthError(
        Exception('AuthRetryableFetchException: ClientException with SocketException: Failed host lookup, errno = 7'),
      );
      expect(result, contains('Нет соединения с сервером'));
      expect(result.contains('errno'), isFalse);
    });

    test('прочая ошибка → общий текст, без технических деталей', () {
      final result = describeAuthError(Exception('Unexpected'));
      expect(result, 'Не удалось войти. Попробуйте ещё раз.');
    });
  });
}
