class LeaderboardEntry {
  const LeaderboardEntry({
    required this.username,
    required this.totalPoints,
    required this.winRate,
    required this.isTrendingUp,
    this.userId,
  });

  final String username;
  final int totalPoints;
  final double winRate;
  final bool isTrendingUp;
  final String? userId;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final num? points = json['net_points'] as num? ?? json['balance_points'] as num?;
    return LeaderboardEntry(
      userId: json['user_id'] as String?,
      username: json['display_name'] as String,
      totalPoints: (points ?? 0).round(),
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      isTrendingUp: json['is_trending_up'] as bool? ?? true,
    );
  }
}
