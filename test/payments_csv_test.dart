// Unit-тесты CSV-выгрузки истории платежей (ТЗ §4.6, Этап 7 п. 7.3).

import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/models/payment.dart';
import 'package:kommunalka/models/supplier.dart';
import 'package:kommunalka/services/excel_report_service.dart';
import 'package:kommunalka/utils/payments_csv.dart';

Supplier _supplier({
  String name = 'Водоканал',
  String? address = 'ул. Тестовая, 1',
}) =>
    Supplier(
      id: 's1',
      userId: 'u1',
      name: name,
      category: 'Вода',
      type: SupplierType.withReadings,
      address: address,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Payment _payment({
  double calculated = 500.0,
  double? actual,
  PaymentStatus status = PaymentStatus.paid,
  DateTime? paymentDate,
  double? consumption,
  List<ReadingSnapshotEntry>? snapshot,
}) =>
    Payment(
      id: 'p1',
      userId: 'u1',
      supplierId: 's1',
      period: DateTime(2026, 2, 1),
      readingSnapshot: snapshot,
      consumption: consumption,
      calculatedAmount: calculated,
      actualAmount: actual,
      status: status,
      paymentDate: paymentDate,
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 1),
    );

PaymentsCsvEntry _entry({Payment? payment, Supplier? supplier, DateTime? period}) =>
    PaymentsCsvEntry(
      period: period ?? DateTime(2026, 2, 1),
      row: ExcelReportRow.fromPaymentAndSupplier(
        supplier ?? _supplier(),
        payment ?? _payment(),
      ),
    );

void main() {
  group('buildPaymentsCsv', () {
    test('заголовки: разделитель «;», BOM, «Период» первым', () {
      final csv = buildPaymentsCsv([_entry()]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      final header = csv.split('\n').first.replaceFirst('\uFEFF', '');
      expect(header.split(';').first, 'Период');
      expect(header.contains('Поставщик'), isTrue);
      expect(header.contains('Статус'), isTrue);
    });

    test('строка данных: период, поставщик, суммы, статус', () {
      final csv = buildPaymentsCsv([
        _entry(
          period: DateTime(2026, 2, 1),
          payment: _payment(
            calculated: 1234.56,
            actual: 1234.56,
            status: PaymentStatus.paid,
            paymentDate: DateTime(2026, 2, 10),
          ),
        ),
      ]);
      final lines = csv.split('\n');
      final row = lines[1].split(';');
      expect(row[0], '02.2026');
      expect(row[1], 'Водоканал');
      expect(row[2], 'ул. Тестовая, 1');
      expect(row[7], '1234,56'); // расчётная (запятая — десятичный разделитель)
      expect(row[8], '1234,56'); // факт
      expect(row[9], '10.02.2026');
      expect(row[10], 'оплачено');
    });

    test('поставщик без показаний: колонки показаний/расхода пусты', () {
      final csv = buildPaymentsCsv([
        _entry(payment: _payment(calculated: 300, actual: null, status: PaymentStatus.pending)),
      ]);
      final row = csv.split('\n')[1].split(';');
      expect(row[3], ''); // текущие
      expect(row[4], ''); // предыдущие
      expect(row[5], ''); // расход
      expect(row[8], ''); // факт (null)
      expect(row[10], 'ожидает');
    });

    test('значение с «;» и кавычками экранируется', () {
      final csv = buildPaymentsCsv([
        _entry(supplier: _supplier(name: 'ООО "Ромашка";филиал')),
      ]);
      // Поле с «;» обёрнуто в кавычки, внутренние кавычки удвоены.
      expect(csv.contains('"ООО ""Ромашка"";филиал"'), isTrue);
    });

    test('показания с несколькими каналами через «; » попадают в кавычки', () {
      final csv = buildPaymentsCsv([
        _entry(
          payment: _payment(
            snapshot: [
              ReadingSnapshotEntry(
                channelId: 'c1',
                channelName: 'ХВС',
                unit: 'м³',
                previousValue: 100,
                currentValue: 120,
                tariff: 40,
                readingDate: DateTime(2026, 2, 1),
              ),
              ReadingSnapshotEntry(
                channelId: 'c2',
                channelName: 'ГВС',
                unit: 'м³',
                previousValue: 50,
                currentValue: 60,
                tariff: 80,
                readingDate: DateTime(2026, 2, 1),
              ),
            ],
            consumption: 30,
          ),
        ),
      ]);
      // Значения нескольких каналов разделены «; » — значит, поле в кавычках.
      expect(csv.contains('"ХВС: 120; ГВС: 60"'), isTrue);
      // Расход 30 — целое без «.0».
      expect(csv.contains(';30;'), isTrue);
    });

    test('пустой список → только заголовок', () {
      final csv = buildPaymentsCsv(const []);
      final lines = csv.trim().split('\n');
      expect(lines.length, 1);
      expect(lines.first.contains('Период'), isTrue);
    });

    test('bytes: UTF-8 с BOM (первые 3 байта EF BB BF)', () {
      final bytes = buildPaymentsCsvBytes([_entry()]);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    });
  });
}
