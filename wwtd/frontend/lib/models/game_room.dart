class GameRoom {
  const GameRoom({
    required this.id,
    required this.joinCode,
    required this.personName,
    required this.isModerator,
  });

  final String id;
  final String joinCode;
  final String personName;
  final bool isModerator;

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'] as String,
      joinCode: json['join_code'] as String,
      personName: json['person_name'] as String,
      isModerator: json['is_moderator'] as bool? ?? false,
    );
  }
}
