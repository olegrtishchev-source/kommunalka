import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../repositories/payment_repository.dart';
import '../../utils/supplier_category_icon.dart';

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
  @override
  void initState() {
    super.initState();
    // Разовая подтяжка кеша из Supabase при открытии экрана (ТЗ §4.7).
    // Pull-to-refresh — отдельный будущий пункт (сейчас в плане не заведён
    // явным номером; если понадобится — добавим при следующей правке).
    Future.microtask(() {
      ref.read(supplierRepositoryProvider).refresh();
      ref.read(paymentRepositoryProvider).refresh();
    });
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

  @override
  Widget build(BuildContext context) {
    final supplierRepo = ref.watch(supplierRepositoryProvider);
    final paymentRepo = ref.watch(paymentRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Поставщики')),
      body: StreamBuilder<List<SupplierRow>>(
        stream: supplierRepo.watchActive(),
        builder: (context, snapshot) {
          final suppliers = snapshot.data ?? const [];
          if (suppliers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Поставщиков пока нет. Нажмите + чтобы добавить.'),
              ),
            );
          }
          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return Dismissible(
                key: ValueKey(supplier.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.archive_outlined),
                ),
                confirmDismiss: (_) => _confirmArchive(context, supplier.name),
                onDismissed: (_) {
                  ref.read(supplierRepositoryProvider).archive(supplier.id);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(iconForSupplierCategory(supplier.category)),
                    title: Text(supplier.name),
                    subtitle: supplier.category != null ? Text(supplier.category!) : null,
                    trailing: _CurrentPeriodBadge(
                      supplierId: supplier.id,
                      paymentRepo: paymentRepo,
                    ),
                    onTap: () => context.push('/suppliers/${supplier.id}'),
                  ),
                ),
              );
            },
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
class _CurrentPeriodBadge extends StatelessWidget {
  const _CurrentPeriodBadge({required this.supplierId, required this.paymentRepo});

  final String supplierId;
  final PaymentRepository paymentRepo;

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
          return Chip(
            label: const Text('нет данных'),
            visualDensity: VisualDensity.compact,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }
        final status = PaymentStatus.fromDb(current.status);
        final (label, color) = switch (status) {
          PaymentStatus.pending => ('ожидает', Colors.orange),
          PaymentStatus.partiallyPaid => ('частично', Colors.amber),
          PaymentStatus.paid => ('оплачено', Colors.green),
        };
        return Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          backgroundColor: color.withValues(alpha: 0.15),
          side: BorderSide(color: color),
        );
      },
    );
  }
}
