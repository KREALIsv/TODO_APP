class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String email;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: createdAt is String
          ? DateTime.parse(createdAt)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
