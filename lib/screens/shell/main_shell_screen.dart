import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Общий каркас нижней навигации (ТЗ, схема §2.5) — 4 раздела: Поставщики /
/// История / Отчёты / Настройки (ТЗ §4.9). Обёртка вокруг
/// StatefulShellRoute.indexedStack из router.dart — у каждой вкладки свой
/// собственный стек экранов и состояние, которое сохраняется при
/// переключении между вкладками, а не пересоздаётся заново.
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Повторное нажатие на уже открытую вкладку возвращает её к
          // корневому экрану — стандартное поведение bottom navigation.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Поставщики'),
          NavigationDestination(icon: Icon(Icons.history), label: 'История'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Отчёты'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
