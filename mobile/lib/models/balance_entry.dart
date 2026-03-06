import 'banking_entity.dart';

class BalanceEntry {
  final String id;
  final String shiftId;
  final String entityId;
  final String type; // OPENING or CLOSING
  final double amount;
  final String? receiptPhotoUrl;
  final BankingEntity? entity;

  BalanceEntry({
    required this.id,
    required this.shiftId,
    required this.entityId,
    required this.type,
    required this.amount,
    this.receiptPhotoUrl,
    this.entity,
  });

  factory BalanceEntry.fromJson(Map<String, dynamic> json) {
    return BalanceEntry(
      id: json['id'],
      shiftId: json['shiftId'] ?? json['shift_id'] ?? '',
      entityId: json['entityId'] ?? json['entity_id'] ?? '',
      type: json['type'],
      amount: _toDouble(json['amount']),
      receiptPhotoUrl: json['receiptPhotoUrl'] ?? json['receipt_photo_url'],
      entity: json['entity'] != null
          ? BankingEntity.fromJson(json['entity'])
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
