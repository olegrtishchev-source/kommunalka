/// Парсер платёжного QR-кода по ГОСТ Р 56042 (ТЗ §4.11, Этап 5 п. 5.9).
///
/// Формат строки: ST0001x|Ключ=Значение|Ключ=Значение|...
/// где x — код кодировки значений (1 — Windows-1251, 2 — UTF-8, 3 — KOI8-R).
/// Пары разделены «|», ключ от значения отделён первым знаком «=».
/// Ключи регистронезависимы (persAcc и PersAcc — один ключ) и приводятся
/// к нижнему регистру. Неизвестные ключи не ломают разбор — они просто
/// сохраняются в fields, нужные выбирает вызывающий код (форма, п. 5.10).
library;

/// Строка не является платёжным QR ГОСТ Р 56042 (не начинается с ST0001).
class QrParseException implements Exception {
  QrParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Результат разбора платёжного QR-кода ГОСТ Р 56042.
class QrPaymentData {
  const QrPaymentData({required this.encoding, required this.fields});

  /// Код кодировки из заголовка: '1' — Windows-1251, '2' — UTF-8, '3' — KOI8-R.
  /// Нужен для корректного чтения кириллицы при сканировании (ТЗ §4.11);
  /// сам парсер принимает уже декодированную строку и значения не
  /// перекодирует — это делается на этапе получения байтов (п. 5.10).
  final String encoding;

  /// Разобранные пары: ключ в нижнем регистре → значение.
  final Map<String, String> fields;
}

/// Разбирает строку платёжного QR-кода ГОСТ Р 56042.
///
/// Возвращает [QrPaymentData] с кодом кодировки и парами «ключ → значение».
/// Бросает [QrParseException], если строка не начинается с ST0001 или код
/// кодировки неизвестен (ТЗ §4.11 — «QR не распознан»).
QrPaymentData parseQrPayment(String qr) {
  if (qr.length < 7 || !qr.startsWith('ST0001')) {
    throw QrParseException('QR не распознан: строка не начинается с ST0001.');
  }
  final encoding = qr.substring(6, 7);
  if (encoding != '1' && encoding != '2' && encoding != '3') {
    throw QrParseException(
      'QR не распознан: неизвестный код кодировки «$encoding».',
    );
  }

  final fields = <String, String>{};
  final parts = qr.substring(7).split('|');
  for (final part in parts) {
    final eqIndex = part.indexOf('=');
    if (eqIndex <= 0) {
      // нет знака «=» или пустой ключ — пропускаем, разбор не падает.
      continue;
    }
    final key = part.substring(0, eqIndex).trim().toLowerCase();
    final value = part.substring(eqIndex + 1);
    if (key.isEmpty) continue;
    fields[key] = value;
  }

  return QrPaymentData(encoding: encoding, fields: fields);
}
