import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

/// Publishable key безопасен для клиентского кода (не секрет).
const supabaseUrl = 'https://jvroshiynvwrjzzztfsx.supabase.co';
const supabasePublishableKey = 'sb_publishable_IpDeMNLn5LQjl8DqBUw5Dw_yHPeTWzx';

/// Яндекс.Диск (Этап 3.11) — Client ID OAuth-приложения, зарегистрированного
/// на oauth.yandex.ru (платформа «Веб-сервисы», scope cloud_api:disk.write).
/// Как и publishable key выше, не секрет: используется implicit-flow
/// (response_type=token), client_secret приложению вообще не нужен.
const yandexClientId = 'ddb0778b6094490eb84e670ee991d6e8';
/// Совпадает со схемой в android/app/src/main/AndroidManifest.xml
/// (CallbackActivity) — туда возвращается системный браузер после входа.
const yandexRedirectUri = 'kommunalka://oauth2redirect';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const ProviderScope(child: KommunalkaApp()));
}
