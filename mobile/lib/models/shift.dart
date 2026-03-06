import 'balance_entry.dart';
import 'movement.dart';

class Shift {
  final String id;
  final String operatorId;
  final String status;
  final DateTime startedAt;
  final DateTime? closedAt;
  final double startingCash;
  final double? endingCash;
  final double? totalOpeningBalance;
  final double? totalClosingBalance;
  final double? totalMovements;
  final double? discrepancy;
  final List<BalanceEntry> balanceEntries;
  final List<Movement> movements;
  final ShiftOperator? operator;

  Shift({
    required this.id,
    required this.operatorId,
    required this.status,
    required this.startedAt,
    this.closedAt,
    required this.startingCash,
    this.endingCash,
    this.totalOpeningBalance,
    this.totalClosingBalance,
    this.totalMovements,
    this.discrepancy,
    this.balanceEntries = const [],
    this.movements = const [],
    this.operator,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      operatorId: json['operatorId'] ?? json['operator_id'] ?? '',
      status: json['status'],
      startedAt: DateTime.parse(json['startedAt'] ?? json['started_at']),
      closedAt: json['closedAt'] != null || json['closed_at'] != null
          ? DateTime.parse(json['closedAt'] ?? json['closed_at'])
          : null,
      startingCash: _toDouble(json['startingCash'] ?? json['starting_cash']),
      endingCash: json['endingCash'] != null || json['ending_cash'] != null
          ? _toDouble(json['endingCash'] ?? json['ending_cash'])
          : null,
      totalOpeningBalance: json['totalOpeningBalance'] != null
          ? _toDouble(json['totalOpeningBalance'])
          : null,
      totalClosingBalance: json['totalClosingBalance'] != null
          ? _toDouble(json['totalClosingBalance'])
          : null,
      totalMovements: json['totalMovements'] != null
          ? _toDouble(json['totalMovements'])
          : null,
      discrepancy: json['discrepancy'] != null
          ? _toDouble(json['discrepancy'])
          : null,
      balanceEntries: (json['balanceEntries'] as List<dynamic>?)
              ?.map((e) => BalanceEntry.fromJson(e))
              .toList() ??
          [],
      movements: (json['movements'] as List<dynamic>?)
              ?.map((e) => Movement.fromJson(e))
              .toList() ??
          [],
      operator: json['operator'] != null
          ? ShiftOperator.fromJson(json['operator'])
          : null,
    );
  }

  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';
  bool get isBalanced => discrepancy != null && discrepancy == 0;

  String get statusLabel {
    if (isOpen) return 'Abierto';
    if (isBalanced) return 'Cuadrado';
    if (discrepancy != null && discrepancy! > 0) return 'Sobrante';
    return 'Faltante';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class ShiftOperator {
  final String id;
  final String fullName;
  final String? email;

  ShiftOperator({required this.id, required this.fullName, this.email});

  factory ShiftOperator.fromJson(Map<String, dynamic> json) {
    return ShiftOperator(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
    );
  }
}
