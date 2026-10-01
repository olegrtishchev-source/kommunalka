import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import '../models/payment.dart';
import '../repositories/receipt_repository.dart';
import '../utils/amount_format.dart';
import '../utils/date_format.dart';
import '../utils/payment_status_format.dart';

/// Карточка одного платежа в истории — общая для «Истории по поставщику»
/// (4.6) и «Общей истории» (4.7), чтобы не дублировать вёрстку. Если
/// задан [supplierName] (только в общей истории, где платежи разных
/// поставщиков перемешаны), он показывается в заголовке карточки.
///
/// «Показания (текущее/предыдущее)» из ТЗ §4.6 показываются только когда
/// у платежа заполнен reading_snapshot — его формирование ещё не сделано
/// (Этап 5, п. 5.4, см. журнал 4.6); до тех пор вместо показаний по
/// каналам строка выводит только итоговый расход числом.
class PaymentHistoryCard extends StatelessWidget {
  const PaymentHistoryCard({
    super.key,
    required this.payment,
    required this.receiptRepo,
    this.supplierName,
  });

  final PaymentRow payment;
  final ReceiptRepository receiptRepo;
  final String? supplierName;

  @override
  Widget build(BuildContext context) {
    final status = PaymentStatus.fromDb(payment.status);
    final (label, color) = paymentStatusLabelAndColor(status);
    final snapshotJson = payment.readingSnapshot;
    final entries = snapshotJson == null
        ? const <ReadingSnapshotEntry>[]
        : (jsonDecode(snapshotJson) as List<dynamic>)
            .map((e) => ReadingSnapshotEntry.fromJson(e as Map<String, dynamic>))
            .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  supplierName != null
                      ? '$supplierName — ${formatPeriod(payment.period)}'
                      : formatPeriod(payment.period),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Chip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: color.withValues(alpha: 0.15),
                  side: BorderSide(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isNotEmpty)
              for (final e in entries)
                Text(
                  '${e.channelName}: ${e.previousValue} → ${e.currentValue} ${e.unit} '
                  '(расход: ${e.consumption.toStringAsFixed(2)} ${e.unit})',
                )
            else if (payment.consumption != null)
              Text('Расход: ${payment.consumption!.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Text('Расчётная сумма: ${formatAmount(payment.calculatedAmount)}'),
            Text(
              payment.actualAmount != null
                  ? 'Факт-сумма: ${formatAmount(payment.actualAmount!)}'
                  : 'Факт-сумма: —',
            ),
            if (payment.paymentDate != null)
              Text(
                'Дата оплаты: ${formatDate(payment.paymentDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: StreamBuilder<List<ReceiptRow>>(
                stream: receiptRepo.watchForPayment(payment.id),
                builder: (context, receiptSnapshot) {
                  final hasReceipt = (receiptSnapshot.data ?? const []).isNotEmpty;
                  return TextButton.icon(
                    onPressed: () => context.push('/payments/${payment.id}/receipt'),
                    icon: Icon(hasReceipt ? Icons.receipt : Icons.receipt_long_outlined),
                    label: Text(hasReceipt ? 'Чек' : 'Прикрепить чек'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
