import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reading_repository.dart';
import 'database_provider.dart';
import 'supabase_providers.dart';

final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReadingRepository(ref.watch(supabaseClientProvider), db.readingsDao);
});
