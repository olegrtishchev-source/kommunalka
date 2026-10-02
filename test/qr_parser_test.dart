// Unit-тесты парсера платёжного QR-кода ГОСТ Р 56042 (ТЗ §4.11, Этап 5 п. 5.9).
// Лицевые счета и адреса в тестовых данных — фиктивные (нули), как и требует
// план: это образцы формата, а не реальные реквизиты.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/utils/qr_parser.dart';

void main() {
  group('parseQrPayment — корректные строки', () {
    test('ST00012 (UTF-8), ЕИРЦ-стиль: разбор полей и кодировка', () {
      final data = parseQrPayment(
        'ST00012|Name=ЕИРЦ|PersonalAcc=40702810000000000000|'
        'BankName=Сбербанк|BIC=044525225|CorrespAcc=30101810400000000225|'
        'PayeeINN=7707083893|KPP=770701001|persAcc=000000000000|'
        'Sum=10000|PaymPeriod=2026.08',
      );
      expect(data.encoding, '2');
      expect(data.fields['name'], 'ЕИРЦ');
      expect(data.fields['personalacc'], '40702810000000000000');
      expect(data.fields['bic'], '044525225');
      expect(data.fields['persacc'], '000000000000');
    });

    test('ST00011 (Windows-1251), ТНС-стиль: есть A3Pay, нет KPP', () {
      final data = parseQrPayment(
        'ST00011|Name=ТНС энерго Кубань|PersonalAcc=40702810000000000000|'
        'BankName=Кубаньбанк|BIC=040349602|CorrespAcc=30101810100000000602|'
        'PayeeINN=2311147226|persAcc=000000000000|'
        'A3Pay=https://a3pay.tns-e.ru/pay',
      );
      expect(data.encoding, '1');
      expect(data.fields['name'], 'ТНС энерго Кубань');
      expect(data.fields['a3pay'], 'https://a3pay.tns-e.ru/pay');
      expect(data.fields.containsKey('kpp'), isFalse);
    });

    test('ST00012, Водопровод-стиль: есть KPP и TechCode', () {
      final data = parseQrPayment(
        'ST00012|Name=Водопровод|PersonalAcc=40702810000000000000|'
        'BankName=Банк|BIC=044525225|PayeeINN=1234567890|KPP=230801001|'
        'persAcc=000000000000|TechCode=05',
      );
      expect(data.fields['kpp'], '230801001');
      expect(data.fields['techcode'], '05');
    });

    test('ключи регистронезависимы: PersAcc и persAcc — один ключ', () {
      final data = parseQrPayment('ST00012|Name=Тест|PersAcc=123456');
      expect(data.fields['persacc'], '123456');
      expect(data.fields.containsKey('PersAcc'), isFalse);
    });

    test('значение отделяется по первому «=» (в ссылке есть ещё «=»)', () {
      final data = parseQrPayment(
        'ST00012|A3Pay=https://cabinet.ru/login?token=abc=def&x=1',
      );
      expect(data.fields['a3pay'], 'https://cabinet.ru/login?token=abc=def&x=1');
    });

    test('неизвестные ключи не ломают разбор', () {
      final data = parseQrPayment(
        'ST00012|Name=Тест|Sum=10000|PaymPeriod=2026.08|Message=Привет|TechCode=99',
      );
      expect(data.fields['name'], 'Тест');
      expect(data.fields['sum'], '10000');
    });
  });

  group('parseQrPayment — негативные случаи', () {
    test('пустая строка → QrParseException', () {
      expect(() => parseQrPayment(''), throwsA(isA<QrParseException>()));
    });

    test('строка не начинается с ST0001 → QrParseException', () {
      expect(
        () => parseQrPayment('http://example.com'),
        throwsA(isA<QrParseException>()),
      );
    });

    test('ссылка (https) → QrParseException', () {
      expect(
        () => parseQrPayment('https://google.com'),
        throwsA(isA<QrParseException>()),
      );
    });

    test('неизвестный код кодировки → QrParseException', () {
      expect(
        () => parseQrPayment('ST00019|Name=Тест'),
        throwsA(isA<QrParseException>()),
      );
    });
  });

  group('decodeQrBytes', () {
    test('ST00012 (UTF-8) → строка с кириллицей без изменений', () {
      final decoded = decodeQrBytes(utf8.encode('ST00012|Name=ЕИРЦ'));
      expect(decoded, 'ST00012|Name=ЕИРЦ');
    });

    test('ST00011 (Windows-1251) → кириллица декодируется корректно', () {
      // "ST00011|Name=ТНС" в cp1251 (Т=0xD2, Н=0xCD, С=0xD1).
      final bytes = <int>[
        0x53, 0x54, 0x30, 0x30, 0x30, 0x31, // ST0001
        0x31, // кодировка 1 (Windows-1251)
        0x7C, // |
        0x4E, 0x61, 0x6D, 0x65, 0x3D, // Name=
        0xD2, 0xCD, 0xD1, // ТНС
      ];
      expect(decodeQrBytes(bytes), 'ST00011|Name=ТНС');
    });

    test('не-QR байты → UTF-8', () {
      expect(decodeQrBytes(utf8.encode('привет')), 'привет');
    });
  });
}
