// Unit-тесты генератора платёжного QR ГОСТ Р 56042 (ТЗ §4.4, Этап 5 п. 5.11).

import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/models/payment.dart';
import 'package:kommunalka/models/supplier.dart';
import 'package:kommunalka/utils/payment_qr_builder.dart';

void main() {
  BankDetails details({
    String recipient = 'ООО Тест',
    String accountNumber = '40702810000000000000',
    String? bik = '044525225',
    String? inn = '7707083893',
    String? bankName,
    String? corrAccount,
    String? kpp,
  }) {
    return BankDetails(
      recipient: recipient,
      accountNumber: accountNumber,
      bik: bik,
      inn: inn,
      bankName: bankName,
      corrAccount: corrAccount,
      kpp: kpp,
    );
  }

  Supplier supplier({
    BankDetails? bankDetails,
    String? personalAccount,
    String? purposeTemplate,
  }) {
    return Supplier(
      id: 's1',
      userId: 'u1',
      name: 'Тест',
      type: SupplierType.withReadings,
      bankDetails: bankDetails,
      personalAccount: personalAccount,
      paymentPurposeTemplate: purposeTemplate,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  Payment payment(double amount, {DateTime? period}) {
    return Payment(
      id: 'p1',
      userId: 'u1',
      supplierId: 's1',
      period: period ?? DateTime(2026, 9, 1),
      calculatedAmount: amount,
      status: PaymentStatus.pending,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  group('buildPaymentQr', () {
    test('полный набор полей, сумма в копейках, Purpose по шаблону', () {
      final qr = buildPaymentQr(
        supplier(
          bankDetails: details(
            bankName: 'Сбербанк',
            corrAccount: '30101810400000000225',
            kpp: '770701001',
          ),
          personalAccount: '123456',
          purposeTemplate: 'оплата за {месяц} {год}',
        ),
        payment(1234.50),
      );
      expect(
        qr,
        'ST00012|Name=ООО Тест|PersonalAcc=40702810000000000000|'
        'BankName=Сбербанк|BIC=044525225|CorrespAcc=30101810400000000225|'
        'PayeeINN=7707083893|KPP=770701001|persAcc=123456|'
        'Sum=123450|Purpose=оплата за Сентябрь 2026',
      );
    });

    test('только обязательные поля — необязательные отсутствуют', () {
      final qr = buildPaymentQr(
        supplier(bankDetails: details()),
        payment(100.0),
      );
      expect(
        qr,
        'ST00012|Name=ООО Тест|PersonalAcc=40702810000000000000|'
        'BIC=044525225|PayeeINN=7707083893|Sum=10000',
      );
    });

    test('сумма в копейках округляется корректно', () {
      final qr = buildPaymentQr(
        supplier(bankDetails: details()),
        payment(99.99),
      );
      expect(qr, contains('Sum=9999'));
    });

    test('знак «|» в значении экранируется пробелом', () {
      final qr = buildPaymentQr(
        supplier(
          bankDetails: details(recipient: 'ООО Тест|Сервис'),
        ),
        payment(50.0),
      );
      expect(qr, contains('Name=ООО Тест Сервис'));
      expect(qr, isNot(contains('|Сервис|')));
    });

    test('нет шаблона назначения — Purpose отсутствует', () {
      final qr = buildPaymentQr(
        supplier(bankDetails: details()),
        payment(50.0),
      );
      expect(qr, isNot(contains('Purpose')));
    });

    test('не хватает обязательных реквизитов → ArgumentError', () {
      expect(
        () => buildPaymentQr(
          supplier(bankDetails: details(inn: null)),
          payment(50.0),
        ),
        throwsArgumentError,
      );
    });
  });
}
