class LeaderboardEntry {
  const LeaderboardEntry({
    required this.username,
    required this.totalPoints,
    required this.winRate,
    required this.isTrendingUp,
  });

  final String username;
  final int totalPoints;
  final double winRate;
  final bool isTrendingUp;
}
