import '../utils/json_parsing.dart';

/// Статус платежа — вычисляется по соотношению факт-суммы и расчётной
/// (ТЗ §4.4, §7), но хранится как поле, чтобы не пересчитывать при
/// каждой выборке списка.
enum PaymentStatus {
  pending('pending'),
  partiallyPaid('partially_paid'),
  paid('paid');

  const PaymentStatus(this.dbValue);

  final String dbValue;

  static PaymentStatus fromDb(String value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => throw FormatException('Неизвестный статус платежа: $value'),
    );
  }

  /// Вычислить статус по соотношению факт-суммы и расчётной (ТЗ §4.4):
  /// ожидает (факт не введён) / частично оплачено (0 < факт < расчёт) /
  /// оплачено (факт ≥ расчёт).
  static PaymentStatus calculate({
    required double calculatedAmount,
    required double? actualAmount,
  }) {
    if (actualAmount == null) return PaymentStatus.pending;
    if (actualAmount >= calculatedAmount) return PaymentStatus.paid;
    if (actualAmount > 0) return PaymentStatus.partiallyPaid;
    return PaymentStatus.pending;
  }
}

/// Один элемент снимка показаний в Payment.reading_snapshot (ТЗ §4.3, §7) —
/// по одному на канал поставщика. Для производного канала previousValue/
/// currentValue скопированы из снимка канала-источника за тот же период.
class ReadingSnapshotEntry {
  const ReadingSnapshotEntry({
    required this.channelId,
    required this.channelName,
    required this.unit,
    required this.previousValue,
    required this.currentValue,
    required this.tariff,
    required this.readingDate,
  });

  final String channelId;
  final String channelName;
  final String unit;
  final double previousValue;
  final double currentValue;
  final double tariff;
  final DateTime readingDate;

  double get consumption => currentValue - previousValue;
  double get amount => consumption * tariff;

  factory ReadingSnapshotEntry.fromJson(Map<String, dynamic> json) {
    return ReadingSnapshotEntry(
      channelId: json['channel_id'] as String,
      channelName: json['channel_name'] as String,
      unit: json['unit'] as String,
      previousValue: parseDouble(json['previous_value']),
      currentValue: parseDouble(json['current_value']),
      tariff: parseDouble(json['tariff']),
      readingDate: parseDate(json['reading_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'channel_name': channelName,
      'unit': unit,
      'previous_value': previousValue,
      'current_value': currentValue,
      'tariff': tariff,
      'reading_date': formatDateOnly(readingDate),
    };
  }
}

/// Платёж за услугу поставщика за период (ТЗ §4.3–4.4, §7).
class Payment {
  const Payment({
    required this.id,
    required this.userId,
    required this.supplierId,
    required this.period,
    this.readingSnapshot,
    this.consumption,
    required this.calculatedAmount,
    this.actualAmount,
    required this.status,
    this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String supplierId;
  /// Первое число месяца периода (напр. 2026-09-01) — см. ТЗ §7.
  final DateTime period;
  /// null для поставщиков типа `without_readings`.
  final List<ReadingSnapshotEntry>? readingSnapshot;
  final double? consumption;
  final double calculatedAmount;
  final double? actualAmount;
  final PaymentStatus status;
  final DateTime? paymentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final snapshotJson = json['reading_snapshot'] as List<dynamic>?;
    return Payment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      supplierId: json['supplier_id'] as String,
      period: parseDate(json['period']),
      readingSnapshot: snapshotJson
          ?.map((e) => ReadingSnapshotEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      consumption: parseDoubleOrNull(json['consumption']),
      calculatedAmount: parseDouble(json['calculated_amount']),
      actualAmount: parseDoubleOrNull(json['actual_amount']),
      status: PaymentStatus.fromDb(json['status'] as String),
      paymentDate: parseDateOrNull(json['payment_date']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'supplier_id': supplierId,
      'period': formatDateOnly(period),
      'reading_snapshot': readingSnapshot?.map((e) => e.toJson()).toList(),
      'consumption': consumption,
      'calculated_amount': calculatedAmount,
      'actual_amount': actualAmount,
      'status': status.dbValue,
      'payment_date': paymentDate != null ? formatDateOnly(paymentDate!) : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
