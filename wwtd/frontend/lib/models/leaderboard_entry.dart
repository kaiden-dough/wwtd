class LeaderboardEntry {
  const LeaderboardEntry({
    required this.username,
    required this.wins,
    required this.resolvedBets,
    required this.winRate,
    required this.isTrendingUp,
    this.userId,
    this.netPoints = 0,
  });

  final String username;
  final int wins;
  final int resolvedBets;
  final double winRate;
  final bool isTrendingUp;
  final String? userId;
  final int netPoints;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String?,
      username: json['display_name'] as String,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      resolvedBets: (json['resolved_bets'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      isTrendingUp: json['is_trending_up'] as bool? ?? false,
      netPoints: (json['net_points'] as num?)?.round() ?? 0,
    );
  }
}
