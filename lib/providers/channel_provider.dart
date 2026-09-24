import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/channel_repository.dart';
import 'database_provider.dart';
import 'supabase_providers.dart';

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChannelRepository(
    ref.watch(supabaseClientProvider),
    db.channelsDao,
    db.readingsDao,
  );
});
