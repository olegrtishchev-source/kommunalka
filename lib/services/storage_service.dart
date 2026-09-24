import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Не удалось распознать/сжать переданные байты как изображение.
class ReceiptCompressionException implements Exception {
  ReceiptCompressionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Сжатие и загрузка файлов чеков в Supabase Storage (ТЗ §4.5). Чисто
/// техническая обёртка над Storage API — привязка чека к платежу
/// (создание строки Receipt) не здесь, это дело ReceiptRepository.
class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  static const _bucket = 'receipts';
  /// Целевой размер файла после сжатия (ТЗ §4.5: «не более ~500 КБ»).
  static const _targetBytes = 500 * 1024;
  /// Длинная сторона после уменьшения разрешения — для фото с телефона
  /// (обычно 3000+ px) этого достаточно, чтобы чек оставался читаемым.
  static const _maxDimension = 1600;

  /// Уменьшает разрешение (если длинная сторона больше [_maxDimension]),
  /// затем подбирает качество JPEG, пока файл не уложится в целевой
  /// размер или качество не упрётся в разумный минимум (30 — дальше
  /// сжимать бессмысленно, чек станет нечитаемым).
  Uint8List compress(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) {
      throw ReceiptCompressionException(
        'Не удалось распознать изображение чека.',
      );
    }

    var image = decoded;
    if (image.width > _maxDimension || image.height > _maxDimension) {
      final wider = image.width >= image.height;
      image = img.copyResize(
        image,
        width: wider ? _maxDimension : null,
        height: wider ? null : _maxDimension,
      );
    }

    var quality = 85;
    var encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    while (encoded.lengthInBytes > _targetBytes && quality > 30) {
      quality -= 15;
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
    return encoded;
  }

  /// Загружает уже сжатые байты по указанному пути внутри бакета,
  /// возвращает тот же путь (это и есть Receipt.file_path, ТЗ §7).
  Future<String> upload(Uint8List bytes, String path) async {
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  /// Временная подписанная ссылка на файл — бакет приватный (ТЗ §5:
  /// доступ только из личного аккаунта, публичного URL нет). По умолчанию
  /// час — для показа в приложении; при выгрузке в Excel-отчёт (Этап 3.10)
  /// вызывающий код передаст больший срок действия.
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) {
    return _client.storage.from(_bucket).createSignedUrl(
          path,
          expiresInSeconds,
        );
  }
}
