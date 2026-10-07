// Unit-тесты резервного копирования JSON (ТЗ §4.9, Этап 7 п. 7.2):
// построение копии и разбор — чистые функции без сети и Flutter.

import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/models/channel.dart';
import 'package:kommunalka/models/payment.dart';
import 'package:kommunalka/models/reading.dart';
import 'package:kommunalka/models/supplier.dart';
import 'package:kommunalka/services/backup_service.dart';

Supplier _supplier({String id = 's1'}) => Supplier(
      id: id,
      userId: 'u1',
      name: 'Водоканал',
      category: 'Вода',
      type: SupplierType.withReadings,
      bankDetails: const BankDetails(recipient: 'МУП Водоканал', inn: '1234567890'),
      personalAccount: '12345',
      readingMethods: const ['cabinet'],
      cabinetUrl: 'https://lk.example',
      readingEmail: 'lk@example.com',
      address: 'ул. Тестовая, 1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Channel _channel({String id = 'c1'}) => Channel(
      id: id,
      userId: 'u1',
      supplierId: 's1',
      name: 'ХВС',
      unit: 'м³',
      tariff: 42.5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Reading _reading({String id = 'r1'}) => Reading(
      id: id,
      userId: 'u1',
      channelId: 'c1',
      value: 123.4,
      readingDate: DateTime(2026, 2, 1),
      meterReplaced: false,
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 1),
    );

Payment _payment({String id = 'p1'}) => Payment(
      id: id,
      userId: 'u1',
      supplierId: 's1',
      period: DateTime(2026, 2, 1),
      calculatedAmount: 500.0,
      actualAmount: 500.0,
      status: PaymentStatus.paid,
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 1),
    );

void main() {
  group('buildBackup + parseBackup', () {
    test('полный цикл: сборка копии и разбор дают те же данные', () {
      final json = buildBackup(
        suppliers: [_supplier()],
        channels: [_channel()],
        readings: [_reading()],
        payments: [_payment()],
        exportedAt: DateTime(2026, 10, 7, 12, 0),
      );
      final data = parseBackup(json);

      expect(data.suppliers.length, 1);
      expect(data.channels.length, 1);
      expect(data.readings.length, 1);
      expect(data.payments.length, 1);
      expect(data.totalRecords, 4);

      final s = data.suppliers.first;
      expect(s.name, 'Водоканал');
      expect(s.category, 'Вода');
      expect(s.personalAccount, '12345');
      expect(s.readingMethods, ['cabinet']);
      expect(s.address, 'ул. Тестовая, 1');
      expect(s.bankDetails?.recipient, 'МУП Водоканал');

      expect(data.channels.first.tariff, 42.5);
      expect(data.readings.first.value, 123.4);
      expect(data.payments.first.status, PaymentStatus.paid);
      expect(data.payments.first.calculatedAmount, 500.0);
    });

    test('в копии есть метаданные формата и версии', () {
      final json = buildBackup(
        suppliers: const [],
        channels: const [],
        readings: const [],
        payments: const [],
        exportedAt: DateTime(2026, 10, 7),
      );
      expect(json.contains('"format": "$backupFormat"'), isTrue);
      expect(json.contains('"version": $backupVersion'), isTrue);
      expect(json.contains('"exported_at"'), isTrue);
    });

    test('пустая копия разбирается без ошибок, isEmpty = true', () {
      final json = buildBackup(
        suppliers: const [],
        channels: const [],
        readings: const [],
        payments: const [],
        exportedAt: DateTime(2026, 10, 7),
      );
      final data = parseBackup(json);
      expect(data.isEmpty, isTrue);
      expect(data.totalRecords, 0);
    });

    test('не JSON → BackupFormatException', () {
      expect(() => parseBackup('не json'), throwsA(isA<BackupFormatException>()));
    });

    test('чужой JSON (нет format) → BackupFormatException', () {
      expect(
        () => parseBackup('{"hello": "world"}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('другой формат (не kommunalka-backup) → BackupFormatException', () {
      expect(
        () => parseBackup('{"format": "other-app", "version": 1}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('более новая версия формата → BackupFormatException', () {
      final json = '{"format": "$backupFormat", "version": ${backupVersion + 1}}';
      expect(() => parseBackup(json), throwsA(isA<BackupFormatException>()));
    });

    test('совместимость: отсутствующие списки трактуются как пустые', () {
      final json = '{"format": "$backupFormat", "version": 1}';
      final data = parseBackup(json);
      expect(data.suppliers, isEmpty);
      expect(data.channels, isEmpty);
      expect(data.readings, isEmpty);
      expect(data.payments, isEmpty);
    });

    test('повреждённая запись в списке → BackupFormatException', () {
      final json = '{"format": "$backupFormat", "version": 1, '
          '"suppliers": [{"нет": "полей"}]}';
      expect(() => parseBackup(json), throwsA(isA<BackupFormatException>()));
    });
  });
}
