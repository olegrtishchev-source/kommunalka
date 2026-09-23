import '../utils/json_parsing.dart';

/// Чек об оплате (ТЗ §4.5, §7) — файл лежит в Supabase Storage,
/// [filePath] хранит путь к нему.
class Receipt {
  const Receipt({
    required this.id,
    required this.paymentId,
    required this.filePath,
    required this.createdAt,
  });

  final String id;
  final String paymentId;
  final String filePath;
  final DateTime createdAt;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      paymentId: json['payment_id'] as String,
      filePath: json['file_path'] as String,
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_id': paymentId,
      'file_path': filePath,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
