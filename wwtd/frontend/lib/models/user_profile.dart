class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.balancePoints,
    this.displayName,
    this.email,
  });

  final String id;
  final String username;
  final double balancePoints;
  final String? displayName;
  final String? email;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      balancePoints: (json['balance_points'] as num?)?.toDouble() ?? 500,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
    );
  }
}
