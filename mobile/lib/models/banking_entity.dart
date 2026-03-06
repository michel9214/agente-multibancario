class BankingEntity {
  final String id;
  final String name;
  final String type;
  final String color;
  final bool isActive;

  BankingEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.isActive,
  });

  factory BankingEntity.fromJson(Map<String, dynamic> json) {
    return BankingEntity(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      color: json['color'] ?? '#1976D2',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
    );
  }
}
