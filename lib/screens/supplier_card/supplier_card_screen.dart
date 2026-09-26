import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/supplier.dart';
import '../../providers/channel_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../repositories/channel_repository.dart';
import '../../utils/supplier_category_icon.dart';

/// Карточка поставщика (схема §2.5: /suppliers/:id) — промежуточный экран
/// между списком поставщиков (4.1) и вводом показаний/оплатой. Показывает
/// реквизиты (с копированием, ТЗ §4.4 — тут, а не на самом экране оплаты,
/// см. её doc-комментарий) и каналы поставщика.
///
/// Кнопка «Внести показания» ведёт либо на уже существующий платёж за
/// текущий период, либо на его создание — та же логика, что раньше жила
/// прямо в списке поставщиков (журнал 3.5.4), теперь на своём месте по
/// схеме навигации.
///
/// Кнопка «Редактировать» в AppBar ведёт на SupplierFormScreen в режиме
/// редактирования (4.2). История платежей по поставщику (4.6) — сюда же
/// добавится при прохождении соответствующего пункта плана; сейчас её
/// тут нет, чтобы не делать неработающую кнопку.
///
/// Для типа without_readings кнопка ввода временно заменена пояснением —
/// ввод суммы вручную для безсчётчиковых поставщиков относится к п. 4.3,
/// ещё не реализован (ReadingEntryScreen сейчас рассчитан только на
/// with_readings, см. её doc-комментарий).
class SupplierCardScreen extends ConsumerStatefulWidget {
  const SupplierCardScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<SupplierCardScreen> createState() => _SupplierCardScreenState();
}

class _SupplierCardScreenState extends ConsumerState<SupplierCardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(channelRepositoryProvider).refresh();
      ref.read(paymentRepositoryProvider).refresh();
    });
  }

  Future<void> _openReadingOrPayment(BuildContext context) async {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final now = DateTime.now();
    final period = DateTime(now.year, now.month, 1);
    final existing =
        await paymentRepo.getForSupplierAndPeriod(widget.supplierId, period);
    if (!context.mounted) return;
    if (existing != null) {
      context.push('/suppliers/${widget.supplierId}/payment/${existing.id}');
    } else {
      context.push('/suppliers/${widget.supplierId}/reading');
    }
  }

  Future<void> _copyBankDetails(BuildContext context, BankDetails details) async {
    await Clipboard.setData(ClipboardData(text: _formatBankDetails(details)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Реквизиты скопированы')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplierRepo = ref.watch(supplierRepositoryProvider);
    final channelRepo = ref.watch(channelRepositoryProvider);

    return StreamBuilder<List<SupplierRow>>(
      stream: supplierRepo.watchAll(),
      builder: (context, snapshot) {
        final suppliers = snapshot.data ?? const [];
        SupplierRow? supplier;
        for (final s in suppliers) {
          if (s.id == widget.supplierId) {
            supplier = s;
            break;
          }
        }

        final bankDetailsJson = supplier?.bankDetails;
        final bankDetails = bankDetailsJson == null
            ? null
            : BankDetails.fromJson(
                Map<String, dynamic>.from(jsonDecode(bankDetailsJson) as Map),
              );
        final isWithReadings = supplier?.type == SupplierType.withReadings.dbValue;

        return Scaffold(
          appBar: AppBar(
            title: Text(supplier?.name ?? 'Поставщик'),
            actions: [
              if (supplier != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Редактировать',
                  onPressed: () => context.push('/suppliers/${widget.supplierId}/edit'),
                ),
            ],
          ),
          body: supplier == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Icon(iconForSupplierCategory(supplier.category), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (supplier.category != null) Text(supplier.category!),
                              Text(
                                isWithReadings ? 'С показаниями' : 'Без показаний',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (bankDetails != null) ...[
                      Text('Реквизиты', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatBankDetails(bankDetails)),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _copyBankDetails(context, bankDetails),
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('Скопировать'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (isWithReadings)
                      _ChannelsList(supplierId: widget.supplierId, channelRepo: channelRepo)
                    else
                      const Text(
                        'Сумма к оплате вводится вручную каждый период — '
                        'экран появится на Этапе 4, п. 4.3.',
                      ),
                    const SizedBox(height: 24),
                    if (isWithReadings)
                      FilledButton.icon(
                        onPressed: () => _openReadingOrPayment(context),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Внести показания'),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

String _formatBankDetails(BankDetails details) {
  final lines = <String>[
    if (details.recipient != null) 'Получатель: ${details.recipient}',
    if (details.inn != null) 'ИНН: ${details.inn}',
    if (details.kpp != null) 'КПП: ${details.kpp}',
    if (details.bik != null) 'БИК: ${details.bik}',
    if (details.accountNumber != null) 'Счёт: ${details.accountNumber}',
  ];
  return lines.join('\n');
}

class _ChannelsList extends StatelessWidget {
  const _ChannelsList({required this.supplierId, required this.channelRepo});

  final String supplierId;
  final ChannelRepository channelRepo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChannelRow>>(
      stream: channelRepo.watchForSupplier(supplierId),
      builder: (context, snapshot) {
        final channels = snapshot.data ?? const [];
        if (channels.isEmpty) {
          return const Text('Каналы показаний пока не заведены.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Каналы показаний', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final channel in channels)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${channel.name}: ${channel.tariff} ₽/${channel.unit}'
                  '${channel.sourceChannelId != null ? ' (производный)' : ''}',
                ),
              ),
          ],
        );
      },
    );
  }
}
