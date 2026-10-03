import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/supplier_provider.dart';
import '../../utils/supplier_category_icon.dart';

/// Экран «Архив» (п. 5.5.2) — список архивированных поставщиков (мягкое
/// удаление, ТЗ §4.1) с возможностью восстановления. Архив не удаляет данные:
/// показания и платежи архивного поставщика остаются в истории, поэтому
/// возврат из архива полностью восстанавливает поставщика в активный список.
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(supplierRepositoryProvider).refresh();
    });
  }

  Future<void> _restore(SupplierRow supplier) async {
    await ref.read(supplierRepositoryProvider).unarchive(supplier.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${supplier.name}» восстановлен.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplierRepo = ref.watch(supplierRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Архив')),
      body: StreamBuilder<List<SupplierRow>>(
        stream: supplierRepo.watchArchived(),
        builder: (context, snapshot) {
          final suppliers = snapshot.data ?? const [];
          if (suppliers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Архив пуст.'),
              ),
            );
          }
          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(iconForSupplierCategory(supplier.category)),
                  title: Text(supplier.name),
                  subtitle: supplier.category != null
                      ? Text(supplier.category!)
                      : null,
                  trailing: TextButton(
                    onPressed: () => _restore(supplier),
                    child: const Text('Восстановить'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
