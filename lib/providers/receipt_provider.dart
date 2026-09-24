import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/receipt_repository.dart';
import 'database_provider.dart';
import 'storage_provider.dart';
import 'supabase_providers.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReceiptRepository(
    ref.watch(supabaseClientProvider),
    db.receiptsDao,
    ref.watch(storageServiceProvider),
  );
});
