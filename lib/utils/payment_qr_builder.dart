import '../models/payment.dart';
import '../models/supplier.dart';

/// Сборка строки платёжного QR-кода по ГОСТ Р 56042 (ТЗ §4.4, Этап 5 п. 5.11).
///
/// Формат: ST00012|Name=…|PersonalAcc=…|BankName=…|BIC=…|CorrespAcc=…|PayeeINN=…
/// |KPP=…|persAcc=…|Sum=…|Purpose=…, кодировка UTF-8 (код «2» в заголовке).
/// Всегда: Name, PersonalAcc, BIC, PayeeINN; остальные — если заполнены в
/// карточке поставщика. Sum — расчётная сумма в копейках (целое число).
/// Purpose — назначение платежа по шаблону с подставленным периодом.
/// Знак «|» в значениях экранируется пробелом (разделитель полей).
String buildPaymentQr(Supplier supplier, Payment payment) {
  final details = supplier.bankDetails;
  if (details == null) {
    throw ArgumentError('У поставщика нет банковских реквизитов.');
  }
  final name = details.recipient;
  final account = details.accountNumber;
  final bic = details.bik;
  final inn = details.inn;
  if (name == null ||
      name.trim().isEmpty ||
      account == null ||
      account.trim().isEmpty ||
      bic == null ||
      bic.trim().isEmpty ||
      inn == null ||
      inn.trim().isEmpty) {
    throw ArgumentError(
      'Не заполнены обязательные реквизиты (получатель, счёт, БИК, ИНН).',
    );
  }

  final kopecks = (payment.calculatedAmount * 100).round();
  final purpose = _buildPurpose(supplier.paymentPurposeTemplate, payment.period);

  final parts = <String>['ST00012'];
  void add(String key, String? value) {
    if (value == null || value.isEmpty) return;
    parts.add('$key=${_escape(value)}');
  }

  add('Name', name);
  add('PersonalAcc', account);
  add('BankName', details.bankName);
  add('BIC', bic);
  add('CorrespAcc', details.corrAccount);
  add('PayeeINN', inn);
  add('KPP', details.kpp);
  add('persAcc', supplier.personalAccount);
  add('Sum', '$kopecks');
  add('Purpose', purpose);

  return parts.join('|');
}

/// Разделитель полей «|» внутри значения заменяется пробелом, чтобы не
/// сломать структуру QR (ГОСТ Р 56042 не определяет экранирование «|»).
String _escape(String value) => value.replaceAll('|', ' ');

const _monthNames = [
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

/// Подставляет в шаблон назначения платежа `{месяц}` и `{год}` из периода
/// (напр. «оплата за {месяц} {год}» → «оплата за Сентябрь 2026»).
String _buildPurpose(String? template, DateTime period) {
  if (template == null || template.isEmpty) return '';
  return template
      .replaceAll('{месяц}', _monthNames[period.month - 1])
      .replaceAll('{год}', '${period.year}');
}
