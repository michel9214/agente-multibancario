import 'balance_entry.dart';
import 'movement.dart';

class CommissionEntry {
  final String id;
  final String shiftId;
  final String? entityId;
  final String? concept;
  final double amount;
  final CommissionEntity? entity;

  CommissionEntry({
    required this.id,
    required this.shiftId,
    this.entityId,
    this.concept,
    required this.amount,
    this.entity,
  });

  factory CommissionEntry.fromJson(Map<String, dynamic> json) {
    return CommissionEntry(
      id: json['id'],
      shiftId: json['shiftId'] ?? json['shift_id'] ?? '',
      entityId: json['entityId'] ?? json['entity_id'],
      concept: json['concept'],
      amount: _toDouble(json['amount']),
      entity: json['entity'] != null
          ? CommissionEntity.fromJson(json['entity'])
          : null,
    );
  }

  String get name => entity?.name ?? concept ?? '';

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class CommissionEntity {
  final String id;
  final String name;

  CommissionEntity({required this.id, required this.name});

  factory CommissionEntity.fromJson(Map<String, dynamic> json) {
    return CommissionEntity(id: json['id'], name: json['name']);
  }
}

class Shift {
  final String id;
  final String operatorId;
  final String status;
  final DateTime startedAt;
  final DateTime? closedAt;
  final double startingCash;
  final double sencillo;
  final double? endingCash;
  final double? totalOpeningBalance;
  final double? totalClosingBalance;
  final double? totalMovements;
  final double? totalCommissions;
  final double? discrepancy;
  final String? discrepancyNote;
  final String? discrepancyPhotoUrl;
  final List<BalanceEntry> balanceEntries;
  final List<Movement> movements;
  final List<CommissionEntry> commissionEntries;
  final ShiftOperator? operator;

  Shift({
    required this.id,
    required this.operatorId,
    required this.status,
    required this.startedAt,
    this.closedAt,
    required this.startingCash,
    this.sencillo = 0,
    this.endingCash,
    this.totalOpeningBalance,
    this.totalClosingBalance,
    this.totalMovements,
    this.totalCommissions,
    this.discrepancy,
    this.discrepancyNote,
    this.discrepancyPhotoUrl,
    this.balanceEntries = const [],
    this.movements = const [],
    this.commissionEntries = const [],
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
      sencillo: _toDouble(json['sencillo'] ?? 0),
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
      totalCommissions: json['totalCommissions'] != null
          ? _toDouble(json['totalCommissions'])
          : null,
      discrepancy: json['discrepancy'] != null
          ? _toDouble(json['discrepancy'])
          : null,
      discrepancyNote: json['discrepancyNote'] ?? json['discrepancy_note'],
      discrepancyPhotoUrl: json['discrepancyPhotoUrl'] ?? json['discrepancy_photo_url'],
      balanceEntries: (json['balanceEntries'] as List<dynamic>?)
              ?.map((e) => BalanceEntry.fromJson(e))
              .toList() ??
          [],
      movements: (json['movements'] as List<dynamic>?)
              ?.map((e) => Movement.fromJson(e))
              .toList() ??
          [],
      commissionEntries: (json['commissionEntries'] as List<dynamic>?)
              ?.map((e) => CommissionEntry.fromJson(e))
              .toList() ??
          [],
      operator: json['operator'] != null
          ? ShiftOperator.fromJson(json['operator'])
          : null,
    );
  }

  bool get isOpen => status == 'OPEN';
  bool get isPreclosed => status == 'PRECLOSED';
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
