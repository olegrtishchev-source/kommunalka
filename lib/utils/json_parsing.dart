// Небольшие защитные хелперы для разбора JSON от Supabase (PostgREST).
// Числовые поля numeric() иногда приходят как num, иногда как String —
// в зависимости от точности значения. Даты (date/timestamptz) — всегда
// строки в ISO 8601.

double? parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

double parseDouble(dynamic value) {
  final result = parseDoubleOrNull(value);
  if (result == null) {
    throw FormatException('Ожидалось числовое значение, получено null');
  }
  return result;
}

DateTime? parseDateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value.toString());
}

DateTime parseDate(dynamic value) {
  final result = parseDateOrNull(value);
  if (result == null) {
    throw FormatException('Ожидалась дата, получено null');
  }
  return result;
}

/// Дата в формате YYYY-MM-DD — для колонок типа `date` (period, reading_date).
String formatDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
