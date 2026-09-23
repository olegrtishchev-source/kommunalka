import '../utils/json_parsing.dart';

/// Тип поставщика — определяет, ведутся ли по нему показания счётчиков
/// (см. ТЗ §4.1, §7).
enum SupplierType {
  withReadings('with_readings'),
  withoutReadings('without_readings');

  const SupplierType(this.dbValue);

  final String dbValue;

  static SupplierType fromDb(String value) {
    return SupplierType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => throw FormatException('Неизвестный тип поставщика: $value'),
    );
  }
}

/// Банковские реквизиты для оплаты (jsonb-поле Supplier.bank_details, ТЗ §4.1).
class BankDetails {
  const BankDetails({
    this.recipient,
    this.inn,
    this.kpp,
    this.bik,
    this.accountNumber,
  });

  final String? recipient;
  final String? inn;
  final String? kpp;
  final String? bik;
  final String? accountNumber;

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      recipient: json['recipient'] as String?,
      inn: json['inn'] as String?,
      kpp: json['kpp'] as String?,
      bik: json['bik'] as String?,
      accountNumber: json['account_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipient': recipient,
      'inn': inn,
      'kpp': kpp,
      'bik': bik,
      'account_number': accountNumber,
    };
  }
}

/// Поставщик коммунальной услуги (ТЗ §7).
class Supplier {
  const Supplier({
    required this.id,
    required this.userId,
    required this.name,
    this.category,
    required this.type,
    this.bankDetails,
    this.paymentPurposeTemplate,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? category;
  final SupplierType type;
  final BankDetails? bankDetails;
  final String? paymentPurposeTemplate;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    final bankDetailsJson = json['bank_details'] as Map<String, dynamic>?;
    return Supplier(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      type: SupplierType.fromDb(json['type'] as String),
      bankDetails:
          bankDetailsJson != null ? BankDetails.fromJson(bankDetailsJson) : null,
      paymentPurposeTemplate: json['payment_purpose_template'] as String?,
      archivedAt: parseDateOrNull(json['archived_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category': category,
      'type': type.dbValue,
      'bank_details': bankDetails?.toJson(),
      'payment_purpose_template': paymentPurposeTemplate,
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
