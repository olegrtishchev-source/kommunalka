import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

/// MaterialApp.router + go_router (ТЗ, Этап 2.4 плана — структура папок).
class KommunalkaApp extends ConsumerWidget {
  const KommunalkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Коммуналка',
      routerConfig: router,
    );
  }
}
