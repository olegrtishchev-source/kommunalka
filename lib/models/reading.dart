import '../utils/json_parsing.dart';

/// Показание счётчика по каналу (ТЗ §4.2, §7). Не существует для
/// производных каналов и для поставщиков типа `without_readings`.
class Reading {
  const Reading({
    required this.id,
    required this.userId,
    required this.channelId,
    required this.value,
    required this.readingDate,
    required this.meterReplaced,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String channelId;
  final double value;
  final DateTime readingDate;
  /// Показание после замены счётчика — снимает ограничение
  /// «не меньше предыдущего» (ТЗ §4.2).
  final bool meterReplaced;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      channelId: json['channel_id'] as String,
      value: parseDouble(json['value']),
      readingDate: parseDate(json['reading_date']),
      meterReplaced: json['meter_replaced'] as bool? ?? false,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'channel_id': channelId,
      'value': value,
      'reading_date': formatDateOnly(readingDate),
      'meter_replaced': meterReplaced,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
