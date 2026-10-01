/// Форматирование дат под привычный вид (Этап 5, п. 5.5): дд.мм.гггг с
/// ведущими нулями. Одна точка правды для всех экранов — если формат
/// понадобится поменять, это делается здесь, а не в каждом виджете.
/// Без пакета intl: для двух простых форматов он не нужен.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// Дата: 30.09.2026.
String formatDate(DateTime date) => '${_two(date.day)}.${_two(date.month)}.${date.year}';

/// Период (месяц платежа): 09.2026.
String formatPeriod(DateTime period) => '${_two(period.month)}.${period.year}';
