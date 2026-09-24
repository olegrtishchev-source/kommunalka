import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/app_database.dart';
import '../../providers/supplier_provider.dart';

/// Список поставщиков — домашний экран после входа (ТЗ §4.1, схема 2.5).
/// Минимальная версия для Этапа 3.5: список + переход к вводу показаний
/// по нажатию на карточку. Карточка поставщика (/suppliers/:id),
/// редактирование, архив — Этап 4 (полная версия экрана — 4.1).
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
    // Pull-to-refresh — на Этапе 4 вместе с полноценным экраном.
    Future.microtask(() => ref.read(supplierRepositoryProvider).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(supplierRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Поставщики')),
      body: StreamBuilder<List<SupplierRow>>(
        stream: repo.watchActive(),
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
              return ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(supplier.name),
                onTap: () => context.push('/suppliers/${supplier.id}/reading'),
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
