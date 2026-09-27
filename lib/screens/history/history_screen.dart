import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/payment_provider.dart';
import '../../providers/receipt_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../widgets/payment_history_card.dart';

/// Общая история платежей по всем поставщикам (ТЗ §4.6, второй абзац;
/// план — п. 4.7) — вкладка «История» нижней навигации (/history, 4.9).
///
/// Фильтр по поставщику и по периоду (месяцу), поиск по сумме и по дате —
/// ровно как в формулировке плана, без дополнительных критериев (например,
/// поиска по названию поставщика — про него в ТЗ/плане речи нет).
/// Карточка платежа — общий виджет PaymentHistoryCard (см. lib/widgets),
/// вынесенный сюда же на этом пункте из lib/screens/history/
/// supplier_history_screen.dart (4.6), чтобы не дублировать вёрстку.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _supplierFilter; // null — все поставщики
  DateTime? _periodFilter; // null — все периоды
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    Future.microtask(() {
      ref.read(supplierRepositoryProvider).refresh();
      ref.read(paymentRepositoryProvider).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickPeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Выберите любой день нужного месяца',
    );
    if (picked != null) {
      setState(() => _periodFilter = DateTime(picked.year, picked.month, 1));
    }
  }

  bool _matchesSearch(PaymentRow p, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final periodStr = '${p.period.month}.${p.period.year}';
    final dateStr = p.paymentDate == null
        ? ''
        : '${p.paymentDate!.day}.${p.paymentDate!.month}.${p.paymentDate!.year}';
    final calcStr = p.calculatedAmount.toStringAsFixed(2);
    final actualStr = p.actualAmount?.toStringAsFixed(2) ?? '';
    return periodStr.contains(q) ||
        dateStr.contains(q) ||
        calcStr.contains(q) ||
        actualStr.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final paymentRepo = ref.watch(paymentRepositoryProvider);
    final receiptRepo = ref.watch(receiptRepositoryProvider);
    final supplierRepo = ref.watch(supplierRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: StreamBuilder<List<SupplierRow>>(
        stream: supplierRepo.watchAll(),
        builder: (context, supplierSnapshot) {
          final suppliers = supplierSnapshot.data ?? const [];
          final supplierNames = {for (final s in suppliers) s.id: s.name};

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _supplierFilter,
                        decoration: const InputDecoration(labelText: 'Поставщик'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Все')),
                          for (final s in suppliers)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (value) => setState(() => _supplierFilter = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _pickPeriod,
                      child: Text(
                        _periodFilter == null
                            ? 'Период'
                            : '${_periodFilter!.month}.${_periodFilter!.year}',
                      ),
                    ),
                    if (_periodFilter != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Сбросить период',
                        onPressed: () => setState(() => _periodFilter = null),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Поиск по сумме или дате',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(_searchController.clear),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<PaymentRow>>(
                  stream: paymentRepo.watchAll(),
                  builder: (context, paymentSnapshot) {
                    var payments = paymentSnapshot.data ?? const [];
                    if (_supplierFilter != null) {
                      payments =
                          payments.where((p) => p.supplierId == _supplierFilter).toList();
                    }
                    if (_periodFilter != null) {
                      payments = payments
                          .where(
                            (p) =>
                                p.period.year == _periodFilter!.year &&
                                p.period.month == _periodFilter!.month,
                          )
                          .toList();
                    }
                    final query = _searchController.text.trim();
                    if (query.isNotEmpty) {
                      payments = payments.where((p) => _matchesSearch(p, query)).toList();
                    }
                    if (payments.isEmpty) {
                      return const Center(child: Text('Платежей не найдено.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        return PaymentHistoryCard(
                          payment: payment,
                          receiptRepo: receiptRepo,
                          supplierName: supplierNames[payment.supplierId] ?? 'Поставщик',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
