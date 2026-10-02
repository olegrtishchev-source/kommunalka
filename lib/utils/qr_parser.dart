/// Парсер платёжного QR-кода по ГОСТ Р 56042 (ТЗ §4.11, Этап 5 п. 5.9).
///
/// Формат строки: ST0001x|Ключ=Значение|Ключ=Значение|...
/// где x — код кодировки значений (1 — Windows-1251, 2 — UTF-8, 3 — KOI8-R).
/// Пары разделены «|», ключ от значения отделён первым знаком «=».
/// Ключи регистронезависимы (persAcc и PersAcc — один ключ) и приводятся
/// к нижнему регистру. Неизвестные ключи не ломают разбор — они просто
/// сохраняются в fields, нужные выбирает вызывающий код (форма, п. 5.10).
library;

import 'dart:convert';

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

/// Декодирует сырые байты платёжного QR в строку с учётом кодировки из
/// заголовка ГОСТ Р 56042 (ST0001x, ТЗ §4.11): 1 — Windows-1251, 2 — UTF-8,
/// 3 — KOI8-R. Нужно для корректной кириллицы: сканер камеры возвращает
/// сырые байты, а в заголовке указана кодировка, в которой закодированы
/// значения (у ТНС энерго — ST00011, cp1251). Байты, не являющиеся
/// платёжным QR, декодируются как UTF-8.
String decodeQrBytes(List<int> bytes) {
  if (bytes.length < 7 || !_isSt0001Header(bytes)) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  final encoding = String.fromCharCode(bytes[6]);
  switch (encoding) {
    case '1':
      return _decodeCp1251(bytes);
    case '3':
      return _decodeKoi8r(bytes);
    default:
      return utf8.decode(bytes, allowMalformed: true);
  }
}

bool _isSt0001Header(List<int> bytes) {
  const header = 'ST0001';
  if (bytes.length < header.length) return false;
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header.codeUnitAt(i)) return false;
  }
  return true;
}

/// Windows-1251: кириллица А-я (0xC0-0xFF) — сдвигом +0x350, Ё/ё (0xA8/0xB8),
/// ASCII (0x00-0x7F) — напрямую; прочие спецсимволы — U+FFFD (в квитанциях
/// не встречаются).
String _decodeCp1251(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80) {
      sb.writeCharCode(b);
    } else if (b == 0xA8) {
      sb.write('Ё');
    } else if (b == 0xB8) {
      sb.write('ё');
    } else if (b >= 0xC0) {
      sb.writeCharCode(b + 0x350);
    } else {
      sb.writeCharCode(0xFFFD);
    }
  }
  return sb.toString();
}

/// Кириллица KOI8-R (0xC0-0xFF) в нестандартном порядке; прочие байты
/// (0x80-0xBF, спецсимволы) — U+FFFD.
const _koi8rCyrillic =
    'юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ';

String _decodeKoi8r(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80) {
      sb.writeCharCode(b);
    } else if (b >= 0xC0) {
      sb.write(_koi8rCyrillic[b - 0xC0]);
    } else {
      sb.writeCharCode(0xFFFD);
    }
  }
  return sb.toString();
}
