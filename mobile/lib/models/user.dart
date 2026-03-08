class User {
  final String id;
  final String? email;
  final String fullName;
  final String? photoUrl;
  final String role;
  final bool? isActive;

  User({
    required this.id,
    this.email,
    required this.fullName,
    this.photoUrl,
    required this.role,
    this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      photoUrl: json['photoUrl'] ?? json['photo_url'],
      role: json['role'] ?? 'OPERATOR',
      isActive: json['isActive'] ?? json['is_active'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'photoUrl': photoUrl,
    'role': role,
    'isActive': isActive,
  };

  bool get isOwner => role == 'OWNER';
  bool get isOperator => role == 'OPERATOR';
}
