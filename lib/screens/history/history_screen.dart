import 'package:flutter/material.dart';

/// Общая история платежей (ТЗ §4.6–4.7) — заглушка для каркаса навигации
/// (Этап 4, п. 4.9). Список платежей по всем поставщикам, фильтры по
/// поставщику/периоду и поиск по сумме/дате — отдельный пункт плана (4.7).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: const Center(child: Text('Раздел «История» в разработке')),
    );
  }
}
