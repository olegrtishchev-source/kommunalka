import 'package:flutter/material.dart';

/// Иконка поставщика в UI подбирается по категории на клиенте — отдельного
/// поля под иконку в модели нет (ТЗ §7, примечание к Supplier.category).
/// Простое сопоставление по ключевым словам, без претензии на полноту —
/// достаточно для личного использования, легко дополнить новым случаем.
IconData iconForSupplierCategory(String? category) {
  final normalized = category?.toLowerCase() ?? '';
  if (normalized.contains('вод')) return Icons.water_drop_outlined;
  if (normalized.contains('электр') || normalized.contains('свет')) {
    return Icons.bolt_outlined;
  }
  if (normalized.contains('газ')) return Icons.local_fire_department_outlined;
  if (normalized.contains('мусор')) return Icons.delete_outline;
  if (normalized.contains('интернет') || normalized.contains('связь')) {
    return Icons.wifi_outlined;
  }
  if (normalized.contains('канализ')) return Icons.plumbing_outlined;
  return Icons.receipt_long_outlined;
}
