/// Формирование CSV с историей платежей (ТЗ §4.6, Этап 7 п. 7.3). Колонки
/// согласованы с Excel-отчётом (ТЗ §4.10, [ExcelReportRow]) и дополнены
/// колонкой «Период»: CSV — это выгрузка всей истории, а не одного месяца.
///
/// Чистая функция без файловых/сетевых операций: сборку строк и передачу
/// файла в систему делает экран (Настройки), здесь — только текст, который
/// легко покрыть unit-тестами.
library;

import 'dart:convert';

import '../models/payment.dart';
import '../services/excel_report_service.dart';
import 'amount_format.dart';

/// Одна запись для CSV-выгрузки: период платежа (колонка «Период») и уже
/// готовая строка отчёта (показания/расход/суммы/статус). `ExcelReportRow`
/// периода не хранит, поэтому он передаётся рядом.
class PaymentsCsvEntry {
  const PaymentsCsvEntry({required this.period, required this.row});

  final DateTime period;
  final ExcelReportRow row;
}

/// Колонки CSV (порядок важен). «Период» — первым столбцом: по нему история
/// сортируется/фильтруется в таблице. Остальные соответствуют Excel-отчёту.
const _headers = <String>[
  'Период',
  'Поставщик',
  'Адрес',
  'Текущие показания',
  'Предыдущие показания',
  'Расход',
  'Тариф',
  'Сумма (расчётная)',
  'Оплачено по факту',
  'Дата оплаты',
  'Статус',
];

/// Строит CSV-текст истории платежей.
///
/// Строки идут в переданном порядке (экран сортирует их по периоду перед
/// вызовом). Разделитель — «;» (в русской локали Excel запятая — десятичный
/// разделитель, поэтому «;» безопаснее для открытия файла в таблице).
/// Кодировка — UTF-8 с BOM: без BOM Excel на Windows неверно показывает
/// кириллицу.
String buildPaymentsCsv(List<PaymentsCsvEntry> entries) {
  final buffer = StringBuffer();
  // BOM — чтобы Excel корректно распознал UTF-8 и кириллицу.
  buffer.write('\uFEFF');
  buffer.writeln(_headers.map(_csvField).join(';'));
  for (final entry in entries) {
    buffer.writeln(_rowToCsv(entry).join(';'));
  }
  return buffer.toString();
}

/// Байты CSV — готовы к записи в файл/передаче в share (UTF-8 с BOM).
List<int> buildPaymentsCsvBytes(List<PaymentsCsvEntry> entries) {
  return utf8.encode(buildPaymentsCsv(entries));
}

/// Строка значений одной записи — в порядке [_headers].
List<String> _rowToCsv(PaymentsCsvEntry entry) {
  final row = entry.row;
  return [
    '${_two(entry.period.month)}.${entry.period.year}',
    _csvField(row.supplierName),
    _csvField(row.address ?? ''),
    _csvField(row.currentText ?? ''),
    _csvField(row.previousText ?? ''),
    row.consumption == null ? '' : formatReading(row.consumption!),
    _csvField(row.tariffText ?? ''),
    formatAmountPlain(row.calculatedAmount),
    row.actualAmount == null ? '' : formatAmountPlain(row.actualAmount!),
    row.paymentDate == null ? '' : _formatDate(row.paymentDate!),
    _csvField(statusLabel(row.status)),
  ];
}

/// Русская подпись статуса для CSV — та же, что и в UI/Excel.
String statusLabel(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return 'ожидает';
    case PaymentStatus.partiallyPaid:
      return 'частично оплачено';
    case PaymentStatus.paid:
      return 'оплачено';
  }
}

/// Сумма без знака валюты и разделителя тысяч — для табличного формата:
/// 1234,56 (запятая — десятичный разделитель, т.к. разделитель колонок «;»).
String formatAmountPlain(double value) =>
    formatNumber(value).replaceAll('.', ',');

String _formatDate(DateTime date) =>
    '${_two(date.day)}.${_two(date.month)}.${date.year}';

String _two(int n) => n.toString().padLeft(2, '0');

/// Экранирует значение для CSV: если есть «;», кавычка, перевод строки или
/// ведущие/хвостовые пробелы — оборачивает в двойные кавычки, внутренние
/// кавычки удваивает (RFC 4180).
String _csvField(String value) {
  final needsQuotes = value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r') ||
      value != value.trim();
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}
