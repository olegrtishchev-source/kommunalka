import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

/// Глобальный ключ мессенджера — SnackBar показывается поверх всего, включая
/// открытые диалоги (например, подтверждение сохранения QR в галерею, когда
/// диалог с QR ещё открыт). Обычный `ScaffoldMessenger.of(context)` рисует
/// SnackBar на своём Scaffold — под диалогом, и его не видно.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: router,
    );
  }
}
