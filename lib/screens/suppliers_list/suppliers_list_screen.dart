import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../utils/payment_status_format.dart';
import '../../utils/supplier_category_icon.dart';

/// Действие, выбранное в меню свайпа по поставщику.
enum _SupplierSwipeAction { archive, delete }

/// Список поставщиков — главный экран приложения (ТЗ §4.1, §4.9 — теперь
/// первая вкладка нижней навигации, не единственный экран приложения, как
/// было на 3.5.1). Карточки (Card, не просто строки списка), значок по
/// категории, бейдж статуса платежа за текущий период. Нажатие ведёт на
/// карточку поставщика (/suppliers/:id) — там решается, куда дальше
/// (ввод показаний или уже созданный платёж, см. SupplierCardScreen);
/// раньше эта развилка (журнал 3.5.4) была прямо тут, теперь — там, где
/// ей и место по схеме навигации §2.5.
///
/// Свайп влево — архивирование (мягкое удаление, ТЗ §4.1) с подтверждением
/// в диалоге, чтобы не архивировать поставщика случайным движением пальца.
/// Просмотр архивных поставщиков и их разархивирование в UI пока не
/// предусмотрены (нет такого пункта ни в ТЗ, ни в плане) — данные не
/// теряются (archived_at, а не удаление), вернуть обратно можно вручную
/// через Supabase, если понадобится.
class SuppliersListScreen extends ConsumerStatefulWidget {
  const SuppliersListScreen({super.key});

  @override
  ConsumerState<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends ConsumerState<SuppliersListScreen> {
  /// Выбранный адрес-фильтр (ТЗ §4.13); null — «Все» (без фильтра).
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    // Разовая подтяжка кеша из Supabase при открытии экрана (ТЗ §4.7).
    Future.microtask(() async {
      ref.read(supplierRepositoryProvider).refresh();
      ref.read(paymentRepositoryProvider).refresh();
      final settings = await ref.read(settingsServiceProvider.future);
      if (!mounted) return;
      setState(() => _selectedAddress = settings.selectedAddress);
    });
  }

  Future<void> _selectAddress(String? address) async {
    setState(() => _selectedAddress = address);
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setSelectedAddress(address);
  }

  Future<bool> _confirmArchive(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Архивировать поставщика?'),
        content: Text(
          '«$name» пропадёт из списка. Показания и платежи по нему '
          'останутся в истории без изменений.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Архивировать'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Архивирует поставщика по свайпу. Возвращает true, только если запись
  /// реально прошла (иначе элемент остаётся в списке и показывается ошибка) —
  /// раньше archive() вызывался без await (fire-and-forget), и при сетевом
  /// сбое поставщик не архивировался в Supabase, но исчезал из списка.
  Future<bool> _archiveSupplier(String id, String name) async {
    try {
      await ref.read(supplierRepositoryProvider).archive(id);
      return true;
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Не удалось архивировать «$name»: $e')),
      );
      return false;
    }
  }

  /// Полное удаление поставщика по свайпу (необратимо). Возвращает true,
  /// если удаление прошло (элемент убирается из списка).
  Future<bool> _deleteSupplier(String id, String name) async {
    try {
      await ref.read(supplierRepositoryProvider).deleteCompletely(id);
      return true;
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Не удалось удалить «$name»: $e')),
      );
      return false;
    }
  }

  /// Меню действий при свайпе влево: «Архивировать» (обратимо) или
  /// «Удалить» (полностью, необратимо). Возвращает true, если элемент нужно
  /// убрать из списка (архивация/удаление прошли), иначе false.
  Future<bool> _showSwipeActions(
    BuildContext context,
    String id,
    String name,
  ) async {
    final action = await showModalBottomSheet<_SupplierSwipeAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                name,
                style: Theme.of(ctx).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Архивировать'),
              subtitle: const Text(
                'Скрыть из списка; история сохранится, можно вернуть.',
              ),
              onTap: () =>
                  Navigator.pop(ctx, _SupplierSwipeAction.archive),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Удалить',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              subtitle: const Text(
                'Удалить навсегда со всеми показаниями, платежами и чеками.',
              ),
              onTap: () => Navigator.pop(ctx, _SupplierSwipeAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return false;
    if (action == _SupplierSwipeAction.archive) {
      final confirmed = await _confirmArchive(context, name);
      if (!confirmed) return false;
      if (!context.mounted) return false;
      return _archiveSupplier(id, name);
    }
    if (action == _SupplierSwipeAction.delete) {
      final confirmed = await _confirmDelete(context, id, name);
      if (!confirmed) return false;
      if (!context.mounted) return false;
      return _deleteSupplier(id, name);
    }
    return false;
  }

  /// Подтверждение полного удаления с предупреждением о количестве связанных
  /// данных (платежи, чеки) — действие необратимо.
  Future<bool> _confirmDelete(
    BuildContext context,
    String id,
    String name,
  ) async {
    SupplierDeletionImpact impact;
    try {
      impact = await ref
          .read(supplierRepositoryProvider)
          .deletionImpact(id);
    } catch (_) {
      impact = SupplierDeletionImpact(payments: 0, receipts: 0);
    }
    if (!context.mounted) return false;

    final details = StringBuffer();
    if (impact.isEmpty) {
      details.write('Связанных платежей и чеков нет.');
    } else {
      details.write('Будут безвозвратно удалены:');
      if (impact.payments > 0) {
        details.write('\n• платежей: ${impact.payments}');
      }
      if (impact.receipts > 0) {
        details.write('\n• чеков (файлов): ${impact.receipts}');
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить поставщика навсегда?'),
        content: Text(
          '«$name» и вся история по нему будут удалены. '
          'Это действие нельзя отменить.\n\n$details',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final supplierRepo = ref.watch(supplierRepositoryProvider);
    final paymentRepo = ref.watch(paymentRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поставщики'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Архив',
            onPressed: () => context.push('/suppliers/archive'),
          ),
        ],
      ),
      body: StreamBuilder<List<SupplierRow>>(
        stream: supplierRepo.watchActive(),
        builder: (context, snapshot) {
          final allSuppliers = snapshot.data ?? const [];
          if (allSuppliers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Поставщиков пока нет. Нажмите + чтобы добавить.'),
              ),
            );
          }

          // Список адресов собирается из данных (ТЗ §4.13): какие адреса
          // реально заполнены у поставщиков, в алфавитном порядке.
          final addresses = <String>{
            for (final s in allSuppliers)
              if (s.address != null && s.address!.trim().isNotEmpty)
                s.address!.trim(),
          }.toList()
            ..sort();

          // Фильтр: null («Все») — все; иначе — только поставщики этого адреса
          // (поставщики без адреса видны только в «Все»).
          final suppliers = _selectedAddress == null
              ? allSuppliers
              : allSuppliers
                  .where((s) => s.address?.trim() == _selectedAddress)
                  .toList();

          return Column(
            children: [
              if (addresses.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: const Text('Все'),
                          selected: _selectedAddress == null,
                          onSelected: (_) => _selectAddress(null),
                        ),
                      ),
                      for (final address in addresses)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(address),
                            selected: _selectedAddress == address,
                            onSelected: (_) => _selectAddress(address),
                          ),
                        ),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.swipe_left, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Свайп влево — убрать поставщика в архив',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: suppliers.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('По этому адресу поставщиков нет.'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = suppliers[index];
                          return Dismissible(
                            key: ValueKey(supplier.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context).colorScheme.errorContainer,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.archive_outlined),
                            ),
                            confirmDismiss: (_) => _showSwipeActions(
                              context,
                              supplier.id,
                              supplier.name,
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: Icon(
                                    iconForSupplierCategory(supplier.category)),
                                title: Text(supplier.name),
                                subtitle: supplier.category != null
                                    ? Text(supplier.category!)
                                    : null,
                                trailing: _CurrentPeriodBadge(
                                  supplierId: supplier.id,
                                  paymentRepo: paymentRepo,
                                ),
                                onTap: () =>
                                    context.push('/suppliers/${supplier.id}'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/suppliers/new'),
        tooltip: 'Добавить поставщика',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Бейдж статуса платежа поставщика за текущий календарный месяц —
/// «нет данных» (платёж ещё не создан), либо статус существующего
/// (ожидает / частично оплачено / оплачено, ТЗ §4.4, §4.6 — цветовой
/// маркер, чтобы не читать каждую строку).
///
/// Тап по бейджу (п. 5.5.1) ведёт сразу к следующему действию: если платёж
/// за текущий период есть — на экран оплаты, если нет — на ввод показаний.
class _CurrentPeriodBadge extends StatelessWidget {
  const _CurrentPeriodBadge({required this.supplierId, required this.paymentRepo});

  final String supplierId;
  final PaymentRepository paymentRepo;

  Future<void> _goToNextStep(
    BuildContext context,
    String? paymentId,
  ) async {
    if (paymentId != null) {
      context.push('/suppliers/$supplierId/payment/$paymentId');
    } else {
      context.push('/suppliers/$supplierId/reading');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<List<PaymentRow>>(
      stream: paymentRepo.watchForSupplier(supplierId),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? const [];
        PaymentRow? current;
        for (final p in payments) {
          if (p.period.year == now.year && p.period.month == now.month) {
            current = p;
            break;
          }
        }
        if (current == null) {
          return InkWell(
            onTap: () => _goToNextStep(context, null),
            borderRadius: BorderRadius.circular(16),
            child: Chip(
              label: const Text('нет данных'),
              visualDensity: VisualDensity.compact,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          );
        }
        final status = PaymentStatus.fromDb(current.status);
        final (label, color) = paymentStatusLabelAndColor(status);
        final paymentId = current.id;
        return InkWell(
          onTap: () => _goToNextStep(context, paymentId),
          borderRadius: BorderRadius.circular(16),
          child: Chip(
            label: Text(label),
            visualDensity: VisualDensity.compact,
            backgroundColor: color.withValues(alpha: 0.15),
            side: BorderSide(color: color),
          ),
        );
      },
    );
  }
}
