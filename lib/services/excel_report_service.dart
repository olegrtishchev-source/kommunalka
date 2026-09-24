import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/payment.dart';
import '../models/supplier.dart';
import '../utils/json_parsing.dart';

/// Одна строка Excel-отчёта (ТЗ §4.10) — уже готовые для показа значения,
/// а не сырые Payment/Supplier. Сборка данных (в т.ч. подписанная ссылка
/// на чек через ReceiptRepository.getUrl) — дело экрана/провайдера,
/// формирующего отчёт (Этап 4), не этого сервиса: ExcelReportService
/// только раскладывает уже готовые строки по ячейкам.
class ExcelReportRow {
  const ExcelReportRow({
    required this.supplierName,
    this.currentText,
    this.previousText,
    this.consumption,
    this.tariffText,
    required this.calculatedAmount,
    this.actualAmount,
    this.paymentDate,
    this.receiptUrl,
    required this.status,
  });

  final String supplierName;
  /// null — поставщик без показаний (ТЗ §4.10: колонки Текущие/
  /// Предыдущие/Тариф остаются пустыми). Текст, а не число — у поставщика
  /// может быть несколько каналов (ТЗ §4.1), тогда значения нескольких
  /// каналов показаны через «; » (см. [ExcelReportRow.fromPaymentAndSupplier]) —
  /// одной числовой ячейки для «текущего показания» в этом случае просто
  /// не существует.
  final String? currentText;
  final String? previousText;
  final double? consumption;
  final String? tariffText;
  final double calculatedAmount;
  final double? actualAmount;
  final DateTime? paymentDate;
  final String? receiptUrl;
  final PaymentStatus status;

  /// Собирает строку отчёта из платежа и его поставщика. [receiptUrl] —
  /// уже полученная ссылка (см. класс выше), с достаточно большим сроком
  /// действия для отчёта, а не короткая для показа в приложении.
  factory ExcelReportRow.fromPaymentAndSupplier(
    Supplier supplier,
    Payment payment, {
    String? receiptUrl,
  }) {
    final snapshot = payment.readingSnapshot;
    return ExcelReportRow(
      supplierName: supplier.name,
      currentText: _formatChannelValues(snapshot, (e) => e.currentValue),
      previousText: _formatChannelValues(snapshot, (e) => e.previousValue),
      consumption: payment.consumption,
      tariffText: _formatChannelValues(snapshot, (e) => e.tariff),
      calculatedAmount: payment.calculatedAmount,
      actualAmount: payment.actualAmount,
      paymentDate: payment.paymentDate,
      receiptUrl: receiptUrl,
      status: payment.status,
    );
  }
}

String? _formatChannelValues(
  List<ReadingSnapshotEntry>? snapshot,
  double Function(ReadingSnapshotEntry) pick,
) {
  if (snapshot == null || snapshot.isEmpty) return null;
  if (snapshot.length == 1) return pick(snapshot.first).toString();
  return snapshot.map((e) => '${e.channelName}: ${pick(e)}').join('; ');
}

/// Формирование Excel-отчёта по платежам за период (ТЗ §4.10). Только
/// сборка файла — сохранение на диск и выгрузка на Яндекс.Диск (Этап 3.11)
/// не здесь.
class ExcelReportService {
  static const _headers = [
    'Поставщик',
    'Текущие',
    'Предыдущие',
    'Расход',
    'Тариф',
    'Сумма (расчётная)',
    'Оплачено по факту',
    'Дата оплаты',
    'Чек',
    'Статус',
  ];

  static const _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  /// «Отчёт_<Месяц>_<Год>.xlsx» (ТЗ §4.10).
  String suggestedFileName(DateTime period) {
    return 'Отчёт_${_monthNames[period.month - 1]}_${period.year}.xlsx';
  }

  /// Строит xlsx-файл: заголовок, по строке на платёж, строка «ИТОГО» —
  /// сумма факт-оплат за период (ТЗ §4.10). Возвращает готовые байты
  /// файла, всегда с нуля (пакет excel не читает существующие xlsx —
  /// см. ТЗ §4.10, «Отчёт создаётся заново при каждом формировании»).
  Uint8List generate({
    required DateTime period,
    required List<ExcelReportRow> rows,
  }) {
    final excel = Excel.createExcel();
    final sheetName = '${_monthNames[period.month - 1]} ${period.year}';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    var rowIndex = 0;
    _writeRow(
      sheet,
      rowIndex,
      _headers.map((h) => TextCellValue(h) as CellValue?).toList(),
      style: CellStyle(bold: true),
    );
    rowIndex++;

    var totalActual = 0.0;
    for (final row in rows) {
      final paidStyle = row.status == PaymentStatus.paid
          ? CellStyle(backgroundColorHex: ExcelColor.fromHexString('#C6EFCE'))
          : null;
      _writeRow(sheet, rowIndex, _rowToCells(row), style: paidStyle);
      rowIndex++;
      totalActual += row.actualAmount ?? 0;
    }

    _writeRow(sheet, rowIndex, [
      TextCellValue('ИТОГО'),
      null,
      null,
      null,
      null,
      null,
      DoubleCellValue(totalActual),
      null,
      null,
      null,
    ], style: CellStyle(bold: true));

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Не удалось сформировать xlsx-файл.');
    }
    return Uint8List.fromList(bytes);
  }

  List<CellValue?> _rowToCells(ExcelReportRow row) {
    return [
      TextCellValue(row.supplierName),
      row.currentText == null ? null : TextCellValue(row.currentText!),
      row.previousText == null ? null : TextCellValue(row.previousText!),
      row.consumption == null ? null : DoubleCellValue(row.consumption!),
      row.tariffText == null ? null : TextCellValue(row.tariffText!),
      DoubleCellValue(row.calculatedAmount),
      row.actualAmount == null ? null : DoubleCellValue(row.actualAmount!),
      row.paymentDate == null ? null : TextCellValue(formatDateOnly(row.paymentDate!)),
      // Пакет excel не поддерживает настоящие гиперссылки в ячейках —
      // кладём саму ссылку текстом; Excel при открытии файла обычно сам
      // распознаёт http(s)-адрес в ячейке и делает его кликабельным, но
      // это поведение Excel, а не гарантия формата файла (ТЗ §4.10 просит
      // «кликабельную ссылку» — это лучшее, что доступно с этим пакетом).
      row.receiptUrl == null ? null : TextCellValue(row.receiptUrl!),
      TextCellValue(_statusLabel(row.status)),
    ];
  }

  void _writeRow(
    Sheet sheet,
    int rowIndex,
    List<CellValue?> values, {
    CellStyle? style,
  }) {
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );
      cell.value = values[col];
      if (style != null) {
        cell.cellStyle = style;
      }
    }
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'ожидает';
      case PaymentStatus.partiallyPaid:
        return 'частично оплачено';
      case PaymentStatus.paid:
        return 'оплачено';
    }
  }
}
