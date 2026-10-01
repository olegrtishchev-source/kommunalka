// Unit-тесты чистой функции PaymentStatus.calculate (ТЗ §4.4, Этап 5 п. 5.6):
// статус платежа выставляется автоматически по соотношению факт-суммы и
// расчётной — ожидает / частично оплачено / оплачено. Функция — чистый Dart
// без Flutter-зависимостей, поэтому тест не поднимает виджеты.

import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/models/payment.dart';

void main() {
  group('PaymentStatus.calculate', () {
    test('факт-сумма не введена (null) → ожидает', () {
      final status = PaymentStatus.calculate(
        calculatedAmount: 100.0,
        actualAmount: null,
      );
      expect(status, PaymentStatus.pending);
    });

    test('факт-сумма 0 → ожидает (оплаты ещё не было)', () {
      final status = PaymentStatus.calculate(
        calculatedAmount: 100.0,
        actualAmount: 0,
      );
      expect(status, PaymentStatus.pending);
    });

    test('0 < факт < расчёт → частично оплачено', () {
      final status = PaymentStatus.calculate(
        calculatedAmount: 100.0,
        actualAmount: 40.0,
      );
      expect(status, PaymentStatus.partiallyPaid);
    });

    test('факт == расчёт → оплачено', () {
      final status = PaymentStatus.calculate(
        calculatedAmount: 100.0,
        actualAmount: 100.0,
      );
      expect(status, PaymentStatus.paid);
    });

    test('факт > расчёт (переплата) → оплачено', () {
      final status = PaymentStatus.calculate(
        calculatedAmount: 100.0,
        actualAmount: 150.0,
      );
      expect(status, PaymentStatus.paid);
    });

    test('отрицательная факт-сумма → ожидает (недопустимо, но не падает)', () {
      final status = PaymentStatus.calculate(
        calculatedAmount: 100.0,
        actualAmount: -10.0,
      );
      expect(status, PaymentStatus.pending);
    });
  });
}
