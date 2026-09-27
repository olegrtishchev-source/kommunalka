import 'package:flutter/material.dart';

import '../models/payment.dart';

/// Русская подпись и цвет статуса платежа (ТЗ §4.4, §4.6 — статус
/// «оплачено» отмечается не только текстом, но и визуальным маркером).
/// Общее для бейджа в списке поставщиков (4.1) и истории платежей (4.6).
(String, Color) paymentStatusLabelAndColor(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.pending => ('ожидает', Colors.orange),
    PaymentStatus.partiallyPaid => ('частично', Colors.amber),
    PaymentStatus.paid => ('оплачено', Colors.green),
  };
}
