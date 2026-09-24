import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show yandexClientId, yandexRedirectUri;
import '../services/yandex_disk_service.dart';

final yandexDiskServiceProvider = Provider<YandexDiskService>((ref) {
  return YandexDiskService(
    clientId: yandexClientId,
    redirectUri: yandexRedirectUri,
  );
});
