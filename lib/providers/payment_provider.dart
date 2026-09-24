import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/payment_repository.dart';
import 'database_provider.dart';
import 'supabase_providers.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PaymentRepository(ref.watch(supabaseClientProvider), db.paymentsDao);
});
