import 'movement_reason.dart';

class Movement {
  final String id;
  final String shiftId;
  final String type;
  final String? reasonId;
  final MovementReason? reason;
  final String direction;
  final double amount;
  final String? description;
  final String? receiptPhotoUrl;
  final DateTime createdAt;

  Movement({
    required this.id,
    required this.shiftId,
    required this.type,
    this.reasonId,
    this.reason,
    required this.direction,
    required this.amount,
    this.description,
    this.receiptPhotoUrl,
    required this.createdAt,
  });

  factory Movement.fromJson(Map<String, dynamic> json) {
    return Movement(
      id: json['id'],
      shiftId: json['shiftId'] ?? json['shift_id'] ?? '',
      type: json['type'],
      reasonId: json['reasonId'] ?? json['reason_id'],
      reason: json['reason'] != null
          ? MovementReason.fromJson(json['reason'])
          : null,
      direction: json['direction'],
      amount: _toDouble(json['amount']),
      description: json['description'],
      receiptPhotoUrl: json['receiptPhotoUrl'] ?? json['receipt_photo_url'],
      createdAt: DateTime.parse(json['createdAt'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String()),
    );
  }

  bool get isIncoming => direction == 'IN';

  String get typeLabel {
    if (reason != null) return reason!.name;
    switch (type) {
      case 'CASH_INJECTION':
        return 'Inyección de efectivo';
      case 'BALANCE_INJECTION':
        return 'Inyección de saldo';
      case 'ATM_WITHDRAWAL':
        return 'Retiro ATM';
      case 'PERSONAL_PAYMENT':
        return 'Pago personal';
      case 'BUSINESS_PAYMENT':
        return 'Pago de negocio';
      case 'OTHER':
        return 'Otro';
      default:
        return type;
    }
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
