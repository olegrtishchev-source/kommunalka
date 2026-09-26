import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/channel.dart';
import '../../models/supplier.dart';
import '../../providers/channel_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../repositories/channel_repository.dart';

/// Добавление/редактирование поставщика (ТЗ §4.1, схема §2.5: /suppliers/new
/// и /suppliers/:id/edit — один и тот же экран, режим определяется тем,
/// передан ли [supplierId]).
///
/// Поля: название, категория (свободный текст — по ней на клиенте
/// подбирается иконка, см. lib/utils/supplier_category_icon.dart),
/// тип (с показаниями / без показаний), реквизиты для оплаты, шаблон
/// назначения платежа. Для типа «с показаниями» — один или несколько
/// каналов показаний (кнопка «Добавить канал», ТЗ §4.1); канал может быть
/// производным — тогда расход берётся из выбранного канала-источника
/// (в т.ч. у другого поставщика) за тот же период, свои показания по нему
/// не вводятся.
///
/// Известные упрощения: смена типа с «с показаниями» на «без показаний»
/// у поставщика, у которого уже есть каналы/показания, не удаляет и не
/// трогает существующие данные — они просто перестают быть видны в этой
/// форме (сама механика ввода суммы для without_readings — ещё не
/// реализованный п. 4.3). Канал с уже сохранёнными показаниями нельзя
/// удалить из формы (ТЗ §4.1) — попытка показывает объяснение и не
/// убирает канал из списка. Шаблон назначения платежа — просто текстовое
/// поле, подстановка {месяц}/{год} в нём пока не реализована (не входит в
/// явные пункты плана, добавим при необходимости).
class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplierId});

  /// null — создание нового поставщика; иначе — редактирование.
  final String? supplierId;

  bool get isEditing => supplierId != null;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _ChannelFormEntry {
  _ChannelFormEntry({this.existing, String? name, String? unit, String? tariff, this.sourceChannelId})
      : nameController = TextEditingController(text: name ?? ''),
        unitController = TextEditingController(text: unit ?? ''),
        tariffController = TextEditingController(text: tariff ?? '');

  /// null — новый канал, ещё не создан в Supabase.
  final ChannelRow? existing;
  final TextEditingController nameController;
  final TextEditingController unitController;
  final TextEditingController tariffController;
  /// id канала-источника — если заполнено, канал производный (ТЗ §4.1).
  String? sourceChannelId;

  void dispose() {
    nameController.dispose();
    unitController.dispose();
    tariffController.dispose();
  }
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _paymentPurposeController = TextEditingController();
  final _recipientController = TextEditingController();
  final _innController = TextEditingController();
  final _kppController = TextEditingController();
  final _bikController = TextEditingController();
  final _accountController = TextEditingController();

  SupplierType _type = SupplierType.withReadings;
  final List<_ChannelFormEntry> _channelEntries = [];
  List<ChannelRow> _allChannels = [];
  Map<String, String> _supplierNameById = {};
  SupplierRow? _existingSupplier;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _paymentPurposeController.dispose();
    _recipientController.dispose();
    _innController.dispose();
    _kppController.dispose();
    _bikController.dispose();
    _accountController.dispose();
    for (final entry in _channelEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final supplierRepo = ref.read(supplierRepositoryProvider);
      final channelRepo = ref.read(channelRepositoryProvider);
      await supplierRepo.refresh();
      await channelRepo.refresh();
      final suppliers = await supplierRepo.watchAll().first;
      final channels = await channelRepo.watchAll().first;
      _supplierNameById = {for (final s in suppliers) s.id: s.name};
      _allChannels = channels;

      if (widget.isEditing) {
        SupplierRow? supplier;
        for (final s in suppliers) {
          if (s.id == widget.supplierId) {
            supplier = s;
            break;
          }
        }
        if (supplier == null) {
          setState(() {
            _error = 'Поставщик не найден';
            _loading = false;
          });
          return;
        }
        _existingSupplier = supplier;
        _nameController.text = supplier.name;
        _categoryController.text = supplier.category ?? '';
        _paymentPurposeController.text = supplier.paymentPurposeTemplate ?? '';
        _type = SupplierType.fromDb(supplier.type);
        final bankDetailsJson = supplier.bankDetails;
        if (bankDetailsJson != null) {
          final details = BankDetails.fromJson(
            Map<String, dynamic>.from(jsonDecode(bankDetailsJson) as Map),
          );
          _recipientController.text = details.recipient ?? '';
          _innController.text = details.inn ?? '';
          _kppController.text = details.kpp ?? '';
          _bikController.text = details.bik ?? '';
          _accountController.text = details.accountNumber ?? '';
        }
        _channelEntries.addAll(
          channels.where((c) => c.supplierId == widget.supplierId).map(
                (c) => _ChannelFormEntry(
                  existing: c,
                  name: c.name,
                  unit: c.unit,
                  tariff: c.tariff.toString(),
                  sourceChannelId: c.sourceChannelId,
                ),
              ),
        );
      }
      if (_channelEntries.isEmpty) {
        _channelEntries.add(_ChannelFormEntry());
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _addChannel() {
    setState(() => _channelEntries.add(_ChannelFormEntry()));
  }

  Future<void> _removeChannel(int index) async {
    final entry = _channelEntries[index];
    if (entry.existing != null) {
      try {
        await ref.read(channelRepositoryProvider).delete(entry.existing!.id);
      } on ChannelHasReadingsException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'У канала уже есть сохранённые показания — удалить нельзя, '
              'доступно только переименование (ТЗ §4.1).',
            ),
          ),
        );
        return;
      } catch (e) {
        setState(() => _error = '$e');
        return;
      }
    }
    setState(() {
      entry.dispose();
      _channelEntries.removeAt(index);
    });
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null;

  String? _numberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введите число';
    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Введите число';
    return null;
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  bool get _hasAnyBankField =>
      _recipientController.text.trim().isNotEmpty ||
      _innController.text.trim().isNotEmpty ||
      _kppController.text.trim().isNotEmpty ||
      _bikController.text.trim().isNotEmpty ||
      _accountController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final bankDetails = _hasAnyBankField
          ? BankDetails(
              recipient: _emptyToNull(_recipientController.text),
              inn: _emptyToNull(_innController.text),
              kpp: _emptyToNull(_kppController.text),
              bik: _emptyToNull(_bikController.text),
              accountNumber: _emptyToNull(_accountController.text),
            )
          : null;

      final supplierRepo = ref.read(supplierRepositoryProvider);
      final channelRepo = ref.read(channelRepositoryProvider);

      final Supplier supplier;
      if (widget.isEditing) {
        final existing = _existingSupplier!;
        supplier = await supplierRepo.update(
          Supplier(
            id: existing.id,
            userId: existing.userId,
            name: _nameController.text.trim(),
            category: _emptyToNull(_categoryController.text),
            type: _type,
            bankDetails: bankDetails,
            paymentPurposeTemplate: _emptyToNull(_paymentPurposeController.text),
            archivedAt: existing.archivedAt,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ),
        );
      } else {
        supplier = await supplierRepo.create(
          name: _nameController.text.trim(),
          category: _emptyToNull(_categoryController.text),
          type: _type,
          bankDetails: bankDetails,
          paymentPurposeTemplate: _emptyToNull(_paymentPurposeController.text),
        );
      }

      if (_type == SupplierType.withReadings) {
        for (final entry in _channelEntries) {
          final name = entry.nameController.text.trim();
          final unit = entry.unitController.text.trim();
          final tariff = double.parse(entry.tariffController.text.replaceAll(',', '.'));
          if (entry.existing != null) {
            final existingChannel = entry.existing!;
            await channelRepo.update(
              Channel(
                id: existingChannel.id,
                userId: existingChannel.userId,
                supplierId: supplier.id,
                name: name,
                unit: unit,
                tariff: tariff,
                sourceChannelId: entry.sourceChannelId,
                createdAt: existingChannel.createdAt,
                updatedAt: existingChannel.updatedAt,
              ),
            );
          } else {
            await channelRepo.create(
              supplierId: supplier.id,
              name: name,
              unit: unit,
              tariff: tariff,
              sourceChannelId: entry.sourceChannelId,
            );
          }
        }
      }

      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<ChannelRow> _availableSources(_ChannelFormEntry entry) {
    return _allChannels.where((c) => c.id != entry.existing?.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Редактирование поставщика' : 'Новый поставщик'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Название поставщика'),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Категория (напр. Вода, Электричество)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<SupplierType>(
                      segments: const [
                        ButtonSegment(
                          value: SupplierType.withReadings,
                          label: Text('С показаниями'),
                        ),
                        ButtonSegment(
                          value: SupplierType.withoutReadings,
                          label: Text('Без показаний'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (selection) =>
                          setState(() => _type = selection.first),
                    ),
                    const SizedBox(height: 20),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Реквизиты для оплаты'),
                      initiallyExpanded: _hasAnyBankField,
                      children: [
                        TextFormField(
                          controller: _recipientController,
                          decoration: const InputDecoration(labelText: 'Получатель'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _innController,
                          decoration: const InputDecoration(labelText: 'ИНН'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _kppController,
                          decoration: const InputDecoration(labelText: 'КПП'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bikController,
                          decoration: const InputDecoration(labelText: 'БИК'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _accountController,
                          decoration: const InputDecoration(labelText: 'Номер счёта'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _paymentPurposeController,
                          decoration: const InputDecoration(
                            labelText: 'Шаблон назначения платежа',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_type == SupplierType.withReadings) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Каналы показаний',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addChannel,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить канал'),
                          ),
                        ],
                      ),
                      for (final entry in _channelEntries.asMap().entries)
                        _ChannelCard(
                          index: entry.key,
                          entry: entry.value,
                          canRemove: _channelEntries.length > 1,
                          sources: _availableSources(entry.value),
                          supplierNameById: _supplierNameById,
                          onRemove: () => _removeChannel(entry.key),
                          onSourceChanged: (id) =>
                              setState(() => entry.value.sourceChannelId = id),
                          requiredValidator: _requiredValidator,
                          numberValidator: _numberValidator,
                        ),
                    ],
                    const SizedBox(height: 12),
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

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.sources,
    required this.supplierNameById,
    required this.onRemove,
    required this.onSourceChanged,
    required this.requiredValidator,
    required this.numberValidator,
  });

  final int index;
  final _ChannelFormEntry entry;
  final bool canRemove;
  final List<ChannelRow> sources;
  final Map<String, String> supplierNameById;
  final VoidCallback onRemove;
  final ValueChanged<String?> onSourceChanged;
  final String? Function(String?) requiredValidator;
  final String? Function(String?) numberValidator;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Канал ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: canRemove ? 'Удалить канал' : 'Должен остаться хотя бы один канал',
                  onPressed: canRemove ? onRemove : null,
                ),
              ],
            ),
            TextFormField(
              controller: entry.nameController,
              decoration: const InputDecoration(labelText: 'Название канала'),
              validator: requiredValidator,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.unitController,
              decoration: const InputDecoration(labelText: 'Единица измерения'),
              validator: requiredValidator,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.tariffController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Тариф, ₽ за единицу'),
              validator: numberValidator,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: entry.sourceChannelId,
              decoration: const InputDecoration(labelText: 'Источник расхода'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Свои показания'),
                ),
                for (final c in sources)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text('${supplierNameById[c.supplierId] ?? '?'} — ${c.name}'),
                  ),
              ],
              onChanged: onSourceChanged,
            ),
          ],
        ),
      ),
    );
  }
}
