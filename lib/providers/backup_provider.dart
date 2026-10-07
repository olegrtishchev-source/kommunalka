import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/backup_repository.dart';
import 'supabase_providers.dart';

/// Резервное копирование (ТЗ §4.9) — экспорт/импорт JSON поверх Supabase.
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(supabaseClientProvider));
});
