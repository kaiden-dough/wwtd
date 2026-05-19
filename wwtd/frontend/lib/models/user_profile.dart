class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.balancePoints,
    this.displayName,
  });

  final String id;
  final String email;
  final double balancePoints;
  final String? displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      balancePoints: (json['balance_points'] as num?)?.toDouble() ?? 500,
      displayName: json['display_name'] as String?,
    );
  }
}
