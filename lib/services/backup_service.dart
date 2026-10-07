/// Резервное копирование данных в JSON (ТЗ §4.9): экспорт всех данных
/// пользователя (поставщики, каналы, показания, платежи) в один файл и
/// импорт из него — на случай потери доступа к аккаунту Supabase или
/// необходимости восстановить данные вручную.
///
/// Файлы чеков (Supabase Storage) НЕ входят в резервную копию — ТЗ §4.9
/// прямо исключает их; экспортируются только записи. Поле `receipts` в
/// копию не пишется, но при импорте отсутствие чеков ожидаемо.
///
/// Здесь — только чистая логика (построение и разбор JSON), без сети и
/// Flutter: запись/чтение через Supabase и файловые операции делает экран
/// (Настройки), а этот сервис легко покрыть unit-тестами.
library;

import 'dart:convert';

import '../models/channel.dart';
import '../models/payment.dart';
import '../models/reading.dart';
import '../models/supplier.dart';

/// Идентификатор формата — защита от импорта «чужого» JSON.
const backupFormat = 'kommunalka-backup';

/// Текущая версия формата. При несовместимых изменениях структур — растёт,
/// а [parseBackup] честно откажется разбирать более новую версию.
const backupVersion = 1;

/// Исключение разбора резервной копии — файл не наш, повреждён или версия
/// формата не поддерживается. Экран показывает пользователю текст как есть.
class BackupFormatException implements Exception {
  BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Разобранное содержимое резервной копии — доменные модели, готовые к
/// импорту (с id и связями; user_id при импорте заменяется на текущего).
class BackupData {
  const BackupData({
    required this.suppliers,
    required this.channels,
    required this.readings,
    required this.payments,
  });

  final List<Supplier> suppliers;
  final List<Channel> channels;
  final List<Reading> readings;
  final List<Payment> payments;

  int get totalRecords =>
      suppliers.length + channels.length + readings.length + payments.length;

  bool get isEmpty => totalRecords == 0;
}

/// Собирает строку JSON резервной копии из готовых списков моделей.
/// [exportedAt] выносится параметром — в тестах не хочется зависеть от
/// текущего времени.
String buildBackup({
  required List<Supplier> suppliers,
  required List<Channel> channels,
  required List<Reading> readings,
  required List<Payment> payments,
  required DateTime exportedAt,
}) {
  final data = <String, dynamic>{
    'format': backupFormat,
    'version': backupVersion,
    'exported_at': exportedAt.toIso8601String(),
    'suppliers': suppliers.map((s) => s.toJson()).toList(),
    'channels': channels.map((c) => c.toJson()).toList(),
    'readings': readings.map((r) => r.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };
  // withIndent — файл читаемый человеком (может пригодиться при ручном
  // восстановлении, ТЗ §4.9); объём небольшой, компактность не критична.
  return const JsonEncoder.withIndent('  ').convert(data);
}

/// Разбирает строку JSON резервной копии в [BackupData]. Бросает
/// [BackupFormatException] с понятным русским текстом, если файл не является
/// резервной копией Kommunalka, повреждён или создан более новой версией.
BackupData parseBackup(String jsonText) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException {
    throw BackupFormatException('Файл не является корректным JSON.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw BackupFormatException('Неверный формат файла резервной копии.');
  }
  if (decoded['format'] != backupFormat) {
    throw BackupFormatException(
      'Это не файл резервной копии Kommunalka.',
    );
  }
  final version = decoded['version'];
  if (version is! int) {
    throw BackupFormatException('В файле не указана версия формата.');
  }
  if (version > backupVersion) {
    throw BackupFormatException(
      'Файл создан более новой версией приложения (формат $version, '
      'поддерживается до $backupVersion). Обновите приложение.',
    );
  }

  return BackupData(
    suppliers: _parseList(decoded['suppliers'], Supplier.fromJson),
    channels: _parseList(decoded['channels'], Channel.fromJson),
    readings: _parseList(decoded['readings'], Reading.fromJson),
    payments: _parseList(decoded['payments'], Payment.fromJson),
  );
}

/// Разбирает массив объектов через [fromJson]. Отсутствующее или null-поле
/// трактуется как пустой список (совместимость с более старыми копиями,
/// где какой-то сущности ещё не было). Ошибка структуры — [BackupFormatException].
List<T> _parseList<T>(
  Object? raw,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (raw == null) return <T>[];
  if (raw is! List) {
    throw BackupFormatException('Повреждённый файл: ожидался список записей.');
  }
  try {
    return raw
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e) {
    throw BackupFormatException('Повреждённая запись в файле резервной копии.');
  }
}
