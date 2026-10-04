import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

/// Яндекс не вернул access_token в редиректе (пользователь отменил вход,
/// либо неверно настроен Client ID/redirect_uri приложения на
/// oauth.yandex.ru).
class YandexAuthException implements Exception {
  YandexAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// REST API Яндекс.Диска ответил ошибкой (истёк токен, не хватает прав,
/// сеть и т.п.).
class YandexApiException implements Exception {
  YandexApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'Яндекс Диск ответил ошибкой $statusCode: $body';
}

/// OAuth-авторизация и загрузка файлов на Яндекс.Диск через REST API
/// (ТЗ §4.10, Этап 3.11). Хранение полученного access_token (между
/// запусками приложения) — не здесь, это дело экрана «Отчёты» (4.10,
/// уточнение по сравнению с этой заметкой, написанной раньше плана
/// Этапа 4: хранит SettingsService, экран которого — «Настройки», но
/// использует токен именно экран «Отчёты»); сервис только получает
/// токен и умеет им пользоваться.
class YandexDiskService {
  YandexDiskService({required this.clientId, required this.redirectUri});

  final String clientId;
  final String redirectUri;

  static const _authUrl = 'https://oauth.yandex.ru/authorize';
  static const _apiBase = 'https://cloud-api.yandex.net/v1/disk';

  /// Таймаут сетевых операций с Диском — чтобы «Формирование...» не
  /// зависало навсегда при «зависшем» соединении; по истечении — ошибка.
  static const _timeout = Duration(seconds: 30);

  /// Открывает системный браузер/Custom Tabs на странице входа Яндекса
  /// (пакет flutter_web_auth_2 сам перехватывает редирект обратно в
  /// приложение по схеме [redirectUri], см. AndroidManifest.xml) и
  /// возвращает access_token. response_type=token (implicit-flow) — без
  /// client_secret, которому в мобильном приложении негде безопасно
  /// храниться.
  Future<String> authorize() async {
    final scheme = Uri.parse(redirectUri).scheme;
    final authUri = Uri.parse(_authUrl).replace(
      queryParameters: {
        'response_type': 'token',
        'client_id': clientId,
        'redirect_uri': redirectUri,
      },
    );
    final resultUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: scheme,
    );
    // access_token приходит во фрагменте (после #), не в query-параметрах.
    final fragment = Uri.parse(resultUrl).fragment;
    final params = Uri.splitQueryString(fragment);
    final token = params['access_token'];
    if (token == null) {
      throw YandexAuthException(
        'Яндекс не вернул access_token в ответе: $resultUrl',
      );
    }
    return token;
  }

  /// Загружает файл на Диск в папку [folderPath] (создаёт её при
  /// необходимости) под именем [fileName] — двухшаговый REST API
  /// Яндекс.Диска: получить ссылку для загрузки, затем PUT байтов по ней.
  Future<void> uploadFile({
    required String accessToken,
    required String folderPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    await _ensureFolder(accessToken, folderPath);

    final remotePath = '$folderPath/$fileName';
    final linkUri = Uri.parse('$_apiBase/resources/upload').replace(
      queryParameters: {'path': remotePath, 'overwrite': 'true'},
    );
    final linkResponse = await http
        .get(
          linkUri,
          headers: {'Authorization': 'OAuth $accessToken'},
        )
        .timeout(_timeout);
    if (linkResponse.statusCode != 200) {
      throw YandexApiException(linkResponse.statusCode, linkResponse.body);
    }
    final href =
        (jsonDecode(linkResponse.body) as Map<String, dynamic>)['href']
            as String;

    final uploadResponse =
        await http.put(Uri.parse(href), body: bytes).timeout(_timeout);
    if (uploadResponse.statusCode != 201 &&
        uploadResponse.statusCode != 202) {
      throw YandexApiException(
        uploadResponse.statusCode,
        uploadResponse.body,
      );
    }
  }

  /// Клиентская ссылка на файл внутри Диска пользователя — открывается в
  /// браузере/приложении и ведёт на конкретный файл (Этап 5.7). Для файлов
  /// владельца Диска публикация (resources/publish) не нужна и может быть
  /// недоступна приложению (403 Forbidden), поэтому используем этот формат.
  ///
  /// Важно: путь кодируется **посегментно**, а разделители `/` остаются —
  /// иначе весь путь превращается в один сегмент и Диск открывает папку,
  /// а не файл.
  String fileClientUrl(String remotePath) {
    final segments = remotePath
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return 'https://disk.yandex.ru/client/disk/$segments';
  }

  /// Публикует файл по [remotePath] и возвращает публичную ссылку
  /// (`public_url`, вида https://yadi.sk/...), которая открывает сам файл.
  /// Используется, чтобы ссылки в Excel-отчёте вели на конкретный чек, а не
  /// на папку. Если файл уже опубликован — Яндекс вернёт тот же public_url.
  Future<String> getPublicUrl({
    required String accessToken,
    required String remotePath,
  }) async {
    final publishUri = Uri.parse('$_apiBase/resources/publish').replace(
      queryParameters: {'path': remotePath},
    );
    final publishResponse = await http
        .put(
          publishUri,
          headers: {'Authorization': 'OAuth $accessToken'},
        )
        .timeout(_timeout);
    // 200 — ок; 409 — ресурс уже опубликован (тоже ок).
    if (publishResponse.statusCode != 200 &&
        publishResponse.statusCode != 409) {
      throw YandexApiException(
        publishResponse.statusCode,
        publishResponse.body,
      );
    }

    final metaUri = Uri.parse('$_apiBase/resources').replace(
      queryParameters: {'path': remotePath, 'fields': 'public_url'},
    );
    final metaResponse = await http
        .get(
          metaUri,
          headers: {'Authorization': 'OAuth $accessToken'},
        )
        .timeout(_timeout);
    if (metaResponse.statusCode != 200) {
      throw YandexApiException(metaResponse.statusCode, metaResponse.body);
    }
    final publicUrl =
        (jsonDecode(metaResponse.body) as Map<String, dynamic>)['public_url']
            as String?;
    if (publicUrl == null) {
      throw YandexApiException(
        metaResponse.statusCode,
        'Нет public_url в ответе: ${metaResponse.body}',
      );
    }
    return publicUrl;
  }

  /// 201 — папка создана, 409 — уже существует; оба исхода — ок,
  /// остальное — настоящая ошибка.
  Future<void> _ensureFolder(String accessToken, String folderPath) async {
    final uri = Uri.parse(
      '$_apiBase/resources',
    ).replace(queryParameters: {'path': folderPath});
    final response = await http
        .put(
          uri,
          headers: {'Authorization': 'OAuth $accessToken'},
        )
        .timeout(_timeout);
    if (response.statusCode != 201 && response.statusCode != 409) {
      throw YandexApiException(response.statusCode, response.body);
    }
  }
}
