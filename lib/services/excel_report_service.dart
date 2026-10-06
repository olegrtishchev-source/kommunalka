import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../models/payment.dart';
import '../models/supplier.dart';
import '../utils/amount_format.dart';
import '../utils/json_parsing.dart';

/// Одна строка Excel-отчёта (ТЗ §4.10) — уже готовые для показа значения,
/// а не сырые Payment/Supplier. Сборка данных (в т.ч. подписанная ссылка
/// на чек через ReceiptRepository.getUrl) — дело экрана/провайдера,
/// формирующего отчёт (Этап 4), не этого сервиса: ExcelReportService
/// только раскладывает уже готовые строки по ячейкам.
class ExcelReportRow {
  const ExcelReportRow({
    required this.supplierName,
    this.address,
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
  /// Адрес (объект) поставщика — ТЗ §4.13. null/пусто — адрес не задан.
  final String? address;
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
      address: supplier.address,
      currentText: _formatChannelValues(snapshot, (e) => e.currentValue),
      previousText: _formatChannelValues(snapshot, (e) => e.previousValue),
      // Старые платежи (до исправления) были сохранены с consumption = null,
      // хотя reading_snapshot у них есть — восстанавливаем расход из снимка,
      // чтобы отчёт по таким платежам не терял колонку «Расход».
      consumption: payment.consumption ?? _consumptionFromSnapshot(snapshot),
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
  if (snapshot.length == 1) return formatReading(pick(snapshot.first));
  return snapshot
      .map((e) => '${e.channelName}: ${formatReading(pick(e))}')
      .join('; ');
}

/// Восстанавливает суммарный расход из снимка показаний (Σ current −
/// previous) для старых платежей, где `consumption` не был сохранён.
/// null/пустой снимок (поставщик без показаний) → null, чтобы колонка
/// «Расход» осталась пустой.
double? _consumptionFromSnapshot(List<ReadingSnapshotEntry>? snapshot) {
  if (snapshot == null || snapshot.isEmpty) return null;
  return snapshot.fold<double>(0, (sum, e) => sum + e.consumption);
}

/// Формирование Excel-отчёта по платежам за период (ТЗ §4.10). Только
/// сборка файла — сохранение на диск и выгрузка на Яндекс.Диск (Этап 3.11)
/// не здесь.
class ExcelReportService {
  static const _headers = [
    'Поставщик',
    'Адрес',
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
      _writeRow(sheet, rowIndex, _rowToCells(row));
      // Заливка — только ячейка «Статус» (последняя колонка) и только для
      // «оплачено»; остальные ячейки и остальные статусы остаются белыми.
      if (row.status == PaymentStatus.paid) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: _headers.length - 1,
                rowIndex: rowIndex,
              ),
            )
            .cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#C6EFCE'),
        );
      }
      rowIndex++;
      totalActual += row.actualAmount ?? 0;
    }

    _writeRow(sheet, rowIndex, [
      TextCellValue('ИТОГО'),
      null, // Адрес
      null,
      null,
      null,
      null,
      null,
      DoubleCellValue(totalActual), // Оплачено по факту
      null,
      null,
      null,
    ], style: CellStyle(bold: true));

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Не удалось сформировать xlsx-файл.');
    }
    // Пакет excel не умеет автофильтр — добавляем его в готовый xlsx
    // пост-обработкой (вставка <autoFilter> в XML листа). Диапазон — вся
    // таблица включая строку «ИТОГО», чтобы в выпадающих списках были все
    // значения (фильтр по колонке «Адрес» — основная цель, ТЗ §4.10).
    return _withAutoFilter(
      Uint8List.fromList(bytes),
      firstRow: 1,
      lastRow: rowIndex + 1,
      lastColumn: _headers.length,
    );
  }

  /// Вставляет `<autoFilter ref="A1:<col><row>"/>` в XML первого листа
  /// xlsx-файла. [firstRow]/[lastRow] — 1-базовые номера строк диапазона
  /// фильтра, [lastColumn] — 1-базовый номер последней колонки. При любой
  /// ошибке разбора/перепаковки возвращает исходные байты — фильтр не
  /// критичен и не должен срывать формирование отчёта.
  Uint8List _withAutoFilter(
    Uint8List xlsx, {
    required int firstRow,
    required int lastRow,
    required int lastColumn,
  }) {
    try {
      final source = ZipDecoder().decodeBytes(xlsx);
      final ref = 'A$firstRow:${_columnName(lastColumn)}$lastRow';
      final out = Archive();
      for (final file in source) {
        if (!file.isFile) continue;
        var content = file.content as List<int>;
        if (file.name.startsWith('xl/worksheets/sheet') &&
            file.name.endsWith('.xml')) {
          final xml = utf8.decode(content);
          // <autoFilter> по схеме OOXML идёт сразу ПОСЛЕ </sheetData>.
          final at = xml.indexOf('</sheetData>');
          if (at >= 0 && !xml.contains('<autoFilter')) {
            final patched = xml.replaceRange(
              at + '</sheetData>'.length,
              at + '</sheetData>'.length,
              '<autoFilter ref="$ref"/>',
            );
            content = utf8.encode(patched);
          }
        }
        out.addFile(ArchiveFile(file.name, content.length, content));
      }
      final encoded = ZipEncoder().encode(out);
      if (encoded != null) return Uint8List.fromList(encoded);
    } catch (_) {
      // оставляем файл без фильтра — это допустимо.
    }
    return xlsx;
  }

  /// 1 → «A», 2 → «B», …, 27 → «AA» — буквенное имя колонки Excel.
  String _columnName(int index) {
    var i = index;
    final buffer = StringBuffer();
    while (i > 0) {
      final rem = (i - 1) % 26;
      buffer.write(String.fromCharCode(65 + rem));
      i = (i - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  List<CellValue?> _rowToCells(ExcelReportRow row) {
    return [
      TextCellValue(row.supplierName),
      row.address == null || row.address!.isEmpty
          ? null
          : TextCellValue(row.address!),
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
