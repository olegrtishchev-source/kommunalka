import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Общий доступ к клиенту Supabase через Riverpod — инициализируется один раз
/// в main.dart (Supabase.initialize), здесь только читаем готовый экземпляр
/// (задел под Этап 3.3 — базовые CRUD-методы репозитории строят поверх него).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
