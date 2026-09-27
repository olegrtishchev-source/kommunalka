import '../models/supplier.dart';

/// Реквизиты поставщика как текст для показа/копирования (ТЗ §4.4) —
/// общая функция для карточки поставщика (4.1) и экрана оплаты (4.4),
/// чтобы не дублировать одно и то же форматирование в двух местах.
String formatBankDetails(BankDetails details) {
  final lines = <String>[
    if (details.recipient != null) 'Получатель: ${details.recipient}',
    if (details.inn != null) 'ИНН: ${details.inn}',
    if (details.kpp != null) 'КПП: ${details.kpp}',
    if (details.bik != null) 'БИК: ${details.bik}',
    if (details.accountNumber != null) 'Счёт: ${details.accountNumber}',
  ];
  return lines.join('\n');
}
