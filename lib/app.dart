import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

/// MaterialApp.router + go_router (ТЗ, Этап 2.4 плана — структура папок).
/// Базовая тема (ТЗ §4.9, §5 — минималистичный интерфейс): Material 3,
/// цветовая схема из одного seed-цвета — при желании поменять фирменный
/// цвет достаточно поменять один параметр ниже, тема пересчитается сама.
class KommunalkaApp extends ConsumerWidget {
  const KommunalkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Коммуналка',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: router,
    );
  }
}
