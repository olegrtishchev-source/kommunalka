import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';
import '../../providers/receipt_provider.dart';
import '../../repositories/receipt_repository.dart';
import '../../utils/payment_status_format.dart';

/// История платежей по конкретному поставщику (ТЗ §4.6, схема §2.5:
/// /suppliers/:id/history) — открывается с карточки поставщика (4.1).
/// Общая история по всем поставщикам с фильтрами/поиском по сумме и дате —
/// отдельный экран, 4.7 (ТЗ §4.6, второй абзац).
///
/// «Показания (текущее/предыдущее), если применимо» из ТЗ §4.6 отображаются
/// только когда у платежа заполнен reading_snapshot — а его формирование
/// (Этап 5, п. 5.4) ещё не реализовано: сейчас ReadingEntryScreen передаёт
/// в Payment.create() готовые consumption/calculatedAmount без snapshot.
/// До 5.4 строка вместо показаний по каналам показывает просто расход
/// (Payment.consumption), если он есть; после 5.4 экран сам начнёт
/// показывать показания по каждому каналу — код уже это читает.
class SupplierHistoryScreen extends ConsumerWidget {
  const SupplierHistoryScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentRepo = ref.watch(paymentRepositoryProvider);
    final receiptRepo = ref.watch(receiptRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('История платежей')),
      body: StreamBuilder<List<PaymentRow>>(
        stream: paymentRepo.watchForSupplier(supplierId),
        builder: (context, snapshot) {
          final payments = snapshot.data ?? const [];
          if (payments.isEmpty) {
            return const Center(child: Text('Платежей пока нет.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) => _PaymentHistoryCard(
              payment: payments[index],
              receiptRepo: receiptRepo,
            ),
          );
        },
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment, required this.receiptRepo});

  final PaymentRow payment;
  final ReceiptRepository receiptRepo;

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
                  '${payment.period.month}.${payment.period.year}',
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
            Text('Расчётная сумма: ${payment.calculatedAmount.toStringAsFixed(2)} ₽'),
            Text(
              payment.actualAmount != null
                  ? 'Факт-сумма: ${payment.actualAmount!.toStringAsFixed(2)} ₽'
                  : 'Факт-сумма: —',
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
