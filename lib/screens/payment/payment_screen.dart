import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../models/supplier.dart';
import '../../providers/payment_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../utils/bank_details_format.dart';

/// Оплата (ТЗ §4.4, схема 2.5, сценарий 3): расчётная сумма, реквизиты
/// поставщика с копированием, напоминание, что оплата идёт через
/// банковское приложение пользователя (само приложение деньги не
/// переводит), факт-сумма, дата оплаты, редактируемый период (ТЗ §4.3 —
/// корректировка периода именно здесь, а не на экране показания).
///
/// Прикрепление чека («по желанию», ТЗ §4.4–4.5) — кнопка ниже ведёт на
/// отдельный экран ReceiptScreen (4.5, /payments/:paymentId/receipt);
/// доступна независимо от сохранения факт-суммы.
///
/// Поля «Банк» нет (убрано из модели/схемы/отчёта на 3.5.4) — банк, через
/// который прошла оплата, виден на самом чеке (ТЗ §4.5), отдельно не
/// фиксируется.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.supplierId, required this.paymentId});

  final String supplierId;
  final String paymentId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  DateTime _period = DateTime.now();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  PaymentRow? _payment;
  SupplierRow? _supplier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final supplierRepo = ref.read(supplierRepositoryProvider);
      await paymentRepo.refresh();
      await supplierRepo.refresh();
      final payment = await paymentRepo.getById(widget.paymentId);
      final supplier = await supplierRepo.getById(widget.supplierId);
      setState(() {
        _payment = payment;
        _supplier = supplier;
        _amountController.text = payment?.calculatedAmount.toString() ?? '';
        if (payment != null) _period = payment.period;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Выберите любой день нужного месяца',
    );
    if (picked != null) {
      setState(() => _period = DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> _copyBankDetails(BankDetails details) async {
    await Clipboard.setData(ClipboardData(text: formatBankDetails(details)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Реквизиты скопированы')),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final original = _payment!.period;
      final periodChanged = _period.year != original.year || _period.month != original.month;
      final updated = await ref.read(paymentRepositoryProvider).recordPayment(
            paymentId: widget.paymentId,
            actualAmount: amount,
            paymentDate: _paymentDate,
            period: periodChanged ? _period : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено. Статус: ${_statusLabel(updated.status)}')),
      );
      context.go('/suppliers');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'ожидает оплаты';
      case PaymentStatus.partiallyPaid:
        return 'оплачено частично';
      case PaymentStatus.paid:
        return 'оплачено';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankDetailsJson = _supplier?.bankDetails;
    final bankDetails = bankDetailsJson == null
        ? null
        : BankDetails.fromJson(
            Map<String, dynamic>.from(jsonDecode(bankDetailsJson) as Map),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payment == null
              ? Center(child: Text('Платёж не найден. ${_error ?? ''}'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Расчётная сумма: '
                          '${_payment!.calculatedAmount.toStringAsFixed(2)} ₽',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Оплата выполняется через ваше банковское приложение — '
                          'это приложение деньги само не переводит.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (bankDetails != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatBankDetails(bankDetails)),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _copyBankDetails(bankDetails),
                                      icon: const Icon(Icons.copy, size: 18),
                                      label: const Text('Скопировать'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Факт-сумма, ₽'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите сумму';
                            if (double.tryParse(v.replaceAll(',', '.')) == null) {
                              return 'Введите число';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Дата оплаты: '
                              '${_paymentDate.day}.${_paymentDate.month}.${_paymentDate.year}',
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _paymentDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setState(() => _paymentDate = picked);
                              },
                              child: const Text('Изменить'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Период: ${_period.month}.${_period.year}'),
                            TextButton(onPressed: _pickPeriod, child: const Text('Изменить')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/payments/${widget.paymentId}/receipt'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Прикрепить чек'),
                        ),
                        const SizedBox(height: 20),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
