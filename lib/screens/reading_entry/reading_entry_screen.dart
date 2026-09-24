import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../providers/channel_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reading_provider.dart';

/// Ввод показания + расчёт суммы (ТЗ §4.2–4.3, схема 2.5, сценарий 2:
/// «Далее» создаёт Payment и открывает экран оплаты). Этап 3.5.2–3.5.3.
///
/// Минимальная версия: поставщик типа with_readings ровно с одним
/// каналом — форма 3.5.1 всегда создаёт поставщика с одним каналом.
/// Несколько/производные каналы, тип without_readings — Этап 4 (экран 4.3).
///
/// Если у канала ещё нет ни одного показания — это его первое показание:
/// расход посчитать не от чего, поэтому платёж не создаётся, показание
/// просто сохраняется как отправная точка. Полноценная обработка
/// «первого показания» — отдельный будущий пункт плана (5.3); здесь —
/// только чтобы тончайшая связка не падала на пустом канале. По той же
/// причине reading_snapshot платежа не заполняется (5.4 — тоже будущий
/// пункт).
class ReadingEntryScreen extends ConsumerStatefulWidget {
  const ReadingEntryScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends ConsumerState<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  ChannelRow? _channel;
  ReadingRow? _previous;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final channelRepo = ref.read(channelRepositoryProvider);
      final readingRepo = ref.read(readingRepositoryProvider);
      await channelRepo.refresh();
      final channels = await channelRepo.watchForSupplier(widget.supplierId).first;
      if (channels.isEmpty) {
        setState(() {
          _error = 'У поставщика нет канала — форма добавления должна '
              'была создать его вместе с поставщиком.';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final channel = _channel;
    if (channel == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final value = double.parse(_valueController.text.replaceAll(',', '.'));
      await ref.read(readingRepositoryProvider).create(
            channelId: channel.id,
            value: value,
            readingDate: DateTime.now(),
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
            period: DateTime(DateTime.now().year, DateTime.now().month, 1),
            consumption: consumption,
            calculatedAmount: amount,
          );
      if (!mounted) return;
      context.go('/suppliers/${widget.supplierId}/payment/${payment.id}');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Показание')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return 'Введите число';
                        }
                        return null;
                      },
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
                      onPressed: (_submitting || _channel == null) ? null : _submit,
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
}
