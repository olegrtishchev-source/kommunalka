import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/supplier.dart';
import '../../providers/channel_provider.dart';
import '../../providers/supplier_provider.dart';

/// Добавление поставщика (ТЗ §4.1, сценарий 1 из схемы 2.5). Минимальная
/// форма для Этапа 3.5.1: формулировка ТЗ §10 «один поставщик, один
/// тариф, без каналов» на практике означает один поставщик с одним
/// неявным каналом — без канала (§7) негде хранить тариф и показания,
/// а поддержка нескольких каналов на поставщика — Этап 4. Поэтому форма
/// создаёт Supplier и его единственный Channel одним шагом; название
/// канала отдельно не спрашивается — совпадает с названием поставщика
/// (получит собственное имя, когда на Этапе 4 появится управление
/// несколькими каналами).
///
/// Тип поставщика — всегда with_readings: сценарий without_readings
/// (сумма без счётчика, ввод суммы напрямую) в тончайшую связку не
/// входит, это тоже Этап 4 (экран 4.2).
///
/// Известное упрощение: создание поставщика и канала — два отдельных
/// запроса к Supabase, без транзакции; если второй (канал) не пройдёт
/// после успешного первого (поставщик), получится поставщик без канала.
/// Для одного тестового пользователя на этапе MVP это некритично —
/// см. журнал плана.
class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _tariffController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _tariffController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final supplier = await ref.read(supplierRepositoryProvider).create(
            name: _nameController.text.trim(),
            type: SupplierType.withReadings,
          );
      await ref.read(channelRepositoryProvider).create(
            supplierId: supplier.id,
            name: supplier.name,
            unit: _unitController.text.trim(),
            tariff: double.parse(_tariffController.text.replaceAll(',', '.')),
          );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый поставщик')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название поставщика'),
                validator: (v) => (v == null || v.isEmpty) ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Единица измерения (напр. м³, кВт·ч)',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Введите единицу' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tariffController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Тариф, ₽ за единицу'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите тариф';
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
