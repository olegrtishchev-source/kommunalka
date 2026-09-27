import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/settings_service.dart';

/// SettingsService асинхронный, так как SharedPreferences.getInstance()
/// сам асинхронный — по аналогии с остальными провайдерами-обёртками
/// (см. journal 3.2), но с FutureProvider, а не Provider.
final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsService(prefs);
});
