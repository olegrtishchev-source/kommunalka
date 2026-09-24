import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';

/// Оплата (ТЗ §4.4, схема 2.5, сценарий 3). Минимальная версия для
/// Этапа 3.5: факт-сумма, дата — без реквизитов поставщика (обычно видны
/// с карточки /suppliers/:id — Этап 4) и без перехода на прикрепление
/// чека («по желанию», не входит в тончайшую связку).
///
/// Поля «Банк» больше нет (убрано из модели/схемы/отчёта по ходу
/// практической проверки 3.5.4) — банк, через который прошла оплата,
/// не фиксируется отдельным полем, эта информация остаётся на самом
/// чеке (ТЗ §4.5), который прикрепляется отдельно.
///
/// Формально не входит в дословный список пунктов 3.5.1–3.5.5, но без
/// него «Далее» на экране показания создавал бы Payment без единого
/// способа его увидеть или довести до оплаты — сквозная связка
/// (сценарий 2.5) была бы не по-настоящему сквозной.
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

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  PaymentRow? _payment;

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
      final repo = ref.read(paymentRepositoryProvider);
      await repo.refresh();
      final payment = await repo.getById(widget.paymentId);
      setState(() {
        _payment = payment;
        _amountController.text = payment?.calculatedAmount.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final updated = await ref.read(paymentRepositoryProvider).recordPayment(
            paymentId: widget.paymentId,
            actualAmount: amount,
            paymentDate: _paymentDate,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payment == null
              ? Center(child: Text('Платёж не найден. ${_error ?? ''}'))
              : Padding(
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
                        const SizedBox(height: 12),
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
