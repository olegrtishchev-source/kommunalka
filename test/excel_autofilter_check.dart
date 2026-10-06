// Проверочный скрипт: убеждается, что ExcelReportService.generate
// вставляет <autoFilter> (фильтр по колонкам) в готовый xlsx. Запуск:
//   dart run test/excel_autofilter_check.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:kommunalka/models/payment.dart';
import 'package:kommunalka/models/supplier.dart';
import 'package:kommunalka/services/excel_report_service.dart';

void main() {
  final service = ExcelReportService();
  final bytes = service.generate(
    period: DateTime(2026, 10, 1),
    rows: [
      ExcelReportRow(
        supplierName: 'Водоканал',
        address: 'Советская 12',
        calculatedAmount: 906.52,
        actualAmount: 906.52,
        status: PaymentStatus.paid,
      ),
      ExcelReportRow(
        supplierName: 'Энергосбыт',
        address: 'Черноморская 5',
        calculatedAmount: 177.08,
        status: PaymentStatus.pending,
      ),
    ],
  );

  final archive = ZipDecoder().decodeBytes(bytes);
  final sheetFile = archive.files.firstWhere(
    (f) => f.name == 'xl/worksheets/sheet1.xml',
  );
  final xml = utf8.decode(sheetFile.content as List<int>);
  final refMatch =
      RegExp(r'<autoFilter ref="([^"]+)"').firstMatch(xml)?.group(1);

  // Расход восстанавливается из снимка для старых платежей (consumption=null).
  final legacy = ExcelReportRow.fromPaymentAndSupplier(
    Supplier(
      id: 's',
      userId: 'u',
      name: 'Водоканал',
      type: SupplierType.withReadings,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    Payment(
      id: 'p',
      userId: 'u',
      supplierId: 's',
      period: DateTime(2026, 10, 1),
      consumption: null,
      calculatedAmount: 906.52,
      status: PaymentStatus.paid,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      readingSnapshot: [
        ReadingSnapshotEntry(
          channelId: 'c',
          channelName: 'Вода',
          unit: 'м³',
          previousValue: 45171,
          currentValue: 45344,
          tariff: 5.24,
          readingDate: DateTime(2026, 10, 3),
        ),
      ],
    ),
  );
  stdout.writeln('legacy consumption: ${legacy.consumption}');

  stdout.writeln('autoFilter ref: $refMatch (bytes: ${bytes.length})');
  File('build/filter_sample.xlsx').writeAsBytesSync(bytes);
  stdout.writeln('written: build/filter_sample.xlsx');
  if (legacy.consumption != 173.0) {
    stderr.writeln('FAIL: расход не восстановлен: ${legacy.consumption}');
    exit(1);
  }
  // 11 колонок (A..K), строки 1..4 (шапка + 2 данных + ИТОГО).
  if (refMatch != 'A1:K4') {
    stderr.writeln('FAIL: ожидался ref A1:K4, получено $refMatch');
    exit(1);
  }
  stdout.writeln('OK');
}
