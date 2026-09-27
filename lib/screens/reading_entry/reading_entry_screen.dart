import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../models/supplier.dart';
import '../../providers/channel_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/supplier_provider.dart';

/// Ввод показаний (with_readings) или суммы к оплате (without_readings) —
/// ТЗ §4.2–4.3, схема §2.5, сценарий 2: «Далее» создаёт Payment и
/// открывает экран оплаты.
///
/// with_readings, полная версия (Этап 5, п. 5.1 + 5.3 + 5.4 — сделаны
/// одним шагом, т.к. на деле это один и тот же код: экран строит поле
/// ввода на каждый «обычный» канал поставщика (их может быть несколько,
/// ТЗ §4.1), для производного канала (source_channel_id заполнено) поле
/// ввода не показывается — значения previous/current копируются из
/// reading_snapshot платежа поставщика канала-источника за тот же период
/// (ТЗ §4.2–4.3). Расход и сумма считаются по каждому каналу отдельно
/// (свой тариф) и суммируются в итоговую сумму платежа; результат виден
/// заранее как предпросмотр, до создания Payment (ТЗ §4.3). При создании
/// платежа собранные значения фиксируются в Payment.reading_snapshot —
/// неизменяемый снимок (5.4).
///
/// «Первое показание» по каналу (нет предыдущего — расход не считается)
/// не блокирует платёж по остальным каналам (решение Олега, см. журнал
/// 5.1): показание сохраняется как отправная точка, канал просто не
/// входит в сумму за этот период, о чём пользователь предупреждается.
/// Та же логика — для производного канала, чей источник ещё не имеет
/// показания за период (ТЗ §4.2: «ввод временно недоступен»): здесь это
/// не блокирует ввод, а просто исключает канал из суммы с тем же
/// предупреждением. Если пропущены вообще все каналы — платёж не
/// создаётся вовсе (как в прежнем однока��альном MVP).
///
/// Не входит в этот пункт: флаг meter_replaced в UI (checkbox) — отдельный
/// п. 5.2, следующим шагом; ReadingRepository.create уже поддерживает
/// параметр, здесь просто не передаётся (по умолчанию false), ошибка
/// понижения показания всплывает как текст, как и раньше. Многоуровневая
/// производность (канал-источник сам производный) не рассматривается —
/// в ТЗ описан только один уровень.
///
/// without_readings — без изменений на этом пункте: сумма к оплате
/// вводится вручную, период редактируется отдельным полем, Payment без
/// reading_snapshot/consumption (ТЗ §4.3, §7).
class ReadingEntryScreen extends ConsumerStatefulWidget {
  const ReadingEntryScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends ConsumerState<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _readingDate = DateTime.now();
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  SupplierRow? _supplier;

  List<ChannelRow> _channels = [];
  final Map<String, TextEditingController> _valueControllers = {};
  final Map<String, ReadingRow?> _previous = {};
  final Map<String, ChannelRow?> _sourceChannel = {};
  final Map<String, ReadingSnapshotEntry?> _derivedEntry = {};

  bool get _isWithoutReadings =>
      _supplier != null && SupplierType.fromDb(_supplier!.type) == SupplierType.withoutReadings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (final c in _valueControllers.values) {
      c.dispose();
    }
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
      await readingRepo.refresh();
      final channels = await channelRepo.watchForSupplier(widget.supplierId).first;
      if (channels.isEmpty) {
        setState(() {
          _error = 'У поставщика нет ни одного канала.';
          _loading = false;
        });
        return;
      }
      channels.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final channel in channels) {
        if (channel.sourceChannelId == null) {
          _valueControllers[channel.id] = TextEditingController()
            ..addListener(() => setState(() {}));
          _previous[channel.id] = await readingRepo.getLatestForChannel(channel.id);
        }
      }
      _channels = channels;
      setState(() => _loading = false);
      await _loadDerivedData();
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Подтягивает для каждого производного канала previous/current из
  /// reading_snapshot платежа канала-источника за тот же период (ТЗ
  /// §4.2–4.3) — период зависит от [_readingDate], поэтому вызывается и
  /// при первой загрузке, и при смене даты показания.
  Future<void> _loadDerivedData() async {
    final channelRepo = ref.read(channelRepositoryProvider);
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final period = DateTime(_readingDate.year, _readingDate.month, 1);

    for (final channel in _channels) {
      final sourceId = channel.sourceChannelId;
      if (sourceId == null) continue;
      final source = await channelRepo.getById(sourceId);
      _sourceChannel[channel.id] = source;
      if (source == null) {
        _derivedEntry[channel.id] = null;
        continue;
      }
      final sourcePayment = await paymentRepo.getForSupplierAndPeriod(source.supplierId, period);
      final snapshotJson = sourcePayment?.readingSnapshot;
      if (snapshotJson == null) {
        _derivedEntry[channel.id] = null;
        continue;
      }
      final entries = (jsonDecode(snapshotJson) as List<dynamic>)
          .map((e) => ReadingSnapshotEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      ReadingSnapshotEntry? match;
      for (final entry in entries) {
        if (entry.channelId == source.id) {
          match = entry;
          break;
        }
      }
      _derivedEntry[channel.id] = match;
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickReadingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _readingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _readingDate = picked);
      await _loadDerivedData();
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

  /// Строка предпросмотра по каналу — только для тех, где уже есть все
  /// данные для расчёта (ТЗ §4.3: показывать предпросмотр до создания
  /// платежа).
  ({double amount, String line})? _previewFor(ChannelRow channel) {
    if (channel.sourceChannelId == null) {
      final text = _valueControllers[channel.id]?.text.trim() ?? '';
      final value = double.tryParse(text.replaceAll(',', '.'));
      final previous = _previous[channel.id];
      if (value == null || previous == null) return null;
      final consumption = value - previous.value;
      final amount = consumption * channel.tariff;
      return (
        amount: amount,
        line: '${channel.name}: $consumption ${channel.unit} × ${channel.tariff} ₽ '
            '= ${amount.toStringAsFixed(2)} ₽',
      );
    }
    final derived = _derivedEntry[channel.id];
    if (derived == null) return null;
    final amount = derived.consumption * channel.tariff;
    return (
      amount: amount,
      line: '${channel.name} (произв.): ${derived.consumption} ${channel.unit} × '
          '${channel.tariff} ₽ = ${amount.toStringAsFixed(2)} ₽',
    );
  }

  Future<void> _submitWithReadings() async {
    final readingRepo = ref.read(readingRepositoryProvider);
    final period = DateTime(_readingDate.year, _readingDate.month, 1);
    final entries = <ReadingSnapshotEntry>[];
    final skipped = <String>[];

    for (final channel in _channels) {
      if (channel.sourceChannelId == null) {
        final value = double.parse(_valueControllers[channel.id]!.text.replaceAll(',', '.'));
        await readingRepo.create(
          channelId: channel.id,
          value: value,
          readingDate: _readingDate,
        );
        final previous = _previous[channel.id];
        if (previous == null) {
          skipped.add('${channel.name} (первое показание)');
          continue;
        }
        entries.add(
          ReadingSnapshotEntry(
            channelId: channel.id,
            channelName: channel.name,
            unit: channel.unit,
            previousValue: previous.value,
            currentValue: value,
            tariff: channel.tariff,
            readingDate: _readingDate,
          ),
        );
      } else {
        final derived = _derivedEntry[channel.id];
        if (derived == null) {
          skipped.add('${channel.name} (нет показания источника за этот период)');
          continue;
        }
        entries.add(
          ReadingSnapshotEntry(
            channelId: channel.id,
            channelName: channel.name,
            unit: channel.unit,
            previousValue: derived.previousValue,
            currentValue: derived.currentValue,
            tariff: channel.tariff,
            readingDate: _readingDate,
          ),
        );
      }
    }

    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Показания сохранены как отправная точка. Расход посчитать не от '
            'чего — платёж не создан.',
          ),
        ),
      );
      context.go('/suppliers');
      return;
    }

    final totalAmount = entries.fold<double>(0, (sum, e) => sum + e.amount);
    final payment = await ref.read(paymentRepositoryProvider).create(
          supplierId: widget.supplierId,
          period: period,
          readingSnapshot: entries,
          calculatedAmount: totalAmount,
        );

    if (!mounted) return;
    if (skipped.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Без учёта в сумме: ${skipped.join(', ')}.')),
      );
    }
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
    final canSubmit = _isWithoutReadings || _channels.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(_isWithoutReadings ? 'Сумма к оплате' : 'Показания')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
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
                        onPressed: (_submitting || !canSubmit) ? null : _submit,
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
            ),
    );
  }

  List<Widget> _withReadingsFields() {
    final previews = <String>[];
    var total = 0.0;
    for (final channel in _channels) {
      final preview = _previewFor(channel);
      if (preview != null) {
        previews.add(preview.line);
        total += preview.amount;
      }
    }

    return [
      for (final channel in _channels) ..._channelFields(channel),
      const SizedBox(height: 8),
      Row(
        children: [
          Text('Дата показания: ${_readingDate.day}.${_readingDate.month}.${_readingDate.year}'),
          TextButton(onPressed: _pickReadingDate, child: const Text('Изменить')),
        ],
      ),
      if (previews.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Предпросмотр', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final line in previews) Text(line),
        const SizedBox(height: 4),
        Text(
          'Итого: ${total.toStringAsFixed(2)} ₽',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ];
  }

  List<Widget> _channelFields(ChannelRow channel) {
    if (channel.sourceChannelId == null) {
      final previous = _previous[channel.id];
      return [
        Text(
          '${channel.name}${previous == null ? ' — первое показание' : ''}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (previous != null)
          Text('Предыдущее: ${previous.value} ${channel.unit}'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _valueControllers[channel.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Текущее показание, ${channel.unit}'),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Введите показание';
            if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Введите число';
            return null;
          },
        ),
        const SizedBox(height: 16),
      ];
    }

    final source = _sourceChannel[channel.id];
    final derived = _derivedEntry[channel.id];
    return [
      Text(
        '${channel.name} — производный${source != null ? ' (из «${source.name}»)' : ''}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        derived == null
            ? 'Нет показания канала-источника за этот период — временно недоступен.'
            : 'Расход из канала-источника: ${derived.previousValue} → ${derived.currentValue} '
                '${channel.unit}',
      ),
      const SizedBox(height: 16),
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
