// Базовый smoke-test: приложение запускается и рисует первый кадр без ошибок.
// Content-специфичные тесты появятся вместе с реальными экранами (Этап 4).

import 'package:flutter_test/flutter_test.dart';

import 'package:kommunalka/main.dart';

void main() {
  testWidgets('Приложение запускается без ошибок', (WidgetTester tester) async {
    await tester.pumpWidget(const SpikeApp());
    await tester.pump();
  });
}
