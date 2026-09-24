import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Единственная точка создания AppDatabase через Riverpod — задел под
/// подключение к ProviderScope на Этапе 4 (по аналогии с supabaseClientProvider
/// и authServiceProvider, см. журнал 3.2). До этого момента спайк-экран
/// в main.dart по-прежнему работает со своим собственным
/// `final database = AppDatabase();` — замена на этот провайдер и удаление
/// спайка произойдут вместе, в начале Этапа 3.5 (MVP), когда появятся
/// настоящие экраны.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
