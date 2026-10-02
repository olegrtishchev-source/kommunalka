import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../models/supplier.dart';
import '../../providers/payment_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../utils/amount_format.dart';
import '../../utils/bank_details_format.dart';
import '../../utils/date_format.dart';
import '../../utils/payment_qr_builder.dart';

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
        _amountController.text =
            payment == null ? '' : formatNumber(payment.calculatedAmount);
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

  /// Показ QR-кода для оплаты (ТЗ §4.4, п. 5.12): формирует строку ST00012,
  /// отрисовывает QR и даёт сохранить/поделиться.
  Future<void> _showPaymentQr() async {
    final payment = _payment;
    final supplier = _supplier;
    if (payment == null || supplier == null) return;
    final String qrData;
    try {
      qrData = buildPaymentQr(_supplierFromRow(supplier), _paymentFromRow(payment));
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('QR для оплаты'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: qrData, size: 240),
            const SizedBox(height: 12),
            const Text(
              'Загрузите QR как изображение в банковском приложении.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _saveQr(qrData),
            child: const Text('Сохранить в галерею'),
          ),
          TextButton(
            onPressed: () => _shareQr(qrData),
            child: const Text('Поделиться'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveQr(String qrData) async {
    try {
      final bytes = await _qrPngBytes(qrData);
      await Gal.putImageBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR сохранён в галерею.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить QR: $e')),
      );
    }
  }

  Future<void> _shareQr(String qrData) async {
    try {
      final bytes = await _qrPngBytes(qrData);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: 'qr.png'),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось поделиться QR: $e')),
      );
    }
  }

  /// Рисует QR-строку в PNG-байты (для сохранения в галерею и «Поделиться»).
  Future<Uint8List> _qrPngBytes(String data) async {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final painter = QrPainter.withQr(qr: qr);
    const size = 400.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(size, size));
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Supplier _supplierFromRow(SupplierRow r) {
    return Supplier(
      id: r.id,
      userId: r.userId,
      name: r.name,
      category: r.category,
      type: SupplierType.fromDb(r.type),
      bankDetails: r.bankDetails == null
          ? null
          : BankDetails.fromJson(
              Map<String, dynamic>.from(jsonDecode(r.bankDetails!) as Map),
            ),
      paymentPurposeTemplate: r.paymentPurposeTemplate,
      personalAccount: r.personalAccount,
      cabinetUrl: r.cabinetUrl,
      readingEmail: r.readingEmail,
      archivedAt: r.archivedAt,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Payment _paymentFromRow(PaymentRow r) {
    return Payment(
      id: r.id,
      userId: r.userId,
      supplierId: r.supplierId,
      period: r.period,
      calculatedAmount: r.calculatedAmount,
      actualAmount: r.actualAmount,
      status: PaymentStatus.fromDb(r.status),
      paymentDate: r.paymentDate,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
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
                          'Расчётная сумма: ${formatAmount(_payment!.calculatedAmount)}',
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
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _showPaymentQr,
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('QR для оплаты'),
                        ),
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
                            Text('Дата оплаты: ${formatDate(_paymentDate)}'),
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
                            Text('Период: ${formatPeriod(_period)}'),
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
