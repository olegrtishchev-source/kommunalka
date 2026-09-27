import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/payment_provider.dart';
import '../../providers/receipt_provider.dart';
import '../../widgets/payment_history_card.dart';

/// История платежей по конкретному поставщику (ТЗ §4.6, схема §2.5:
/// /suppliers/:id/history) — открывается с карточки поставщика (4.1).
/// Общая история по всем поставщикам с фильтрами/поиском по сумме и дате —
/// отдельный экран, 4.7 (ТЗ §4.6, второй абзац).
///
/// Вёрстка карточки платежа — общий виджет PaymentHistoryCard (см. журнал
/// 4.7), там же и заметка про reading_snapshot/5.4.
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
            itemBuilder: (context, index) => PaymentHistoryCard(
              payment: payments[index],
              receiptRepo: receiptRepo,
            ),
          );
        },
      ),
    );
  }
}
