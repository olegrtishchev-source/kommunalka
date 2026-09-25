import 'package:flutter/material.dart';

/// Настройки приложения (ТЗ §4.8) — заглушка для каркаса навигации (Этап 4,
/// п. 4.9). Валюта, формат даты, переключатель напоминаний, выход из
/// аккаунта, очистка локального кеша drift — отдельный пункт плана (4.8).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: const Center(child: Text('Раздел «Настройки» в разработке')),
    );
  }
}
