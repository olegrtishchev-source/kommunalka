import 'package:flutter/material.dart';

/// Формирование и выгрузка Excel-отчёта на Яндекс.Диск (ТЗ §4.10) —
/// заглушка для каркаса навигации (Этап 4, п. 4.9). Выбор периода, кнопка
/// «Сформировать и выгрузить» и статус авторизации Яндекс.Диска — п. 4.10.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты')),
      body: const Center(child: Text('Раздел «Отчёты» в разработке')),
    );
  }
}
