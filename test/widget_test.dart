// Смоук-тест: экран входа рисует поля и кнопку без ошибок. Не тестируем
// KommunalkaApp целиком — ему для сборки провайдеров нужен реальный
// Supabase.initialize() (main.dart), что для обычного widget-теста
// избыточно; полноценные тесты сценариев — Этап 4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/screens/auth/login_screen.dart';

void main() {
  testWidgets('Экран входа рисует поля и кнопку без ошибок', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
