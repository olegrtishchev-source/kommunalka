import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/supplier_repository.dart';
import 'database_provider.dart';
import 'supabase_providers.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SupplierRepository(ref.watch(supabaseClientProvider), db.suppliersDao);
});
