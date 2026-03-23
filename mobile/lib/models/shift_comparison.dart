class ComparisonShiftSummary {
  final String id;
  final DateTime startedAt;
  final DateTime? closedAt;
  final String operatorName;
  final double cash; // endingCash for closing, startingCash for opening

  ComparisonShiftSummary({
    required this.id,
    required this.startedAt,
    this.closedAt,
    required this.operatorName,
    required this.cash,
  });

  factory ComparisonShiftSummary.fromClosingJson(Map<String, dynamic> json) {
    return ComparisonShiftSummary(
      id: json['id'],
      startedAt: DateTime.parse(json['startedAt']),
      closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
      operatorName: json['operatorName'] ?? '-',
      cash: _toDouble(json['endingCash']),
    );
  }

  factory ComparisonShiftSummary.fromOpeningJson(Map<String, dynamic> json) {
    return ComparisonShiftSummary(
      id: json['id'],
      startedAt: DateTime.parse(json['startedAt']),
      operatorName: json['operatorName'] ?? '-',
      cash: _toDouble(json['startingCash']),
    );
  }
}

class EntityComparison {
  final String entityId;
  final String entityName;
  final double closingAmount;
  final double openingAmount;
  final double diff;

  EntityComparison({
    required this.entityId,
    required this.entityName,
    required this.closingAmount,
    required this.openingAmount,
    required this.diff,
  });

  factory EntityComparison.fromJson(Map<String, dynamic> json) {
    return EntityComparison(
      entityId: json['entityId'],
      entityName: json['entityName'] ?? 'Entidad',
      closingAmount: _toDouble(json['closingAmount']),
      openingAmount: _toDouble(json['openingAmount']),
      diff: _toDouble(json['diff']),
    );
  }
}

class ShiftComparison {
  final ComparisonShiftSummary closingShift;
  final ComparisonShiftSummary openingShift;
  final double cashDiff;
  final double totalDiff;
  final List<EntityComparison> entityComparisons;

  ShiftComparison({
    required this.closingShift,
    required this.openingShift,
    required this.cashDiff,
    required this.totalDiff,
    required this.entityComparisons,
  });

  factory ShiftComparison.fromJson(Map<String, dynamic> json) {
    return ShiftComparison(
      closingShift: ComparisonShiftSummary.fromClosingJson(json['closingShift']),
      openingShift: ComparisonShiftSummary.fromOpeningJson(json['openingShift']),
      cashDiff: _toDouble(json['cashDiff']),
      totalDiff: _toDouble(json['totalDiff']),
      entityComparisons: (json['entityComparisons'] as List)
          .map((e) => EntityComparison.fromJson(e))
          .toList(),
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
