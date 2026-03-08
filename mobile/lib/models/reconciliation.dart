class Reconciliation {
  final double totalOpeningBalance;
  final double totalClosingBalance;
  final double totalMovements;
  final double totalCommissions;
  final double startingCash;
  final double endingCash;
  final double discrepancy;
  final String status;
  final String? discrepancyNote;
  final String? discrepancyPhotoUrl;
  final ReconciliationDetails details;

  Reconciliation({
    required this.totalOpeningBalance,
    required this.totalClosingBalance,
    required this.totalMovements,
    required this.totalCommissions,
    required this.startingCash,
    required this.endingCash,
    required this.discrepancy,
    required this.status,
    this.discrepancyNote,
    this.discrepancyPhotoUrl,
    required this.details,
  });

  factory Reconciliation.fromJson(Map<String, dynamic> json) {
    return Reconciliation(
      totalOpeningBalance: _d(json['totalOpeningBalance']),
      totalClosingBalance: _d(json['totalClosingBalance']),
      totalMovements: _d(json['totalMovements']),
      totalCommissions: _d(json['totalCommissions']),
      startingCash: _d(json['startingCash']),
      endingCash: _d(json['endingCash']),
      discrepancy: _d(json['discrepancy']),
      status: json['status'],
      discrepancyNote: json['discrepancyNote'],
      discrepancyPhotoUrl: json['discrepancyPhotoUrl'],
      details: ReconciliationDetails.fromJson(json['details']),
    );
  }

  bool get isBalanced => status == 'BALANCED';
  bool get isSurplus => status == 'SURPLUS';
  bool get isDeficit => status == 'DEFICIT';

  String get statusLabel {
    switch (status) {
      case 'BALANCED': return 'CUADRADO';
      case 'SURPLUS': return 'SOBRANTE';
      case 'DEFICIT': return 'FALTANTE';
      default: return status;
    }
  }

  /// Total apertura (efectivo + saldos)
  double get totalOpening => startingCash + totalOpeningBalance;

  /// Total cierre (efectivo + saldos)
  double get totalClosing => endingCash + totalClosingBalance;

  /// Total esperado = apertura + movimientos netos (comisiones son solo informativas)
  double get totalExpected => totalOpening + totalMovements;

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

class ReconciliationDetails {
  final List<BalanceSummary> openingBalances;
  final List<BalanceSummary> closingBalances;
  final List<MovementSummary> movements;
  final List<CommissionSummary> commissions;

  ReconciliationDetails({
    required this.openingBalances,
    required this.closingBalances,
    required this.movements,
    required this.commissions,
  });

  factory ReconciliationDetails.fromJson(Map<String, dynamic> json) {
    return ReconciliationDetails(
      openingBalances: (json['openingBalances'] as List)
          .map((e) => BalanceSummary.fromJson(e))
          .toList(),
      closingBalances: (json['closingBalances'] as List)
          .map((e) => BalanceSummary.fromJson(e))
          .toList(),
      movements: (json['movements'] as List)
          .map((e) => MovementSummary.fromJson(e))
          .toList(),
      commissions: (json['commissions'] as List?)
              ?.map((e) => CommissionSummary.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CommissionSummary {
  final String name;
  final double amount;

  CommissionSummary({required this.name, required this.amount});

  factory CommissionSummary.fromJson(Map<String, dynamic> json) {
    return CommissionSummary(
      name: json['name'] ?? '',
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class BalanceSummary {
  final String entityName;
  final double amount;

  BalanceSummary({required this.entityName, required this.amount});

  factory BalanceSummary.fromJson(Map<String, dynamic> json) {
    return BalanceSummary(
      entityName: json['entityName'],
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class MovementSummary {
  final String type;
  final String direction;
  final double amount;
  final String? description;

  MovementSummary({
    required this.type,
    required this.direction,
    required this.amount,
    this.description,
  });

  factory MovementSummary.fromJson(Map<String, dynamic> json) {
    return MovementSummary(
      type: json['type'],
      direction: json['direction'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
    );
  }
}
