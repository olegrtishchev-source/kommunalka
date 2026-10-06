/// Форматирование денежных сумм под привычный вид (Этап 5, п. 5.5): два
/// знака после запятой, разделитель тысяч — пробел, знак «₽». Одна точка
/// правды для всех экранов — по аналогии с lib/utils/date_format.dart для
/// дат: если формат сумм понадобится поменять, это делается здесь, а не в
/// каждом виджете. Без пакета intl: для одного простого формата он не нужен.
library;

/// Группирует целую часть пробелами по три разряда: 1234 → «1 234».
String _groupThousands(String intPart) => intPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );

/// Число без знака валюты и без разделителя тысяч — для полей ввода
/// (значение должно парситься через double.tryParse) и поиска по сумме:
/// 1234.50.
String formatNumber(double value) => value.toStringAsFixed(2);

/// Показание счётчика без лишнего «.0»: целые — как есть (42845), дробные —
/// с нужным числом знаков без хвостовых нулей (42845.5). Счётчики обычно
/// целочисленные, поэтому «42845.0» в интерфейсе выглядит лишним.
String formatReading(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  // Убираем хвостовые нули у дробной части: 3.500 → 3.5, 3.140 → 3.14.
  var s = value.toString();
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Сумма с разделителем тысяч: 1 234.50 ₽.
String formatAmount(double value) {
  final fixed = value.toStringAsFixed(2);
  final negative = fixed.startsWith('-');
  final unsigned = negative ? fixed.substring(1) : fixed;
  final parts = unsigned.split('.');
  return '${negative ? '-' : ''}${_groupThousands(parts[0])}.${parts[1]} ₽';
}
