import 'dart:async';

import 'package:http/http.dart' as http;

/// HTTP-клиент с таймаутом на каждый запрос — обёртка над [http.Client],
/// передаётся в `Supabase.initialize(httpClient: ...)`.
///
/// Зачем: штатный HTTP-клиент Supabase не имеет таймаута и при «зависшем»
/// соединении запрос может не завершиться никогда — экран навсегда остаётся
/// на индикаторе загрузки (наблюдалось на экранах «Отчёты» и «Оплата»).
/// Здесь каждый запрос ограничен [timeout]; по истечении бросается
/// [TimeoutException], который `guardRepositoryCall` переводит в
/// NetworkException с понятным сообщением (ТЗ §5 — приложение переживает
/// потерю соединения без потери данных).
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient({http.Client? inner, this.timeout = const Duration(seconds: 30)})
      : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() {
    _inner.close();
  }
}
