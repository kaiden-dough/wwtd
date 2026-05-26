class GameRoom {
  const GameRoom({
    required this.id,
    required this.joinCode,
    required this.personName,
    required this.moderatorName,
    required this.isModerator,
    required this.balancePoints,
  });

  final String id;
  final String joinCode;
  final String personName;
  final String moderatorName;
  final bool isModerator;
  final double balancePoints;

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'] as String,
      joinCode: json['join_code'] as String,
      personName: json['person_name'] as String,
      moderatorName: json['moderator_name'] as String? ?? '',
      isModerator: json['is_moderator'] as bool? ?? false,
      balancePoints: (json['balance_points'] as num?)?.toDouble() ?? 500,
    );
  }
}
