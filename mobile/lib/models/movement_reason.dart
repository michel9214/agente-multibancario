class MovementReason {
  final String id;
  final String name;
  final String defaultDirection;
  final bool isActive;

  MovementReason({
    required this.id,
    required this.name,
    required this.defaultDirection,
    this.isActive = true,
  });

  factory MovementReason.fromJson(Map<String, dynamic> json) {
    return MovementReason(
      id: json['id'],
      name: json['name'],
      defaultDirection: json['defaultDirection'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultDirection': defaultDirection,
        'isActive': isActive,
      };
}
