import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/supplier.dart';
import '../../providers/channel_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/supplier_provider.dart';

/// Ввод показания (with_readings) или суммы к оплате (without_readings) —
/// ТЗ §4.2–4.3, схема §2.5, сценарий 2: «Далее» создаёт Payment и
/// открывает экран оплаты. with_readings — часть Этапа 3.5.2–3.5.3,
/// without_readings — добавлено на 4.3.
///
/// with_readings — по-прежнему минимальная версия с Этапа 3.5: поставщик
/// берётся ровно с одним (первым) каналом. Несколько каналов за раз,
/// производные каналы (расход из канала-источника) и флаг meter_replaced
/// в UI — сознательно не входят в 4.3, это отдельные пункты Этапа 5
/// (5.1–5.3), хотя форма 4.2 уже умеет заводить несколько каналов на
/// поставщика. Проверка «нельзя понизить показание» уже работает на
/// уровне ReadingRepository.create (MeterValueDecreasedException) — здесь
/// её ошибка просто всплывает как текст, без отдельного UI на meter_replaced.
///
/// without_readings — сумма к оплате вводится вручную; период (в отличие
/// от with_readings) не выводится из даты показания — берётся текущий
/// месяц по умолчанию, редактируется явным полем. Payment создаётся без
/// reading_snapshot и без consumption (ТЗ §4.3, §7).
///
/// Если по каналу ещё нет ни одного показания — это его первое показание:
/// расход посчитать не от чего, поэтому платёж не создаётся, показание
/// просто сохраняется как отправная точка. Полноценная обработка
/// «первого показания» — отдельный будущий пункт плана (5.3); здесь —
/// только чтобы форма не падала на пустом канале. По той же причине
/// reading_snapshot платежа не заполняется (5.4 — тоже будущий пункт).
class ReadingEntryScreen extends ConsumerStatefulWidget {
  const ReadingEntryScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends ConsumerState<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _readingDate = DateTime.now();
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  SupplierRow? _supplier;
  ChannelRow? _channel;
  ReadingRow? _previous;

  bool get _isWithoutReadings =>
      _supplier != null && SupplierType.fromDb(_supplier!.type) == SupplierType.withoutReadings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final supplierRepo = ref.read(supplierRepositoryProvider);
      await supplierRepo.refresh();
      final supplier = await supplierRepo.getById(widget.supplierId);
      if (supplier == null) {
        setState(() {
          _error = 'Поставщик не найден';
          _loading = false;
        });
        return;
      }
      _supplier = supplier;

      if (SupplierType.fromDb(supplier.type) == SupplierType.withoutReadings) {
        setState(() => _loading = false);
        return;
      }

      final channelRepo = ref.read(channelRepositoryProvider);
      final readingRepo = ref.read(readingRepositoryProvider);
      await channelRepo.refresh();
      final channels = await channelRepo.watchForSupplier(widget.supplierId).first;
      if (channels.isEmpty) {
        setState(() {
          _error = 'У поставщика нет ни одного канала.';
          _loading = false;
        });
        return;
      }
      final channel = channels.first;
      await readingRepo.refresh();
      final previous = await readingRepo.getLatestForChannel(channel.id);
      setState(() {
        _channel = channel;
        _previous = previous;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pickReadingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _readingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _readingDate = picked);
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

  Future<void> _submitWithReadings() async {
    final channel = _channel;
    if (channel == null) return;
    final value = double.parse(_valueController.text.replaceAll(',', '.'));
    await ref.read(readingRepositoryProvider).create(
          channelId: channel.id,
          value: value,
          readingDate: _readingDate,
        );

    final previous = _previous;
    if (previous == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Это первое показание — сохранено как отправная точка. '
            'Расчёт суммы появится со следующего показания.',
          ),
        ),
      );
      context.go('/suppliers');
      return;
    }

    final consumption = value - previous.value;
    final amount = consumption * channel.tariff;
    final payment = await ref.read(paymentRepositoryProvider).create(
          supplierId: widget.supplierId,
          period: DateTime(_readingDate.year, _readingDate.month, 1),
          consumption: consumption,
          calculatedAmount: amount,
        );
    if (!mounted) return;
    context.go('/suppliers/${widget.supplierId}/payment/${payment.id}');
  }

  Future<void> _submitWithoutReadings() async {
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final payment = await ref.read(paymentRepositoryProvider).create(
          supplierId: widget.supplierId,
          period: _period,
          calculatedAmount: amount,
        );
    if (!mounted) return;
    context.go('/suppliers/${widget.supplierId}/payment/${payment.id}');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isWithoutReadings) {
        await _submitWithoutReadings();
      } else {
        await _submitWithReadings();
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isWithoutReadings ? 'Сумма к оплате' : 'Показание')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isWithoutReadings)
                      ..._withoutReadingsFields()
                    else
                      ..._withReadingsFields(),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: (_submitting || (!_isWithoutReadings && _channel == null))
                          ? null
                          : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Далее'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _withReadingsFields() {
    return [
      Text(
        _previous == null
            ? 'Предыдущих показаний нет — это первое.'
            : 'Предыдущее показание: ${_previous!.value} ${_channel?.unit ?? ''}',
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _valueController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Текущее показание, ${_channel?.unit ?? ''}',
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите показание';
          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Введите число';
          return null;
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text(
            'Дата показания: '
            '${_readingDate.day}.${_readingDate.month}.${_readingDate.year}',
          ),
          TextButton(onPressed: _pickReadingDate, child: const Text('Изменить')),
        ],
      ),
    ];
  }

  List<Widget> _withoutReadingsFields() {
    return [
      TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Сумма к оплате, ₽'),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите сумму';
          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Введите число';
          return null;
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text('Период: ${_period.month}.${_period.year}'),
          TextButton(onPressed: _pickPeriod, child: const Text('Изменить')),
        ],
      ),
    ];
  }
}
