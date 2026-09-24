import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import 'supabase_providers.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseClientProvider));
});
