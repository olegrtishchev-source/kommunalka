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

/// Сумма с разделителем тысяч: 1 234.50 ₽.
String formatAmount(double value) {
  final fixed = value.toStringAsFixed(2);
  final negative = fixed.startsWith('-');
  final unsigned = negative ? fixed.substring(1) : fixed;
  final parts = unsigned.split('.');
  return '${negative ? '-' : ''}${_groupThousands(parts[0])}.${parts[1]} ₽';
}
