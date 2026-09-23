import '../utils/json_parsing.dart';

/// Канал показаний поставщика (ТЗ §4.1, §7). Существует только для
/// поставщиков типа `with_readings`. Если [sourceChannelId] заполнено —
/// канал производный: у него нет собственных показаний, расход берётся
/// из указанного канала (в т.ч. другого поставщика) за тот же период.
class Channel {
  const Channel({
    required this.id,
    required this.userId,
    required this.supplierId,
    required this.name,
    required this.unit,
    required this.tariff,
    this.sourceChannelId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String supplierId;
  final String name;
  final String unit;
  final double tariff;
  final String? sourceChannelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDerived => sourceChannelId != null;

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      supplierId: json['supplier_id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      tariff: parseDouble(json['tariff']),
      sourceChannelId: json['source_channel_id'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'supplier_id': supplierId,
      'name': name,
      'unit': unit,
      'tariff': tariff,
      'source_channel_id': sourceChannelId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
